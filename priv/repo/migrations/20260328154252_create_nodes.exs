defmodule WCore.Repo.Migrations.CreateNodes do
  use Ecto.Migration

  def change do
    create table(:nodes) do
      add :machine_identifier, :string, null: false
      add :location, :string, null: false

      timestamps()
    end

    create unique_index(:nodes, [:machine_identifier])
  end
end
