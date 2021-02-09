defmodule Epicenter.Cases.Person.Search do
  import Ecto.Query

  alias Epicenter.Cases
  alias Epicenter.Cases.Person
  alias Epicenter.Cases.Demographic
  alias Epicenter.Repo

  def find(search_string) do
    case is_uuid?(search_string) do
      true ->
        find_matching_people(:person_id, [search_string], downcase: false)

      false ->
        search_tokens = search_string |> String.split(" ") |> Enum.map(&String.trim/1) |> Enum.map(&String.downcase/1)

        external_id_matches =
          find_matching_people(:external_id, search_tokens, downcase: false)
          |> Cases.preload_demographics()

        first_name_matches =
          find_matching_people(:first_name, search_tokens)
          |> Cases.preload_demographics()
          |> Enum.filter(&coalesced_field_matches?(&1, :first_name, search_tokens))

        last_name_matches =
          find_matching_people(:last_name, search_tokens)
          |> Cases.preload_demographics()
          |> Enum.filter(&coalesced_field_matches?(&1, :last_name, search_tokens))

        (external_id_matches ++ first_name_matches ++ last_name_matches)
        |> Enum.uniq()
        |> Enum.sort_by(&full_name/1)
    end
  end

  def coalesced_field_matches?(person, field, search_tokens) do
    demographic = person |> Person.coalesce_demographics()
    search_tokens |> Enum.member?(String.downcase(demographic[field]))
  end

  def full_name(person) do
    demographic = person |> Person.coalesce_demographics()
    [demographic.first_name, demographic.last_name] |> Enum.join(" ")
  end

  defp is_uuid?(term) do
    String.match?(term, ~r/[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}/)
  end

  def find_matching_people(field, search_tokens, opts \\ []) do
    downcase? = Keyword.get(opts, :downcase, true)

    query =
      from demographic in Demographic,
        select: demographic.person_id,
        distinct: true

    query =
      if downcase?,
        do: query |> where([d], fragment("lower(?)", field(d, ^field)) in ^search_tokens),
        else: query |> where([d], field(d, ^field) in ^search_tokens)

    query
    |> Repo.all()
    |> Person.Query.get_people()
    |> Person.Query.reject_archived_people(true)
    |> Repo.all()
  end
end
