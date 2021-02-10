defmodule Epicenter.Test.AuditLogAssertions do
  import ExUnit.Assertions
  import Mox

  alias Epicenter.Test

  def expect_phi_view_logs(count) do
    Mox.verify_on_exit!()

    log_level = :info

    Test.PhiLoggerMock
    |> expect(log_level, count, fn message, metadata, unlogged_metadata ->
      Process.put(:phi_logger_messages, phi_logger_messages() ++ [{message, metadata, Keyword.put(unlogged_metadata, :log_level, log_level)}])
      :ok
    end)
  end

  def inspect_logs() do
    phi_logger_messages() |> IO.inspect(label: "phi_logger_messages")
  end

  # this function will only work if you call expect_phi_view_logs() before the subject action
  def refute_phi_view_logged(user, people) do
    for person <- List.wrap(people) do
      unexpected_log_text = "User(#{user.id}) viewed Person(#{person.id})"

      refute_receive({:logged, ^unexpected_log_text}, nil, "view unexpectedly logged for person: #{person.tid}")
    end
  end

  # this function will only work if you call expect_phi_view_logs() before the subject action
  def verify_phi_view_logged(user, person_or_people) do
    messages = phi_logger_messages() |> Enum.map(fn {message, _metadata, _unlogged_metadata} -> message end) |> MapSet.new()
    people = List.wrap(person_or_people)
    expected_messages = people |> Enum.map(&"User(#{user.id}) viewed Person(#{&1.id})") |> MapSet.new()

    unless MapSet.subset?(expected_messages, messages) do
      flunk """
      Expected phi logs to contain: #{expected_messages |> MapSet.to_list() |> inspect()}
      but got: #{messages |> MapSet.to_list() |> inspect()}
      """
    end
  end

  def phi_logger_messages(),
    do: Process.get(:phi_logger_messages, [])
end
