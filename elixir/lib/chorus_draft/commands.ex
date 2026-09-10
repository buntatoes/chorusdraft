defmodule ChorusDraft.Commands do
  @moduledoc false
  alias ChorusDraft.Error

  @simple %{
    "setup" => "--setup",
    "draft" => "--post-only",
    "review" => "--process-queue",
    "replies" => "--replies-only",
    "start" => "--daemon",
    "listen" => "--listen",
    "help" => "--help",
    "version" => "--version",
    "status" => "--status",
    "history" => "--history"
  }
  def normalize([]), do: []
  def normalize(["-" <> _ | _] = args), do: args

  def normalize([command | args]) do
    cond do
      Map.has_key?(@simple, command) ->
        [Map.fetch!(@simple, command) | args]

      command == "automatic" ->
        ["--daemon", "--automatic" | args]

      command == "service" ->
        {action, rest} = required(args, command)

        unless action in ["install", "uninstall", "print"],
          do: raise(Error, "service requires install, uninstall, or print.")

        ["--service=#{action}" | rest]

      command in ["post", "search", "delete", "import", "reject"] ->
        {value, rest} = required(args, command)
        flag = %{"post" => "text", "import" => "import-state"} |> Map.get(command, command)
        ["--#{flag}=#{value}" | rest]

      command == "edit" ->
        {id, args} = required(args, command)
        {text, rest} = required(args, command)
        ["--edit=#{id}", "--text=#{text}" | rest]

      command in ["reply", "quote"] ->
        {id, args} = required(args, command)
        {text, rest} = required(args, command)
        flag = if command == "reply", do: "reply-to", else: "quote-uri"
        ["--text=#{text}", "--#{flag}=#{id}" | rest]

      command in ["random", "discover", "targets"] ->
        {value, rest} = optional(args)

        flags =
          case command do
            "random" -> ["--random-post=#{value || ""}"]
            "discover" -> ["--discover"] ++ option("query", value)
            "targets" -> ["--targets-only"] ++ option("target", value)
          end

        flags ++ rest

      true ->
        raise Error, "Unknown command. Use help to see available commands."
    end
  end

  defp required([value | rest], command) do
    if value == "" or String.starts_with?(value, "--"),
      do: raise(Error, "#{command} requires an argument. Use help for examples.")

    {value, rest}
  end

  defp required([], command),
    do: raise(Error, "#{command} requires an argument. Use help for examples.")

  defp optional(["-" <> _ | _] = args), do: {nil, args}
  defp optional([value | rest]), do: {value, rest}
  defp optional([]), do: {nil, []}
  defp option(_flag, nil), do: []
  defp option(flag, value), do: ["--#{flag}=#{value}"]
end
