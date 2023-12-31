defmodule Streamer.Schema.Settings do
  @moduledoc """
  Schema that maps to Settings database table
  """
  use Ecto.Schema

  alias Streamer.Schema.StreamingStatusEnum

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "settings" do
    field(:symbol, :string)
    field(:status, StreamingStatusEnum)

    timestamps()
  end
end
