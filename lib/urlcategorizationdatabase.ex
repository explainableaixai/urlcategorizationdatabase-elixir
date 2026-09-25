defmodule URLCategorizationDatabase.Client do
  @moduledoc "Client for URL Categorization Database."
  defstruct [:api_key, :base_url]

  def new(api_key, opts \\ []) when is_binary(api_key) and byte_size(api_key) > 0,
    do: %__MODULE__{
      api_key: api_key,
      base_url:
        Keyword.get(opts, :base_url, "https://www.websitecategorizationapi.com/api")
        |> String.trim_trailing("/")
    }

  defp request(client, value) when is_binary(value) and byte_size(value) > 0 do
    case Req.post(client.base_url <> "/iab/iab_web_content_filtering.php",
           form: [{"query", value}, {"data_type", "url"}, {"api_key", client.api_key}]
         ) do
      {:ok, %Req.Response{status: s, body: body}} when s in 200..299 -> {:ok, body}
      {:ok, %Req.Response{status: s, body: body}} -> {:error, {:api_error, s, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  def classify(client, value), do: request(client, value)
end
