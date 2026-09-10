defmodule ChorusDraft.PII do
  @moduledoc """
  Public personal-information screening API. The implementation is proprietary
  ChorusDraft Guard. ChorusDraft refuses to run if Guard is missing.
  """

  def sensitive?(text), do: ChorusDraft.Guard.call(:pii, :sensitive?, [text])
  def validate!(text), do: ChorusDraft.Guard.call(:pii, :validate!, [text])
  def redact(value), do: ChorusDraft.Guard.call(:pii, :redact, [value])
end
