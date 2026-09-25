client = URLCategorizationDatabase.Client.new(System.fetch_env!("AQ_API_KEY"))
IO.inspect(URLCategorizationDatabase.Client.classify(client, "bbc.com"))
