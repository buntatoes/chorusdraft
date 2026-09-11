defmodule Mix.Tasks.Guard.Keygen do
  @shortdoc "Generates an ed25519 key pair for signing ChorusDraft Guard"

  @moduledoc """
  Generates an ed25519 key pair for signing the proprietary Guard modules.

      mix guard.keygen --out /secure/path/chorusdraft-guard-release.key

  Writes the private key to `--out` (owner-readable only) and the public key to
  `--pub`, which defaults to `<out>.pub`. Neither file is overwritten if it
  already exists.

  The private key belongs offline, with whoever cuts releases. Copy the public
  key into `guard/keys/` and commit it: that is what every build verifies
  against.
  """

  use Mix.Task

  alias ChorusDraft.Guard.Signature

  @impl Mix.Task
  def run(argv) do
    {options, [], []} = OptionParser.parse(argv, strict: [out: :string, pub: :string])

    private_path = options[:out] || Mix.raise("mix guard.keygen requires --out PATH")
    public_path = options[:pub] || private_path <> ".pub"

    for path <- [private_path, public_path] do
      if File.exists?(path), do: Mix.raise("Refusing to overwrite #{path}")
    end

    private_key = :crypto.strong_rand_bytes(32)

    File.mkdir_p!(Path.dirname(private_path))
    File.write!(private_path, Signature.encode_private_key(private_key))
    File.chmod!(private_path, 0o600)

    File.mkdir_p!(Path.dirname(public_path))
    File.write!(public_path, Signature.encode_public_key(Signature.public_key(private_key)))

    Mix.shell().info("Private signing key: #{private_path} (keep this offline, never commit it)")
    Mix.shell().info("Public verifying key: #{public_path} (copy into guard/keys/ and commit)")
  end
end
