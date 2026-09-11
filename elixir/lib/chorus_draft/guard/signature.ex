defmodule ChorusDraft.Guard.Signature do
  @moduledoc """
  Verifies that the proprietary Guard modules are the compiled code a release
  signed.

  A release build records a digest of each Guard BEAM in a manifest and signs
  that manifest with an ed25519 key. The public halves live in
  `guard/keys/*.pub`; the private half never enters the repository. `mix
  guard.sign` compiles the manifest, the signature, and the trusted keys into
  the build, so a built ChorusDraft carries its own trust anchor and reads no
  key material at runtime. A build that was never signed carries none of it and
  refuses every Guard module.

  Verification digests the Guard BEAM as it exists on disk (inside the escript
  archive for a release package) and confirms the code the runtime loaded is
  that same BEAM. A Guard file that is swapped for a stub, or patched in place,
  fails even when it exports every function with the right names.
  """

  @manifest_header "chorusdraft-guard-manifest/1"

  # Everything that decides what the module does at runtime. Compile metadata
  # (`CInf`, `Dbgi`, `Docs`, `ExCk`, `LocT`) is left out: it records the build
  # directory and is dropped when escript packaging strips the BEAM, so
  # including it would make the digest depend on where and how Guard was built
  # rather than on what Guard executes.
  @digest_chunks ~w(AtU8 Code StrT ImpT ExpT FunT LitT Line Type Attr)c

  # Written into the build by `mix guard.sign`, after Guard is compiled and
  # there is something to digest. An unsigned build has no such module.
  @bundle ChorusDraft.Guard.Signature.Bundle

  @doc "Manifest recorded for this build, or `nil` when the build is unsigned."
  def manifest, do: bundle(:manifest)

  @doc "Detached signature for `manifest/0`, or `nil` when the build is unsigned."
  def signature, do: bundle(:signature)

  @doc """
  Public keys this build trusts, as raw 32-byte ed25519 keys.

  Taken from `guard/keys/*.pub` when the build was signed. A build with no key
  trusts nothing and refuses every Guard module.
  """
  def trusted_keys, do: bundle(:trusted_keys) || []

  defp bundle(name) do
    if Code.ensure_loaded?(@bundle) and function_exported?(@bundle, name, 0),
      do: apply(@bundle, name, [])
  end

  @doc """
  Verifies `module` against the manifest compiled into this build.

  Returns `:ok` or `{:error, reason}`. The result is cached per module for the
  life of the runtime: verification happens when Guard is first used.
  """
  def verify(module) when is_atom(module) do
    case :persistent_term.get({__MODULE__, module}, nil) do
      :ok ->
        :ok

      nil ->
        case verify(module, manifest(), signature(), trusted_keys()) do
          :ok ->
            :persistent_term.put({__MODULE__, module}, :ok)
            :ok

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc "Verifies `module` against an explicit manifest, signature, and key set."
  def verify(module, manifest, signature, keys) when is_atom(module) and is_list(keys) do
    case :code.get_object_code(module) do
      {^module, beam, _path} -> verify_beam(module, beam, manifest, signature, keys)
      :error -> {:error, :unreadable_beam}
    end
  end

  @doc """
  Verifies `beam`, the compiled bytes of `module`, against a signed manifest.

  Checks in order: the signature covers the manifest under a trusted key; the
  manifest is for this release; the manifest covers this module; the BEAM
  digest matches the manifest; the runtime is executing that BEAM.
  """
  def verify_beam(module, beam, manifest, signature, keys)
      when is_atom(module) and is_binary(beam) and is_list(keys) do
    with :ok <- check_signature(manifest, signature, keys),
         {:ok, entries} <- parse_manifest(manifest),
         :ok <- check_release(entries),
         {:ok, expected} <- fetch_digest(entries, module),
         {:ok, actual} <- digest(beam),
         :ok <- compare(expected, actual),
         :ok <- check_running_code(module, beam) do
      :ok
    end
  end

  @doc """
  Digest of the compiled code in `beam`.

  Stable across build directories, `MIX_ENV`, and escript BEAM stripping, and
  different for any change to the module's executable content.
  """
  def digest(beam) when is_binary(beam) do
    case :beam_lib.chunks(beam, @digest_chunks, [:allow_missing_chunks]) do
      {:ok, {_module, chunks}} ->
        payload =
          Enum.map(@digest_chunks, fn name ->
            case List.keyfind(chunks, name, 0) do
              {^name, data} when is_binary(data) -> [name, <<1, byte_size(data)::64>>, data]
              _ -> [name, <<0>>]
            end
          end)

        {:ok, :crypto.hash(:sha256, payload)}

      _ ->
        :error
    end
  end

  @doc """
  Canonical manifest text covering `modules` for release `version`.

  `modules` is a list of `{module, beam}` pairs. The text is what the release
  key signs, so its bytes are fixed: header, release version, then one sorted
  line per module.
  """
  def manifest_text(modules, version) do
    lines =
      modules
      |> Enum.map(fn {module, beam} ->
        {:ok, digest} = digest(beam)
        "module #{module} beam-sha256 #{Base.encode16(digest, case: :lower)}"
      end)
      |> Enum.sort()

    Enum.join([@manifest_header, "version #{version}" | lines], "\n") <> "\n"
  end

  @doc "Signs `manifest` with a raw 32-byte ed25519 private key."
  def sign(manifest, private_key) when is_binary(manifest) and byte_size(private_key) == 32 do
    :crypto.sign(:eddsa, :none, manifest, [private_key, :ed25519])
  end

  @doc "Public key matching a raw 32-byte ed25519 private key."
  def public_key(private_key) when byte_size(private_key) == 32 do
    {public, _private} = :crypto.generate_key(:eddsa, :ed25519, private_key)
    public
  end

  @doc "Text form of a public key file."
  def encode_public_key(public_key) when byte_size(public_key) == 32 do
    "ed25519 " <> Base.encode64(public_key) <> "\n"
  end

  @doc "Text form of a private key file."
  def encode_private_key(private_key) when byte_size(private_key) == 32 do
    "ed25519-private " <> Base.encode64(private_key) <> "\n"
  end

  @doc "Reads a public key file's contents."
  def parse_public_key(text), do: parse_key(text, "ed25519")

  @doc "Reads a private key file's contents."
  def parse_private_key(text), do: parse_key(text, "ed25519-private")

  @doc "Text form of a detached signature."
  def encode_signature(signature) when byte_size(signature) == 64 do
    Base.encode64(signature) <> "\n"
  end

  defp parse_key(text, label) when is_binary(text) do
    text
    |> lines()
    |> Enum.find_value(:error, fn line ->
      with [^label, encoded] <- String.split(line, " ", parts: 2),
           {:ok, key} <- Base.decode64(String.trim(encoded)),
           32 <- byte_size(key) do
        {:ok, key}
      else
        _ -> nil
      end
    end)
  end

  defp parse_key(_text, _label), do: :error

  defp check_signature(manifest, signature, keys)
       when is_binary(manifest) and is_binary(signature) do
    with false <- keys == [],
         {:ok, decoded} <- Base.decode64(String.trim(signature)),
         64 <- byte_size(decoded) do
      if Enum.any?(keys, &:crypto.verify(:eddsa, :none, manifest, decoded, [&1, :ed25519])),
        do: :ok,
        else: {:error, :untrusted_signature}
    else
      true -> {:error, :no_trusted_key}
      _ -> {:error, :malformed_signature}
    end
  end

  defp check_signature(nil, _signature, _keys), do: {:error, :unsigned}
  defp check_signature(_manifest, nil, _keys), do: {:error, :unsigned}
  defp check_signature(_manifest, _signature, _keys), do: {:error, :malformed_signature}

  defp parse_manifest(text) when is_binary(text) do
    case lines(text) do
      [@manifest_header, "version " <> version | rest] when version != "" ->
        parse_modules(rest, %{version: version, modules: %{}})

      _ ->
        {:error, :malformed_manifest}
    end
  end

  defp parse_modules([], entries), do: {:ok, entries}

  defp parse_modules([line | rest], entries) do
    with ["module", module, "beam-sha256", digest] <- String.split(line, " "),
         {:ok, digest} <- Base.decode16(digest, case: :lower),
         32 <- byte_size(digest),
         false <- Map.has_key?(entries.modules, module) do
      parse_modules(rest, put_in(entries.modules[module], digest))
    else
      _ -> {:error, :malformed_manifest}
    end
  end

  defp check_release(%{version: version}) do
    if version == ChorusDraft.version(), do: :ok, else: {:error, :wrong_release}
  end

  defp fetch_digest(%{modules: modules}, module) do
    case Map.fetch(modules, Atom.to_string(module)) do
      {:ok, digest} -> {:ok, digest}
      :error -> {:error, :unsigned_module}
    end
  end

  defp compare(expected, actual) do
    if :crypto.hash_equals(expected, actual), do: :ok, else: {:error, :digest_mismatch}
  end

  # The signed BEAM on disk is only evidence if it is also the code answering
  # calls: the loaded module reports the MD5 the emulator computed when it took
  # that code, which no BEAM file can claim for itself.
  defp check_running_code(module, beam) do
    if :code.module_md5(beam) == module.module_info(:md5),
      do: :ok,
      else: {:error, :stale_code}
  rescue
    _ -> {:error, :stale_code}
  end

  defp lines(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim_trailing(&1, "\r"))
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
  end
end
