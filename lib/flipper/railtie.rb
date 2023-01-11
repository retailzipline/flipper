module Flipper
  class Railtie < Rails::Railtie
    config.before_configuration do
      config.flipper = ActiveSupport::OrderedOptions.new.update(
        env_key: ENV.fetch('FLIPPER_ENV_KEY', 'flipper'),
        memoize: ENV.fetch('FLIPPER_MEMOIZE', 'true').casecmp('true').zero?,
        preload: ENV.fetch('FLIPPER_PRELOAD', 'true').casecmp('true').zero?,
        instrumenter: ENV.fetch('FLIPPER_INSTRUMENTER', 'ActiveSupport::Notifications').constantize,
        log: ENV.fetch('FLIPPER_LOG', 'true').casecmp('true').zero?
      )
    end

    config.before_initialize do |app|
      Flipper.configure do |config|
        config.default do
          Flipper.new(config.adapter, instrumenter: app.config.flipper.instrumenter)
        end
      end

      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Base.include Flipper::Identifier
      end
    end

    initializer "flipper.memoizer" do |app|
      flipper = app.config.flipper

      app.middleware.use Flipper::Middleware::Memoizer, {
        env_key: flipper.env_key,
        preload: flipper.preload,
        if: flipper.memoize.respond_to?(:call) ? flipper.memoize : nil
      }
    end

    config.after_initialize do
      if config.flipper.log && config.flipper.instrumenter == ActiveSupport::Notifications
        require "flipper/instrumentation/log_subscriber"
      end
    end
  end
end
