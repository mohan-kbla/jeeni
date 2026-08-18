require_relative "boot"

require "rails/all"
module SpreeExtension
  class Migration
    def self.[](version)
      ActiveRecord::Migration[version]
    end
  end
end

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module EcomApp
  class Application < Rails::Application

    config.to_prepare do
      # Load application's model / class decorators
      Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end

      # Load application's view overrides
      Dir.glob(File.join(File.dirname(__FILE__), "../app/overrides/*.rb")) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end

      # Load Spree Auth Devise frontend controllers manually since spree_frontend is not present
      if Gem.loaded_specs['spree_auth_devise']
        gem_path = Gem.loaded_specs['spree_auth_devise'].full_gem_path
        %w[
          user_sessions_controller
          user_registrations_controller
          user_passwords_controller
          user_confirmations_controller
          users_controller
        ].each do |controller|
          require File.join(gem_path, "lib/controllers/frontend/spree", controller)
        end
      end
    end
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Kolkata"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
