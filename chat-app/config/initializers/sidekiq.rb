redis_cfg = {
  url: "redis://#{ENV.fetch("REDIS_HOST")}:#{ENV.fetch("REDIS_PORT")}/#{ENV.fetch("REDIS_DB")}",
  timeout: 2.0
}

Sidekiq.configure_server do |config|
  config.redis = redis_cfg
  config.average_scheduled_poll_interval = 5
end

Sidekiq.configure_client do |config|
  config.redis = redis_cfg
end