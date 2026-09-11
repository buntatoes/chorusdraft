defmodule ChorusDraft.Lock do
  @moduledoc false
  alias ChorusDraft.Error

  # The account-state lock must exclude separate OS processes: a desktop
  # launcher beside a CLI run, or two CLI runs. Erlang/OTP has no advisory
  # file-lock call, so exclusion comes from the kernel's exclusive bind of a
  # loopback listening socket. One socket at a time can hold an address, and
  # the kernel drops it when the owning VM exits or crashes, so a dead holder
  # never leaves a stale lock. `:global` serialises holders inside one VM
  # before any bind, which keeps same-VM handoff quick and fair.
  #
  # Candidate addresses come from the lock file's identity: its device and
  # inode where the OS reports them, otherwise its normalised path. Two stores
  # therefore never contend, and two paths naming one lock file still do. A
  # holder answers every connection with that identity digest, which is how a
  # contender separates a peer holding this store's lock from an unrelated
  # local listener on a candidate address.

  @timeout_ms 5_000
  @candidates 8
  @first_port 49_152
  @port_count 16_384
  @retry_ms 20
  @accept_wait_ms 25
  @answer_wait_ms 25
  @peer_wait_ms 200
  @backlog 64
  @release_wait_ms 1_000

  def acquire(path, opts \\ []) do
    digest = digest(path)
    resource = {__MODULE__, digest}
    deadline = System.monotonic_time(:millisecond) + Keyword.get(opts, :timeout, @timeout_ms)

    unless hold_vm_lock?(resource, deadline),
      do: raise(Error, "State is busy or could not be locked.")

    case listen(candidate_ports(digest), digest, deadline) do
      {:ok, socket, port} ->
        case start_acceptor(socket, digest) do
          {:ok, acceptor} ->
            %{acceptor: acceptor, port: port, resource: resource}

          :error ->
            :gen_tcp.close(socket)
            fail(resource, "State is busy or could not be locked.")
        end

      :busy ->
        fail(resource, "State is busy or could not be locked.")

      :unavailable ->
        fail(resource, "State could not be locked: no loopback lock address was free.")
    end
  end

  # The acceptor closes the socket and exits, so its exit proves the kernel has
  # dropped the address before the next holder tries to bind it.
  def release(lock) do
    ref = Process.monitor(lock.acceptor)
    send(lock.acceptor, :release)
    wake(lock.port)

    receive do
      {:DOWN, ^ref, :process, _pid, _reason} -> :ok
    after
      @release_wait_ms -> Process.demonitor(ref, [:flush])
    end

    release_vm_lock(lock.resource)
    :ok
  end

  defp fail(resource, message) do
    release_vm_lock(resource)
    raise Error, message
  end

  # A throwaway connection returns the acceptor from its accept wait, so the
  # address is free the moment release returns rather than one wait later.
  defp wake(port) do
    case :gen_tcp.connect({127, 0, 0, 1}, port, [active: false], @peer_wait_ms) do
      {:ok, socket} -> :gen_tcp.close(socket)
      {:error, _reason} -> :ok
    end
  end

  defp hold_vm_lock?(resource, deadline) do
    if :global.set_lock({resource, self()}, [node()], 0) do
      true
    else
      retry?(deadline) and hold_vm_lock?(resource, deadline)
    end
  end

  defp release_vm_lock(resource), do: :global.del_lock({resource, self()}, [node()])

  defp listen(ports, digest, deadline) do
    case claim(ports, ports, digest) do
      {:ok, socket, port} -> {:ok, socket, port}
      reason -> if retry?(deadline), do: listen(ports, digest, deadline), else: reason
    end
  end

  # Candidates are walked in one fixed order, so every contender agrees on
  # which address belongs to this store.
  defp claim([], _all, _digest), do: :unavailable

  defp claim([port | rest], all, digest) do
    options = [:binary, ip: {127, 0, 0, 1}, active: false, packet: :raw, backlog: @backlog]

    # No `reuseaddr`: a bind must fail while another socket holds the address,
    # which is the whole guarantee this lock rests on.
    case :gen_tcp.listen(port, options) do
      {:ok, socket} ->
        # An unrelated listener can free an earlier candidate at any moment, so
        # a successful bind alone does not prove sole ownership. Yield the lock
        # if a peer answers on any other candidate.
        if Enum.any?(List.delete(all, port), &peer?(&1, digest)) do
          :gen_tcp.close(socket)
          :busy
        else
          {:ok, socket, port}
        end

      {:error, :eaddrinuse} ->
        if peer?(port, digest), do: :busy, else: claim(rest, all, digest)

      {:error, _reason} ->
        claim(rest, all, digest)
    end
  end

  defp peer?(port, digest) do
    options = [:binary, active: false, packet: :raw]

    case :gen_tcp.connect({127, 0, 0, 1}, port, options, @peer_wait_ms) do
      {:ok, socket} ->
        answer = :gen_tcp.recv(socket, byte_size(digest), @peer_wait_ms)
        :gen_tcp.close(socket)
        answer == {:ok, digest}

      {:error, _reason} ->
        false
    end
  end

  # The acceptor owns the socket and watches the holder, so the address is
  # released when the transaction ends and when its process dies.
  defp start_acceptor(socket, digest) do
    holder = self()

    acceptor =
      spawn(fn ->
        Process.monitor(holder)

        receive do
          :own -> accept(socket, digest)
        after
          @release_wait_ms -> :gen_tcp.close(socket)
        end
      end)

    case :gen_tcp.controlling_process(socket, acceptor) do
      :ok ->
        send(acceptor, :own)
        {:ok, acceptor}

      {:error, _reason} ->
        Process.exit(acceptor, :kill)
        :error
    end
  end

  # The release and holder-death checks come before every accept: a contender
  # polling the address must never keep a dead holder's acceptor alive.
  defp accept(socket, digest) do
    receive do
      :release -> :gen_tcp.close(socket)
      {:DOWN, _ref, :process, _pid, _reason} -> :gen_tcp.close(socket)
    after
      0 -> answer(socket, digest)
    end
  end

  defp answer(socket, digest) do
    case :gen_tcp.accept(socket, @accept_wait_ms) do
      {:ok, peer} ->
        _ = :gen_tcp.send(peer, digest)
        # Wait briefly for the contender to close, so it reads the digest
        # before the socket goes. Answering must stay quick: a holder that
        # stalls here looks like an unrelated listener to the next contender.
        _ = :gen_tcp.recv(peer, 0, @answer_wait_ms)
        # Reset rather than linger: a TIME_WAIT entry on the lock address would
        # block the next holder's bind, which reads as a busy store.
        _ = :inet.setopts(peer, linger: {true, 0})
        :gen_tcp.close(peer)
        accept(socket, digest)

      {:error, :timeout} ->
        accept(socket, digest)

      {:error, _reason} ->
        :gen_tcp.close(socket)
    end
  end

  defp retry?(deadline) do
    if System.monotonic_time(:millisecond) < deadline do
      Process.sleep(@retry_ms)
      true
    else
      false
    end
  end

  defp candidate_ports(digest) do
    digest
    |> :binary.bin_to_list()
    |> Enum.chunk_every(2, 2, :discard)
    |> Enum.take(@candidates)
    |> Enum.map(fn [high, low] -> @first_port + rem(high * 256 + low, @port_count) end)
    |> Enum.uniq()
  end

  defp digest(path), do: :crypto.hash(:sha256, "chorusdraft/state-lock\0" <> identity(path))

  # Several paths can name one lock file, so the file's own identity is the
  # lock identity. Windows reports no inode; there the normalised path stands
  # in, case-folded because its file names are case-insensitive.
  defp identity(path) do
    expanded = Path.expand(path)

    case File.stat(expanded) do
      {:ok, %File.Stat{inode: inode, major_device: device}} when inode > 0 ->
        "inode:#{device}:#{inode}"

      _ ->
        "path:" <> String.downcase(expanded)
    end
  end
end
