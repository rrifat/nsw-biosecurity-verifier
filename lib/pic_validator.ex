defmodule PicValidator do
  @moduledoc """
  Validates NSW NLIS Property Identification Code (PIC) format.
  PIC must be 8 alphanumeric characters; first 2 must be an allowed prefix
  (NA–NZ excluding NI). Uses pattern matching and function clauses only.
  """

  @pic_byte_size 8

  @allowed_prefixes [
    "NA", "NB", "NC", "ND", "NE", "NF", "NG", "NH", "NJ", "NK",
    "NL", "NM", "NN", "NP", "NQ", "NR", "NS", "NT", "NU", "NV",
    "NW", "NX", "NY", "NZ"
  ]

  def validate(pic) when is_binary(pic) and byte_size(pic) == @pic_byte_size do
    case alphanumeric?(pic) do
      true -> check_prefix(pic)
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

  def generate_pic do
    prefix = Enum.random(@allowed_prefixes)
    suffix = for _ <- 1..6, into: <<>>, do: <<random_alphanumeric()>>
    prefix <> suffix
  end

  def generate_pic_different_from(other) when is_binary(other) do
    pic = generate_pic()
    case pic do
      ^other -> generate_pic_different_from(other)
      _ -> pic
    end
  end

  defp check_prefix(<<prefix::binary-size(2), _rest::binary>> = pic) do
    case prefix in @allowed_prefixes do
      true -> {:ok, pic}
      false -> {:error, :invalid_prefix}
    end
  end

  defp alphanumeric?(<<>>), do: true

  defp alphanumeric?(<<c, rest::binary>>)
       when c in ?A..?Z or c in ?a..?z or c in ?0..?9,
       do: alphanumeric?(rest)

  defp alphanumeric?(_), do: false

  @alphanumeric ~c/ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789/

  defp random_alphanumeric do
    Enum.at(@alphanumeric, :rand.uniform(62) - 1)
  end
end
