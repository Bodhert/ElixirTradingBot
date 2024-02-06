defmodule DataWarehouse.Schema.SubscriberSettings do
  @moduledoc """
  Schema that maps to Settings database table
  """
  use Ecto.Schema

  alias DataWarehouse.Schema.SubscriberStatusEnum

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "subscriber_settings" do
    field(:topic, :string)
    field(:status, SubscriberStatusEnum)

    timestamps()
  end
end
