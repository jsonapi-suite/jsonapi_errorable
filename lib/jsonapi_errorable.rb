require 'jsonapi/serializable'

require 'jsonapi_errorable/version'
require 'jsonapi_errorable/exception_handler'
require 'jsonapi_errorable/validatable'
require 'jsonapi_errorable/serializers/validation'

module JsonapiErrorable
  def self.included(klass)
    klass.class_eval do
      class << self
        attr_accessor :_errorable_registry
      end

      def self.inherited(subklass)
        subklass._errorable_registry = self._errorable_registry.dup
      end
    end
    klass._errorable_registry = {}
    klass.send(:include, Validatable)
    klass.extend ClassMethods
  end

  def self.disable!
    @enabled = false
  end

  def self.enable!
    @enabled = true
  end

  def self.disabled?
    @enabled == false
  end

  def self.logger
    @logger ||= defined?(Rails) ? Rails.logger : Logger.new($stdout)
  end

  def self.logger=(logger)
    @logger = logger
  end

  def handle_exception(e)
    raise e if JsonapiErrorable.disabled?

    exception_klass = self.class._errorable_registry[e.class] || default_exception_handler.new
    exception_klass.log(e)
    json   = exception_klass.error_payload(e)
    status = exception_klass.status_code(e)
    render json: json, status: status
  end

  def default_exception_handler
    self.class.default_exception_handler
  end

  module ClassMethods
    def register_exception(klass, options = {})
      exception_klass = options[:handler] || default_exception_handler
      self._errorable_registry[klass] = exception_klass.new(options)
    end

    def default_exception_handler
      JsonapiErrorable::ExceptionHandler
    end
  end
end
