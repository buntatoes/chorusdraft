defmodule ChorusDraft.Guard do
  @moduledoc """
  Loads the proprietary ChorusDraft Guard implementation.

  Official builds compile `guard/` and sign the compiled Guard modules with the
  release key. If that code is missing, or the code on disk is not what the
  release signed, ChorusDraft refuses to continue rather than screening or
  publishing without safeguards.
  """
  alias ChorusDraft.Error
  alias ChorusDraft.Guard.Signature

  @safety ChorusDraft.Guard.Safety
  @pii ChorusDraft.Guard.PII

  @doc "The proprietary modules a build must carry and verify."
  def modules, do: [@safety, @pii]

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
        case Signature.verify(module) do
          :ok -> module
          {:error, reason} -> raise Error, unverified_message(reason)
        end

      _ ->
        raise Error, missing_message()
    end
  end

  def missing_message do
    "ChorusDraft Guard is required and was not loaded. Official builds include the proprietary safeguard module; refusing to continue without it."
  end

  def unverified_message(reason) do
    "ChorusDraft Guard failed signature verification (#{explain(reason)}). Official builds ship Guard signed by the release key; refusing to screen or publish with unverified safeguards."
  end

  defp explain(:unsigned), do: "this build carries no Guard signature"
  defp explain(:malformed_signature), do: "the Guard signature is unreadable"
  defp explain(:no_trusted_key), do: "this build carries no Guard verifying key"
  defp explain(:untrusted_signature), do: "no trusted key signed the Guard manifest"
  defp explain(:malformed_manifest), do: "the signed Guard manifest is unreadable"
  defp explain(:wrong_release), do: "the signed Guard manifest is for another release"
  defp explain(:unsigned_module), do: "the signed Guard manifest does not cover this module"
  defp explain(:unreadable_beam), do: "the Guard code could not be read back for checking"
  defp explain(:digest_mismatch), do: "the Guard code on disk is not what was signed"
  defp explain(:stale_code), do: "the running Guard code is not the code on disk"
end
