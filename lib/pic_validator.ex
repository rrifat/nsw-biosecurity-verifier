defmodule PicValidator do
  @moduledoc """
  Validates NSW Property Identification Code (PIC) format.
  PIC must be 8 alphanumeric characters (letters and digits).
  Uses pattern matching and function clauses only.
  """

  @pic_byte_size 8

  def validate(pic) when is_binary(pic) and byte_size(pic) == @pic_byte_size do
    case alphanumeric?(pic) do
      true -> {:ok, pic}
      false -> {:error, :invalid_characters}
    end
  end

  def validate(pic) when is_binary(pic) and byte_size(pic) != @pic_byte_size,
    do: {:error, :wrong_length}

  def validate(pic) when is_binary(pic),
    do: {:error, :invalid_characters}

  def validate(_),
    do: {:error, :not_a_string}

  def valid?(pic), do: match?({:ok, _}, validate(pic))

  defp alphanumeric?(<<>>), do: true

  defp alphanumeric?(<<c, rest::binary>>)
       when c in ?A..?Z or c in ?a..?z or c in ?0..?9,
       do: alphanumeric?(rest)

  defp alphanumeric?(_), do: false
end
