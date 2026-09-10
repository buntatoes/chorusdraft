defmodule ChorusDraft.Control do
  @moduledoc false
  alias ChorusDraft.Error

  @actions ~w(approve reject quit skip edit)
  @max_text 10_000
  # Commands are small (text is capped at @max_text); a 64 KiB line cap stops a
  # broken or hostile client from growing the heap with an unterminated line.
  @max_line 65_536

  def enabled?, do: System.get_env("CHORUSDRAFT_CONTROL") == "1"

  def setup! do
    if enabled?() do
      # JSON lines travel over a pipe. List-mode stdio makes IO.read/2 return
      # charlists, which used to crash review with a generic failure.
      _ = :io.setopts(:standard_io, [:binary])
    end

    :ok
  end

  def log(text) do
    text = to_string(text)

    if enabled?() do
      emit(%{"event" => "log", "value" => ending(text)})
    else
      IO.puts(text)
    end
  end

  def warn(text) do
    text = to_string(text)

    if enabled?() do
      emit(%{"event" => "log", "value" => ending(text)})
    else
      IO.puts(:stderr, text)
    end
  end

  def emit(map) when is_map(map), do: emit_to(:stdio, map)

  def emit_to(device, map) when is_map(map) do
    IO.write(device, Jason.encode!(map) <> "\n")
  end

  def read(device) do
    case line(device) do
      :eof -> %{"action" => "quit"}
      {:error, _} -> %{"action" => "quit"}
      data -> decode!(normalize(data))
    end
  end

  def decode!(line) when is_binary(line) do
    case Jason.decode(String.trim(line)) do
      {:ok, %{"action" => action} = command} when action in @actions ->
        validate!(action, command)

      _ ->
        raise Error, "Invalid control command."
    end
  end

  defp validate!("edit", command) do
    text = command["text"]

    unless is_binary(text) and String.trim(text) != "" and String.length(text) <= @max_text and
             not String.contains?(text, <<0>>) do
      raise Error, "Replacement text is required."
    end

    if Regex.match?(~r/[\x00-\x08\x0b-\x1f\x7f]/u, text),
      do: raise(Error, "Replacement text is invalid.")

    %{"action" => "edit", "text" => text}
  end

  defp validate!(action, _command), do: %{"action" => action}

  defp line(device), do: line(device, [], 0)

  defp line(device, acc, size) do
    case read_byte(device) do
      :eof ->
        if acc == [], do: :eof, else: finish_line(acc)

      {:error, _} = error ->
        error

      "\n" ->
        finish_line(acc)

      _ when size >= @max_line ->
        raise Error, "Control command exceeded the 64 KiB line limit."

      byte ->
        line(device, [byte | acc], size + 1)
    end
  end

  defp finish_line(acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()

  defp read_byte(device) do
    data =
      try do
        IO.binread(device, 1)
      rescue
        _ -> IO.read(device, 1)
      end

    if is_list(data), do: List.to_string(data), else: data
  end

  defp normalize(data) when is_binary(data), do: data
  defp normalize(data) when is_list(data), do: List.to_string(data)

  defp ending(text), do: if(String.ends_with?(text, "\n"), do: text, else: text <> "\n")
end
