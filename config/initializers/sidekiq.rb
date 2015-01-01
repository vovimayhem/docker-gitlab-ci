# Custom Redis configuration

redis_config = {
  url: ENV['REDIS_URL'],
  namespace: 'resque:gitlab_ci'
}

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end
