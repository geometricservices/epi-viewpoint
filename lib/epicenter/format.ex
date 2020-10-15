defmodule Epicenter.Format do
  alias Epicenter.Cases.Address
  alias Epicenter.Cases.Phone
  alias Euclid.Extra

  def address(nil), do: ""

  def address(%Address{street: street, city: city, state: state, postal_code: postal_code}) do
    non_postal_code = [street, city, state] |> Extra.List.compact() |> Enum.join(", ")
    [non_postal_code, postal_code] |> Extra.List.compact() |> Enum.join(" ")
  end

  def date(nil), do: ""
  def date(%Date{} = date), do: "#{zero_pad(date.month, 2)}/#{zero_pad(date.day, 2)}/#{date.year}"

  def person(nil), do: ""
  def person(%{first_name: first_name, last_name: last_name}), do: [first_name, last_name] |> Euclid.Exists.join(" ")

  def phone(nil), do: ""
  def phone(%Phone{number: number}), do: phone(number)
  def phone(string) when is_binary(string), do: reformat_phone(string)

  # # #

  defp reformat_phone(string) when byte_size(string) == 10,
    do: string |> Number.Phone.number_to_phone(area_code: true)

  defp reformat_phone(string) when byte_size(string) == 11,
    do: string |> String.slice(1..-1) |> Number.Phone.number_to_phone(area_code: true, country_code: String.at(string, 0))

  defp reformat_phone(string),
    do: string

  defp zero_pad(value, zeros),
    do: String.pad_leading(to_string(value), zeros, "0")
end
