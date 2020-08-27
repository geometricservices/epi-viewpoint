defmodule EpicenterWeb.PeopleLive.Index do
  use EpicenterWeb, :live_view

  alias Epicenter.Cases
  alias Epicenter.Cases.Import.ImportInfo
  alias Epicenter.Cases.Person

  def mount(_params, _session, socket) do
    if connected?(socket),
      do: Cases.subscribe()

    socket |> set_reload_message(nil) |> set_filter(:all) |> load_people() |> ok()
  end

  def handle_params(%{"filter" => filter}, _url, socket) when filter in ~w{all call_list contacts},
    do: socket |> set_filter(filter) |> noreply()

  def handle_params(_, _url, socket),
    do: socket |> noreply()

  def handle_info({:import, %ImportInfo{imported_person_count: imported_person_count}}, socket),
    do: socket |> set_reload_message("Show #{imported_person_count} new people") |> noreply()

  def handle_event("refresh-people", _, socket),
    do: socket |> set_reload_message(nil) |> load_people() |> noreply()

  defp set_filter(socket, filter) when is_binary(filter),
    do: socket |> set_filter(Euclid.Extra.Atom.from_string(filter))

  defp set_filter(socket, filter) when is_atom(filter),
    do: socket |> assign(filter: filter, page_title: page_title(filter)) |> load_people()

  defp set_reload_message(socket, message),
    do: socket |> assign(reload_message: message)

  # # #

  defp ok(socket),
    do: {:ok, socket}

  defp noreply(socket),
    do: {:noreply, socket}

  # # #

  defp load_people(socket) do
    people = Cases.list_people(socket.assigns.filter) |> Cases.preload_lab_results()
    socket |> assign(people: people, person_count: length(people))
  end

  def latest_result(person),
    do: Person.latest_lab_result(person, :result)

  def latest_sample_date(person),
    do: Person.latest_lab_result(person, :sample_date)

  def page_title(:all), do: "People"
  def page_title(:call_list), do: "Call List"
  def page_title(:contacts), do: "Contacts"
end