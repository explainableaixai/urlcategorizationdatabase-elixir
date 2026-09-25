# URLCategorizationDatabase

Elixir client for content classification of domains and URLs. It is meant to run next to a licensed category file: the file covers known domains offline, and this client classifies whatever the file lacks. Product details and file formats are on the [URL categorization database pricing](https://www.urlcategorizationdatabase.com/pricing.php) page.

## Installation

```elixir
{:urlcategorizationdatabase, "~> 1.0"}
```

## Classify

```elixir
client = URLCategorizationDatabase.Client.new(System.fetch_env!("AQ_API_KEY"))
{:ok, body} = URLCategorizationDatabase.Client.classify(client, "arstechnica.com")
```

`classify/2` posts `query`, `data_type=url` and the key as a form to the classification endpoint. `body` is the decoded JSON map. Its fields follow the API reference on the website, since the client passes them through unchanged.

The endpoint reports problems in the body as well as through the status, for example a `"status"` of 401 together with a message when the key is missing. Check both:

```elixir
case URLCategorizationDatabase.Client.classify(client, host) do
  {:ok, %{"status" => s} = b} when is_integer(s) and s >= 400 -> {:error, {:api_error, s, b}}
  {:ok, %{"detail" => _} = b} -> {:error, {:api_error, :unknown, b}}
  other -> other
end
```

## An enrichment pipeline with Oban

Most real work is a table of domains that need a category column. Oban turns that into durable, retryable jobs:

```elixir
defmodule MyApp.Workers.Categorize do
  use Oban.Worker, queue: :categorize, max_attempts: 5

  @impl true
  def perform(%Oban.Job{args: %{"domain" => domain}}) do
    client = URLCategorizationDatabase.Client.new(Application.fetch_env!(:my_app, :ucd_key))

    case URLCategorizationDatabase.Client.classify(client, domain) do
      {:ok, body} ->
        MyApp.Sites.put_categories(domain, body)

      {:error, {:api_error, 429, _}} ->
        {:snooze, 60}

      {:error, {:api_error, status, _}} when status in [401, 403] ->
        {:cancel, :key_or_quota}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

Set the queue limit to a small number, for example `categorize: 4`, to bound concurrency. `{:snooze, 60}` backs off on rate limits without using up attempts. `{:cancel, ...}` stops jobs that cannot succeed until a person fixes the key. Oban's own retry handles everything else.

## Enqueueing only what is missing

```elixir
Repo.all(from s in Site, where: is_nil(s.categories), select: s.domain)
|> Enum.map(&MyApp.Workers.Categorize.new(%{"domain" => &1}))
|> Oban.insert_all()
```

Before enqueueing, remove domains the licensed file already covers. Every call you skip saves quota.

## Normalising domains

Lower-case, drop the scheme, path and a leading `www.`, and store that as the key:

```elixir
def normalise(raw) do
  raw = if String.contains?(raw, "://"), do: raw, else: "https://" <> raw
  raw |> URI.parse() |> Map.fetch!(:host) |> String.downcase() |> String.replace_prefix("www.", "")
end
```

On analytics and CRM data this often collapses many rows into far fewer unique domains.

## Choosing granularity

Pass the registered domain for one label per site. Pass the full host on platforms where subdomains are separate sites. Pass a full URL when individual pages differ, as on large publishers. Mixing forms in one table makes joins unreliable, so pick one per dataset.

## Keeping results current

Store the full response body in a `:map` (jsonb) column with a `categorized_at` timestamp. Re-enqueue rows older than a few months, oldest first. When a new release of the licensed file arrives, clear live results for domains it now covers, so the file stays the reference and your table holds only the gaps.

## Return values

| Value | Meaning |
|---|---|
| `{:ok, map}` | HTTP 2xx. Still check the body for an error field |
| `{:error, {:api_error, status, body}}` | HTTP error status |
| `{:error, exception}` | Transport error |

`new/2` and `classify/2` require non-empty binaries and raise `FunctionClauseError` otherwise. Requests use `Req.post/2`, and Req does not retry POST requests by default, so retrying is up to your job runner. Oban is a good fit for that.

## Options

`new(key, base_url: url)` changes the endpoint base, which helps with testing against a local stub. The key travels in the form body over HTTPS, which is what the endpoint expects.

## Typical uses

- CRM enrichment: tag company websites with an industry before routing leads.
- Analytics: add a topic dimension to referrer and outbound-link reports.
- Ad operations: screen domain lists before a campaign.
- Security reporting: label traffic by topic, while blocking decisions use [K-12 web filtering categories](https://www.webfilteringdatabase.com/categories-web-filtering.php) in schools and enterprise categories elsewhere.

## AI traffic

General content taxonomies file AI products under software. [AI data leakage prevention tools](https://www.aitoolsblocklist.com/ai-data-loss-prevention.php) need that AI flag, which takes one more lookup against the AI register. For [detecting shadow AI](https://www.shadowaitools.com/detection-methodology.php) across resolver data, the log audit does the counting.

Other clients: [Go](https://pkg.go.dev/github.com/explainableaixai/urlcategorizationdatabase-go), [Dart](https://pub.dev/packages/urlcategorizationdatabase) and [PHP](https://packagist.org/packages/urlcategorizationdatabase/urlcategorizationdatabase).

## License

MIT. IAB Tech Lab taxonomy names appear for compatibility only.
