defmodule ChorusDraft.PII do
  @moduledoc "Conservative pattern screening, not a guarantee that text is anonymous."
  alias ChorusDraft.{Error, Safety}

  # A leading @ distinguishes a federated social mention from an email address.
  @email ~r/(?<![\p{L}\p{N}_@])[\p{L}\p{N}.!#$%&'*+\/=?^_`{|}~-]+\s*@\s*[\p{L}\p{N}-]+(?:\s*\.\s*[\p{L}\p{N}-]+)+/iu
  @obfuscated_email ~r/(?<![\p{L}\p{N}_@])[\p{L}\p{N}._%+-]+\s*(?:\[at\]|\(at\)|\{at\}|\s+at\s+)\s*[\p{L}\p{N}-]+(?:\s*(?:\[dot\]|\(dot\)|\{dot\}|\s+dot\s+|\.)\s*[\p{L}\p{N}-]+)+/iu
  # Seven or more digits covers local/international phones, SSNs and card numbers.
  @number ~r/(?<![\p{L}\p{N}])\+?\p{Nd}(?:[\p{Zs}\t.()\-‐‑‒–—]*\p{Nd}){6,}(?![\p{L}\p{N}])/u
  @address ~r/\b\d{1,6}\s+[\p{L}\p{N}][\p{L}\p{N} .'’-]{0,60}\s+(?:avenue|ave|boulevard|blvd|court|ct|drive|dr|lane|ln|road|rd|street|st|way|place|pl|terrace|ter|circle|cir|parkway|pkwy|highway|hwy)\b/iu
  @po_box ~r/\b(?:p\.?\s*o\.?\s+box|post\s+office\s+box)\s+\d+\b/iu
  @identifier ~r/\b(?:ssn|social\s+security(?:\s+number)?|passport(?:\s+(?:no|number))?|driver'?s?\s+licen[cs]e|date\s+of\s+birth|dob|iban|bank\s+account|routing\s+number)\s*[:#=]?\s*[\p{L}\p{N}][\p{L}\p{N} .\/-]{2,60}/iu
  @coordinates ~r/(?<![\p{L}\p{N}])-?\d{1,3}\.\d{4,}\s*[,;]\s*-?\d{1,3}\.\d{4,}(?!\p{N})/u
  @credential ~r/\b(?:AIza[\w-]{35}|gh[pousr]_[\w]{20,}|github_pat_[\w]{20,}|sk-(?:proj-)?[\w-]{20,}|eyJ[\w-]{10,}\.[\w-]{10,}\.[\w-]{10,})\b/u
  @patterns [
    @email,
    @obfuscated_email,
    @number,
    @address,
    @po_box,
    @identifier,
    @coordinates,
    @credential
  ]

  def sensitive?(text) when is_binary(text) do
    value = Safety.screening_text(text)
    Enum.any?(@patterns, &Regex.match?(&1, value))
  end

  def sensitive?(nil), do: false

  def validate!(text) do
    if sensitive?(text),
      do: raise(Error, "AI draft may contain personal information or credentials.")
    true
  end

  # Only provider context is normalized/redacted. Never silently rewrite a draft
  # that the operator has reviewed or mutate the canonical platform post.
  def redact(value) when is_binary(value) do
    Enum.reduce(@patterns, Safety.screening_text(value), fn pattern, text ->
      Regex.replace(pattern, text, "[REDACTED]")
    end)
  end

  def redact(value) when is_list(value), do: Enum.map(value, &redact/1)
  def redact(value) when is_map(value), do: Map.new(value, fn {key, item} -> {key, redact(item)} end)
  def redact(value), do: value
end
