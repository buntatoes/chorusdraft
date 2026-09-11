defmodule ChorusDraft.Config do
  alias ChorusDraft.Error

  def load(path, env \\ System.get_env()) do
    case File.lstat(path) do
      {:ok, %{type: :regular}} ->
        path
        |> File.stream!([], :line)
        |> Enum.with_index(1)
        |> Enum.reduce(env, fn {line, number}, acc -> parse_line(line, number, acc) end)

      {:error, :enoent} ->
        env

      {:ok, _} ->
        raise Error, "Configuration must be a regular file, not a symlink or directory."

      {:error, _} ->
        raise Error, "Could not read configuration."
    end
  end

  def required(env, key) do
    value = env |> Map.get(key, "") |> to_string() |> String.trim()

    if value == "" or String.starts_with?(value, ["your_", "xxxx-"]) do
      raise Error, "Set #{key} in .env or the environment."
    end

    value
  end

  defp parse_line(line, number, env) do
    line = String.trim(line)

    cond do
      line == "" or String.starts_with?(line, "#") ->
        env

      true ->
        case Regex.run(~r/^([A-Z][A-Z0-9_]*)=(.*)$/s, line, capture: :all_but_first) do
          [key, value] -> Map.put_new(env, key, unquote_value(String.trim(value)))
          _ -> raise Error, "Invalid .env assignment at line #{number}"
        end
    end
  end

  defp unquote_value(value) do
    if String.length(value) >= 2 and
         ((String.starts_with?(value, "\"") and String.ends_with?(value, "\"")) or
            (String.starts_with?(value, "'") and String.ends_with?(value, "'"))) do
      String.slice(value, 1, String.length(value) - 2)
    else
      value
    end
  end
end
