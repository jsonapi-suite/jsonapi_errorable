module JsonapiErrorable
  class ExceptionHandler
    def initialize(options = {})
      @status  = options[:status]
      @title   = options[:title]
      @message = options[:message]
      @log     = options[:log]
    end

    def status_code(error)
      @status || 500
    end

    def error_code(error)
      status_code = status_code(error)
      Rack::Utils::SYMBOL_TO_STATUS_CODE.invert[status_code]
    end

    def backtrace_cleaner
      defined?(Rails) ? Rails.backtrace_cleaner : nil
    end

    def title
      @title || 'Error'
    end

    def detail(error)
      if @message == true
        error.message
      else
        @message ? @message.call(error) : default_detail
      end
    end

    def meta(error)
      {}
    end

    def error_payload(error)
      {
        errors: [
          code: error_code(error),
          status: status_code(error).to_s,
          title: title,
          detail: detail(error),
          meta: meta(error)
        ]
      }
    end

    def log?
      @log != false
    end

    def log(error)
      return unless log?
      backtrace = error.backtrace

      if cleaner = backtrace_cleaner
        backtrace = cleaner.clean(backtrace)
      end

      log_error(error, backtrace)
    end

    private

    def log_error(e, backtrace)
      logger.error "\033[31mERROR: #{e.class}: #{e.message}\033[0m"
      logger.error "\033[31m#{backtrace.join("\n")}\033[0m"
    end

    def logger
      JsonapiErrorable.logger
    end

    def default_detail
      "We've notified our engineers and hope to address this issue shortly."
    end
  end
end
