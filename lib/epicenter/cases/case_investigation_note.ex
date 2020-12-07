defmodule Epicenter.Cases.CaseInvestigationNote do
  use Ecto.Schema
  import Ecto.Changeset

  @required_attrs ~w{author_id text}a
  @optional_attrs ~w{case_investigation_id deleted_at exposure_id tid}a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @derive {Jason.Encoder, only: [:id] ++ @required_attrs ++ @optional_attrs}

  schema "case_investigation_notes" do
    field :deleted_at, :utc_datetime
    field :seq, :integer, read_after_writes: true
    field :text, :string
    field :tid, :string

    belongs_to :author, Epicenter.Accounts.User
    belongs_to :case_investigation, Epicenter.Cases.CaseInvestigation
    belongs_to :exposure, Epicenter.Cases.Exposure

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(case_investigation_note, attrs) do
    case_investigation_note
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
  end
end
