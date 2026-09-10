defmodule ChorusDraft.Lock do
  @moduledoc false
  alias ChorusDraft.{Error, Platform}

  # Only standard-library OS locks are used. The parent owns the stdin pipe;
  # closing it (also on a VM crash) releases the helper's lock in the kernel.
  @python ~S"""
  import os, sys, time
  try:
      path = sys.argv[1]
      fd = os.open(path, os.O_RDWR | os.O_CREAT, 0o600)
      if os.name == 'nt' and os.fstat(fd).st_size == 0:
          os.write(fd, b'\0')
          os.fsync(fd)
      deadline = time.monotonic() + 5
      while True:
          try:
              if os.name == 'nt':
                  import msvcrt
                  os.lseek(fd, 0, os.SEEK_SET)
                  msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)
              else:
                  import fcntl
                  fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
              break
          except OSError:
              if time.monotonic() >= deadline:
                  sys.exit(1)
              time.sleep(0.02)
      sys.stdout.buffer.write(b'locked\n')
      sys.stdout.buffer.flush()
      sys.stdin.buffer.read(1)
      os.close(fd)
  except Exception:
      sys.exit(1)
  """

  def acquire(path, backend \\ Platform.os()) do
    {executable, args} =
      if backend == "linux" do
        executable =
          System.find_executable("flock") ||
            raise(Error, "Install util-linux (flock) to use Linux state storage.")

        {executable,
         [
           "--exclusive",
           "--timeout",
           "5",
           "--no-fork",
           path,
           "/bin/sh",
           "-c",
           "printf 'locked\\n'; read -r release"
         ]}
      else
        {Platform.python(), ["-I", "-u", "-c", @python, path]}
      end

    port =
      Port.open(
        {:spawn_executable, executable},
        [:binary, :exit_status, :use_stdio, :hide, {:line, 64}, args: args]
      )

    receive do
      {^port, {:data, {:eol, "locked"}}} -> port
      {^port, {:exit_status, _}} -> raise Error, "State is busy or could not be locked."
    after
      10_000 ->
        release(port)
        raise Error, "State lock timed out."
    end
  end

  # Close stdin so the helper drops the OS lock.
  def release(port) do
    if Port.info(port), do: Port.close(port)
    :ok
  end
end
