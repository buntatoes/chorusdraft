defmodule ChorusDraft.GuardSignatureTest do
  use ExUnit.Case, async: false
  alias ChorusDraft.Guard
  alias ChorusDraft.Guard.Signature

  @authentic """
  defmodule ChorusDraft.GuardSignatureFixture do
    def eligible?(post), do: post["visibility"] == "public"
  end
  """

  # What a swapped Guard looks like: the same module name, the same exported
  # functions, screening removed, and the identity the old check asked for.
  @patched """
  defmodule ChorusDraft.GuardSignatureFixture do
    def eligible?(_post), do: true
    def __guard_id__, do: "chorusdraft-guard-" <> ChorusDraft.version()
  end
  """

  setup_all do
    previous = Code.compiler_options()
    Code.compiler_options(ignore_module_conflict: true)

    # The authentic module is compiled last, so it is the code the runtime is
    # executing while these tests run.
    patched = compile(@patched)
    authentic = compile(@authentic)
    on_exit(fn -> Code.compiler_options(previous) end)

    private_key = :crypto.strong_rand_bytes(32)
    module = ChorusDraft.GuardSignatureFixture
    manifest = Signature.manifest_text([{module, authentic}], ChorusDraft.version())

    %{
      fixture: module,
      authentic: authentic,
      patched: patched,
      manifest: manifest,
      signature: sign(manifest, private_key),
      keys: [Signature.public_key(private_key)]
    }
  end

  test "accepts a Guard BEAM the signed manifest covers", context do
    assert Signature.verify_beam(
             context.fixture,
             context.authentic,
             context.manifest,
             context.signature,
             context.keys
           ) == :ok
  end

  test "refuses a patched Guard BEAM even though it claims the release identity", context do
    {:ok, {_module, [exports: exports]}} = :beam_lib.chunks(context.patched, [:exports])
    assert {:__guard_id__, 0} in exports

    assert Signature.verify_beam(
             context.fixture,
             context.patched,
             context.manifest,
             context.signature,
             context.keys
           ) == {:error, :digest_mismatch}
  end

  test "refuses a Guard BEAM that is on disk but is not the running code", context do
    manifest =
      Signature.manifest_text([{context.fixture, context.patched}], ChorusDraft.version())

    private_key = :crypto.strong_rand_bytes(32)

    assert Signature.verify_beam(
             context.fixture,
             context.patched,
             manifest,
             sign(manifest, private_key),
             [Signature.public_key(private_key)]
           ) == {:error, :stale_code}
  end

  test "refuses a build with no signature", context do
    assert Signature.verify_beam(context.fixture, context.authentic, nil, nil, context.keys) ==
             {:error, :unsigned}

    assert Signature.verify_beam(
             context.fixture,
             context.authentic,
             context.manifest,
             nil,
             context.keys
           ) == {:error, :unsigned}

    assert Signature.verify_beam(
             context.fixture,
             context.authentic,
             context.manifest,
             "not base64 at all",
             context.keys
           ) == {:error, :malformed_signature}
  end

  test "refuses a build with no trusted key", context do
    assert Signature.verify_beam(
             context.fixture,
             context.authentic,
             context.manifest,
             context.signature,
             []
           ) == {:error, :no_trusted_key}
  end

  test "refuses a manifest signed by an untrusted key", context do
    other = :crypto.strong_rand_bytes(32)

    assert Signature.verify_beam(
             context.fixture,
             context.authentic,
             context.manifest,
             sign(context.manifest, other),
             context.keys
           ) == {:error, :untrusted_signature}
  end

  test "refuses an edited manifest", context do
    edited = context.manifest <> "module Elixir.Sneaky beam-sha256 #{String.duplicate("0", 64)}\n"

    assert Signature.verify_beam(
             context.fixture,
             context.authentic,
             edited,
             context.signature,
             context.keys
           ) == {:error, :untrusted_signature}
  end

  test "refuses a manifest for another release", context do
    manifest = Signature.manifest_text([{context.fixture, context.authentic}], "0.0.1")
    private_key = :crypto.strong_rand_bytes(32)

    assert Signature.verify_beam(
             context.fixture,
             context.authentic,
             manifest,
             sign(manifest, private_key),
             [Signature.public_key(private_key)]
           ) == {:error, :wrong_release}
  end

  test "refuses a module the manifest does not cover", context do
    manifest = Signature.manifest_text([], ChorusDraft.version())
    private_key = :crypto.strong_rand_bytes(32)

    assert Signature.verify_beam(
             context.fixture,
             context.authentic,
             manifest,
             sign(manifest, private_key),
             [Signature.public_key(private_key)]
           ) == {:error, :unsigned_module}
  end

  test "this build's own Guard modules verify against the signature it shipped" do
    for module <- Guard.modules() do
      assert Signature.verify(module) == :ok
    end

    assert Signature.manifest() =~ "chorusdraft-guard-manifest/1"
    assert Signature.trusted_keys() != []
  end

  test "refuses the real Guard modules when their BEAM is patched" do
    for module <- Guard.modules() do
      {^module, beam, _path} = :code.get_object_code(module)

      assert Signature.verify_beam(
               module,
               patch(beam),
               Signature.manifest(),
               Signature.signature(),
               Signature.trusted_keys()
             ) == {:error, :digest_mismatch}
    end
  end

  test "digests ignore build metadata but not code" do
    {_module, safety, _path} = :code.get_object_code(ChorusDraft.Guard.Safety)
    {_module, pii, _path} = :code.get_object_code(ChorusDraft.Guard.PII)

    assert Signature.digest(safety) == Signature.digest(safety)
    assert Signature.digest(safety) != Signature.digest(pii)
    assert Signature.digest(safety) != Signature.digest(patch(safety))
    assert Signature.digest("not a beam file") == :error
  end

  test "reads and writes key and signature files" do
    private_key = :crypto.strong_rand_bytes(32)
    public_key = Signature.public_key(private_key)

    assert Signature.parse_private_key(Signature.encode_private_key(private_key)) ==
             {:ok, private_key}

    assert Signature.parse_public_key(Signature.encode_public_key(public_key)) ==
             {:ok, public_key}

    assert Signature.parse_public_key("# comment only\n") == :error
    assert Signature.parse_public_key("ed25519 " <> Base.encode64("short")) == :error
    assert Signature.parse_public_key(Signature.encode_private_key(private_key)) == :error
  end

  defp compile(source) do
    [{_module, beam} | _] = Code.compile_string(source)
    beam
  end

  defp sign(manifest, private_key) do
    Signature.encode_signature(Signature.sign(manifest, private_key))
  end

  defp patch(beam) do
    {:ok, _module, chunks} = :beam_lib.all_chunks(beam)

    patched =
      Enum.map(chunks, fn
        {~c"AtU8", data} -> {~c"AtU8", data <> <<0>>}
        chunk -> chunk
      end)

    {:ok, patched_beam} = :beam_lib.build_module(patched)
    patched_beam
  end
end
