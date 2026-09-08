defmodule ChorusDraft.Control do
  @moduledoc false
  alias ChorusDraft.Error

  @actions ~w(approve reject quit skip edit)
  @max_text 10_000

  def enabled?, do: System.get_env("CHORUSDRAFT_CONTROL") == "1"

  def setup! do
    if enabled?() do
      _ = :io.setopts(:standard_io, [{:encoding, :unicode}, {:binary, false}])
      _ = :io.setopts(:standard_io, [{:buffer, :line}])
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
    case IO.read(device, :line) do
      :eof ->
        %{"action" => "quit"}

      {:error, _} ->
        %{"action" => "quit"}

      line when is_binary(line) ->
        decode!(line)
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

  defp ending(text), do: if(String.ends_with?(text, "\n"), do: text, else: text <> "\n")
end
