require File.expand_path('../boot', __FILE__)

require "rails"

# Pick the frameworks you want:
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Example
  class Application < Rails::Application
    config.active_record.raise_in_transactional_callbacks = true
    config.cache_classes = false
    config.eager_load = false
    config.consider_all_requests_local       = true
    config.action_controller.perform_caching = false
    config.active_support.deprecation = :log
    config.active_record.migration_error = :page_load
  end
end
#
