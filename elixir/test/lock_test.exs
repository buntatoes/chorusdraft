defmodule ChorusDraft.LockTest do
  use ExUnit.Case, async: false
  alias ChorusDraft.{Error, Lock, Platform}

  @busy_timeout_ms 300
  @child_timeout_ms 20_000

  setup do
    dir = Path.join(System.tmp_dir!(), "chorus-draft-lock-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    path = Path.join(dir, "state.lock")
    File.touch!(path)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir, path: path}
  end

  test "locking calls no spawn, exec, or executable lookup" do
    {:ok, {_module, [imports: imports]}} =
      Lock |> :code.which() |> :beam_lib.chunks([:imports])

    forbidden =
      Enum.filter(imports, fn
        {:erlang, :open_port, _arity} -> true
        {:os, :cmd, _arity} -> true
        {:os, :find_executable, _arity} -> true
        {Port, _function, _arity} -> true
        {System, function, _arity} when function in [:cmd, :shell, :find_executable] -> true
        _other -> false
      end)

    assert forbidden == []
  end

  # Connecting to a closed port costs a full timeout on Windows, so an
  # uncontended lock must never reach for an address it did not find taken.
  test "an uncontended lock is taken and released without probing", %{path: path} do
    {elapsed, :ok} =
      :timer.tc(fn ->
        Enum.each(1..10, fn _ -> path |> Lock.acquire() |> Lock.release() end)
      end)

    assert elapsed < 2_000_000
  end

  test "the holder releases the lock and can take it again", %{path: path} do
    lock = Lock.acquire(path)
    assert :ok = Lock.release(lock)
    assert lock2 = Lock.acquire(path)
    assert :ok = Lock.release(lock2)
  end

  test "a second process in this VM waits and then takes the lock", %{path: path} do
    lock = Lock.acquire(path)

    waiting =
      Task.async(fn ->
        second = Lock.acquire(path)
        Lock.release(second)
        :acquired
      end)

    refute_receive {_ref, :acquired}, 200
    Lock.release(lock)
    assert Task.await(waiting) == :acquired
  end

  test "a second holder is refused while the lock is held in this VM", %{path: path} do
    lock = Lock.acquire(path)

    refused =
      Task.async(fn ->
        assert_raise Error, ~r/busy/, fn -> Lock.acquire(path, timeout: @busy_timeout_ms) end
      end)

    Task.await(refused)
    Lock.release(lock)
  end

  test "separate stores never contend", %{dir: dir} do
    other = Path.join(dir, "other.lock")
    File.touch!(other)

    first = Lock.acquire(Path.join(dir, "state.lock"))
    second = Lock.acquire(other)
    assert :ok = Lock.release(first)
    assert :ok = Lock.release(second)
  end

  test "two paths naming one lock file are one lock", %{dir: dir} do
    lock = Lock.acquire(Path.join(dir, "state.lock"))
    alias_path = Path.join([dir, "sub", "..", "state.lock"])
    File.mkdir_p!(Path.join(dir, "sub"))

    assert_raise Error, ~r/busy/, fn -> Lock.acquire(alias_path, timeout: @busy_timeout_ms) end
    assert :ok = Lock.release(lock)
  end

  test "a linked path to one lock file is one lock", %{dir: dir, path: path} do
    if Platform.os() != "windows" do
      linked = Path.join(dir, "linked.lock")
      File.ln_s!(path, linked)
      lock = Lock.acquire(path)

      assert_raise Error, ~r/busy/, fn -> Lock.acquire(linked, timeout: @busy_timeout_ms) end
      assert :ok = Lock.release(lock)
    end
  end

  test "the lock is released when the holding process is killed", %{path: path} do
    parent = self()

    holder =
      spawn(fn ->
        Lock.acquire(path)
        send(parent, :held)
        Process.sleep(:infinity)
      end)

    assert_receive :held, 2_000
    Process.exit(holder, :kill)

    lock = Lock.acquire(path)
    assert :ok = Lock.release(lock)
  end

  test "a separate OS process cannot take a held lock and takes it once free", %{path: path} do
    lock = Lock.acquire(path)
    assert {output, status} = acquire_in_os_process(path)
    assert status == 3, "expected the second OS process to be refused, got: #{output}"

    assert :ok = Lock.release(lock)
    assert {output, status} = acquire_in_os_process(path)
    assert status == 0, "expected the second OS process to acquire, got: #{output}"
  end

  # A second VM proves cross-process exclusion; only the test spawns it.
  defp acquire_in_os_process(path) do
    erl = System.find_executable("erl") || flunk("erl must be on PATH to run this test")
    paths = Enum.flat_map(:code.get_path(), &["-pa", List.to_string(&1)])

    script = """
    {ok, _} = application:ensure_all_started(elixir),
    Path = list_to_binary(os:getenv("CHORUSDRAFT_LOCK_PATH")),
    try 'Elixir.ChorusDraft.Lock':acquire(Path, [{timeout, 500}]) of
      Lock ->
        'Elixir.ChorusDraft.Lock':release(Lock),
        halt(0)
    catch
      _:_ -> halt(3)
    end
    """

    task =
      Task.async(fn ->
        System.cmd(erl, paths ++ ["-noshell", "-noinput", "-eval", script],
          env: [{"CHORUSDRAFT_LOCK_PATH", path}],
          stderr_to_stdout: true
        )
      end)

    Task.await(task, @child_timeout_ms)
  end
end
