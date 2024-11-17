Elasticsearch::Model.client = Elasticsearch::Client.new(
  host: ENV.fetch("ELASTICSEARCH_HOST", "http://localhost:9200/"),
  log: true,
  transport_options: {
    request: { timeout: 10 }
  }
)