defmodule ChorusDraft do
  @moduledoc "Shared runtime for ChorusDraft on Linux, macOS, and Windows."
  @version "0.52.1"
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
