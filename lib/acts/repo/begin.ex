if Code.ensure_loaded?(Bonfire.Common.Utils) do
  defmodule Bonfire.Epics.Acts.Repo.Begin do
    @moduledoc """
    An Act that enters a transaction if there are no changeset errors
    """
    import Where
    import Bonfire.Common.Utils
    alias Bonfire.Epics
    alias Bonfire.Epics.{Act, Acts.Repo.Commit, Epic}
    import Epics

    def run(epic, act) do
      # take all the modules before commit and run them, then return the remainder.
      {next, rest} = Enum.split_while(epic.next, &(&1.module != Commit))
      rest = Enum.drop(rest, 1) # drop commit if there are any items left
      nested = %{ epic | next: next }
      # if there are already errors, we will assume nothing is going to write and skip the transaction.
      if epic.errors == [] do
        maybe_debug(act, "entering transaction", "repo")
        Bonfire.Repo.transact_with(fn ->
          epic = Epic.run(nested)
          if epic.errors == [], do: {:ok, epic}, else: {:error, epic}
        end)
        |> case do
          {:ok, epic} ->
            maybe_debug(act, "committed successfully", "repo")
            %{ epic | next: rest }
          {:error, epic} ->
            maybe_debug(act, "rollback because of errors", "repo")
            %{ epic | next: rest }
        end
      else
        maybe_debug(act, epic.errors, "not entering transaction because of errors")
        Epic.run(nested)
        %{ epic | next: rest }
      end
    end
  end
end
