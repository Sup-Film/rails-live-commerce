class ApplicationLoggerService
  class << self
    def info(message, context = {})
      log(:info, message, context)
    end

    def warn(message, context = {})
      log(:warn, message, context)
    end

    def error(message, context = {})
      log(:error, message, context)
    end

    def debug(message, context = {})
      log(:debug, message, context)
    end

    # สำหรับ log การทำงานของ business logic
    def business_event(event_name, details = {})
      log(:info, "Business Event: #{event_name}", {
        event: event_name,
        timestamp: Time.current.iso8601,
        **details,
      })
    end

    def performance(action, duration, context = {})
      log(:info, "Performance: #{action}", {
        action: action,
        duration_ms: duration,
        performance: true,
        **context,
      })
    end

    private

    def log(level, message, context)
      formatted_context = context.empty? ? "" : " | Context: #{context.to_json}"
      Rails.logger.send(level, "#{message}#{formatted_context}")
    end
  end
end
