defmodule ChorusDraft do
  @moduledoc "Shared runtime for the Linux, macOS, and Windows Elixir testing builds."
  @version "0.52.0-testing"
  def version, do: @version
end

defmodule ChorusDraft.Error do
  defexception [:message]
end

defmodule ChorusDraft.HTTPError do
  defexception [:message, :status]

  def exception(status) do
    %__MODULE__{
      status: status,
      message:
        "Remote request failed (HTTP #{status}); response omitted to protect credentials and content."
    }
  end
end
