defmodule ChorusDraft.Safety do
  alias ChorusDraft.Error

  @opt_out ~r/\b(?:leave\s+me\s+alone|(?:do\s+not|don't|dont|stop)\s+(?:reply(?:ing)?|respond(?:ing)?|contact(?:ing)?|mention(?:ing)?)(?:\s+to)?\s+me)\b/iu
  @abuse ~r/(?:\b(?:kill|hang)\s+yourself\b|\bdie\s+in\s+(?:a\s+)?fire\b|\bbomb\s+threat\b|\bdoxx?(?:ing|ed)?\b|\b(?:everyone|everybody)\s+(?:go\s+)?(?:attack|harass|report|threaten)\b|\byou(?:'re|\s+are)\s+(?:an?\s+)?(?:idiot|moron|worthless|pathetic)\b)/iu
  @automatic_abuse ~r/(?:\b(?:clown|creep|disgusting|dumb|idiot|loser|moron|pathetic|stupid|trash|worthless)\b|\b(?:shut\s+up|go\s+(?:away|die)|nobody\s+likes\s+you)\b|\b(?:attack|dogpile|harass|mass[- ]?report|ratio|threaten)\s+@?\w+|\b(?:send\s+nudes|nice\s+(?:ass|tits)|your\s+(?:body|chest)\s+is\s+hot)\b)/iu
  @automatic_mention ~r/(?<![\p{L}\p{N}_@])@[\p{L}\p{N}_][\p{L}\p{N}_.-]*(?:@[\p{L}\p{N}_][\p{L}\p{N}_.-]*)?/u
  @automatic_url ~r/(?:\b(?:https?:\/\/|www\.)[^\s<>]+|\b(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+(?:ai|app|co|com|dev|io|net|org|social|xyz)(?:\/[^\s<>]*)?)/iu
  @automatic_email ~r/\b[a-z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+\b/iu
  @automatic_phone ~r/(?<![\p{L}\p{N}])\+?\d[\d .()-]{6,}\d(?![\p{L}\p{N}])/u
  @automatic_address ~r/\b\d{1,6}\s+[\p{L}\p{N}][\p{L}\p{N} .'’-]{0,60}\s+(?:avenue|ave|boulevard|blvd|court|ct|drive|dr|lane|ln|road|rd|street|st|way)\b/iu
  @injection ~r/ignore.{0,30}(instructions|rules)|system\s+prompt|jailbreak|reveal.{0,30}instructions|repeat\s+the\s+prompt|you\s+are\s+now|<\/?(?:system|untrusted_user_input)>/isu
  @control ~r/[\x{0000}-\x{0008}\x{000B}-\x{001F}\x{007F}\x{200E}\x{200F}\x{202A}-\x{202E}\x{2066}-\x{2069}]/u
  @format ~r/[\x{00AD}\x{0600}-\x{0605}\x{061C}\x{06DD}\x{070F}\x{0890}\x{0891}\x{08E2}\x{180E}\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}\x{FFF9}-\x{FFFB}\x{110BD}\x{110CD}\x{13430}-\x{1343F}\x{1BCA0}-\x{1BCA3}\x{1D173}-\x{1D17A}\x{E0001}\x{E0020}-\x{E007F}]/u

  def public?(post), do: post["visibility"] in ["public", "unlisted"]

  def actor_key(actor) do
    actor
    |> to_string_or_empty()
    |> String.trim()
    |> String.trim_leading("@")
    |> String.downcase()
  end

  def opt_out?(text), do: Regex.match?(@opt_out, screening_text(text))
  def injection?(text), do: Regex.match?(@injection, to_string_or_empty(text))

  def eligible?(post) do
    public?(post) and String.trim(to_string_or_empty(post["text"])) != "" and
      not injection?(post["text"])
  end

  def screening_text(text) do
    text
    |> to_string_or_empty()
    |> :unicode.characters_to_nfkc_binary()
    |> String.replace(["‘", "’", "ʼ"], "'")
    |> String.replace(@format, "")
  end

  def clean(text) do
    text |> to_string_or_empty() |> String.replace(@control, "") |> String.slice(0, 2000)
  end

  def validate_text!(text, limit) do
    value = to_string_or_empty(text)

    if String.trim(value) == "" or String.length(value) > limit do
      raise Error, "Post text is empty or exceeds the platform length limit."
    end

    if clean(value) != value, do: raise(Error, "Post contains control characters.")

    if Regex.match?(@abuse, screening_text(value)) do
      raise Error, "Post failed harassment screening."
    end

    true
  end

  def validate_automatic_text!(text, limit) do
    validate_text!(text, limit)
    value = screening_text(text)

    cond do
      Regex.match?(@automatic_abuse, value) ->
        raise Error, "Post failed automatic harassment screening."

      Regex.match?(@automatic_mention, value) ->
        raise Error, "Automatic AI output cannot add account mentions."

      Regex.match?(@automatic_url, value) ->
        raise Error, "Automatic AI output cannot add links."

      Regex.match?(@automatic_email, value) or Regex.match?(@automatic_phone, value) or
          Regex.match?(@automatic_address, value) ->
        raise Error, "Automatic AI output may contain personal contact information."

      true ->
        true
    end
  end

  defp to_string_or_empty(value) when is_binary(value), do: value
  defp to_string_or_empty(nil), do: ""
  defp to_string_or_empty(value), do: to_string(value)
end
