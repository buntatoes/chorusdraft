defmodule ChorusDraft.Safety do
  @moduledoc """
  Public screening API. The implementation is proprietary ChorusDraft Guard.
  ChorusDraft refuses to run if Guard is missing.
  """

  def public?(post), do: ChorusDraft.Guard.call(:safety, :public?, [post])
  def actor_key(actor), do: ChorusDraft.Guard.call(:safety, :actor_key, [actor])
  def opt_out?(text), do: ChorusDraft.Guard.call(:safety, :opt_out?, [text])
  def injection?(text), do: ChorusDraft.Guard.call(:safety, :injection?, [text])
  def eligible?(post), do: ChorusDraft.Guard.call(:safety, :eligible?, [post])
  def screening_text(text), do: ChorusDraft.Guard.call(:safety, :screening_text, [text])
  def clean(text), do: ChorusDraft.Guard.call(:safety, :clean, [text])

  def validate_text!(text, limit),
    do: ChorusDraft.Guard.call(:safety, :validate_text!, [text, limit])

  def validate_automatic_text!(text, limit),
    do: ChorusDraft.Guard.call(:safety, :validate_automatic_text!, [text, limit])
end
