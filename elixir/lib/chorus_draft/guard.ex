defmodule ChorusDraft.Guard do
  @moduledoc """
  Loads the proprietary ChorusDraft Guard implementation.

  Official builds compile `guard/`. If that code is missing or is not a
  licensed Guard module, ChorusDraft refuses to continue rather than
  screening or publishing without safeguards.
  """
  alias ChorusDraft.Error

  @safety ChorusDraft.Guard.Safety
  @pii ChorusDraft.Guard.PII
  @id_prefix "chorusdraft-guard-"

  def required! do
    safety()
    pii()
    :ok
  end

  def safety, do: ensure_module!(@safety)
  def pii, do: ensure_module!(@pii)

  def call(kind, fun, args)
      when kind in [:safety, :pii] and is_atom(fun) and is_list(args) do
    module = if(kind == :safety, do: safety(), else: pii())
    arity = length(args)

    unless function_exported?(module, fun, arity) do
      raise Error, missing_message()
    end

    apply(module, fun, args)
  end

  def ensure_module!(module) when is_atom(module) do
    case Code.ensure_loaded(module) do
      {:module, ^module} ->
        id =
          if function_exported?(module, :__guard_id__, 0), do: module.__guard_id__()

        if valid_id?(id) do
          module
        else
          raise Error, missing_message()
        end

      _ ->
        raise Error, missing_message()
    end
  end

  def missing_message do
    "ChorusDraft Guard is required and was not loaded. Official builds include the proprietary safeguard module; refusing to continue without it."
  end

  # The id check proves a Guard beam is present and matches this release, not
  # that it is authentic: anyone who can swap beams already controls the
  # runtime. The fail-closed property is what matters.
  defp valid_id?(id) when is_binary(id),
    do: id == @id_prefix <> ChorusDraft.version()

  defp valid_id?(_), do: false
end
