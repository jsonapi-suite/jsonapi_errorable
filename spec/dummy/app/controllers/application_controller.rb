class CustomStatusError < StandardError;end
class CustomTitleError < StandardError;end
class MessageTrueError < StandardError;end
class MessageProcError < StandardError;end
class LogFalseError < StandardError;end
class CustomHandlerError < StandardError;end
class SpecialPostError < StandardError;end

class ApplicationController < ActionController::Base
  include JsonapiErrorable

  class CustomErrorHandler < JsonapiErrorable::ExceptionHandler
    def status_code(e)
      302
    end
  end

  register_exception CustomStatusError,  status: 301
  register_exception CustomTitleError,   title: 'My Title'
  register_exception MessageTrueError,   message: true
  register_exception MessageProcError,   message: ->(e) { e.class.name.upcase }
  register_exception LogFalseError,      log: false
  register_exception CustomHandlerError, handler: CustomErrorHandler

  rescue_from Exception do |e|
    handle_exception(e)
  end
end
