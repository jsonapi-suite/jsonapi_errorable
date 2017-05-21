require 'spec_helper'

class CustomStatusError < StandardError;end
class CustomTitleError < StandardError;end
class MessageTrueError < StandardError;end
class MessageProcError < StandardError;end
class MetaProcError < StandardError;end
class LogFalseError < StandardError;end
class CustomHandlerError < StandardError;end
class SpecialPostError < StandardError;end

class CustomErrorHandler < JsonapiErrorable::ExceptionHandler
  def status_code(e)
    302
  end
end

class ApplicationController < ActionController::Base
  include JsonapiErrorable

  register_exception CustomStatusError,  status: 301
  register_exception CustomTitleError,   title: 'My Title'
  register_exception MessageTrueError,   message: true
  register_exception MessageProcError,   message: ->(e) { e.class.name.upcase }
  register_exception MetaProcError,      meta: ->(e) { { class_name: e.class.name.upcase } }
  register_exception LogFalseError,      log: false
  register_exception CustomHandlerError, handler: CustomErrorHandler

  rescue_from Exception do |e|
    handle_exception(e)
  end
end

class PostsController < ApplicationController
  def index
    render json: {}
  end
end

class SpecialPostsController < PostsController
  register_exception SpecialPostError, message: ->(e) { 'special post' }

  def index
    JsonapiErrorable.enable!
    raise SpecialPostError
  end
end

RSpec.describe 'jsonapi_errorable', type: :controller do
  controller(PostsController) { }

  def raises(klass, message)
    expect(controller).to receive(:index).and_raise(klass, message)
  end

  def error
    json['errors'][0]
  end

  def standard_detail
    "We've notified our engineers and hope to address this issue shortly."
  end

  context 'when a random error thrown' do
    before do
      raises(StandardError, 'some_error')
    end

    it 'gives stock jsonapi-compatible error response' do
      expect(Rails.logger).to receive(:error).twice
      get :index

      expect(response.status).to eq(500)
      expect(json).to eq({
        'errors'   => [
          'code'   => 'internal_server_error',
          'status' => '500',
          'title'  => 'Error',
          'detail' => standard_detail,
          'meta'   => {}
        ]
      })
    end
  end

  context 'when the error is registered' do
    context 'with custom status' do
      before do
        raises(CustomStatusError, 'some message')
      end

      it 'returns correct status code' do
        get :index
        expect(response.status).to eq(301)
        expect(error['status']).to eq('301')
        expect(error['code']).to eq('moved_permanently')
      end
    end

    context 'with custom title' do
      before do
        raises(CustomTitleError, 'some message')
      end

      it 'returns correct title' do
        get :index
        expect(error['title']).to eq('My Title')
      end
    end

    context 'with message == true' do
      before do
        raises(MessageTrueError, 'some message')
      end

      it 'shows error message thrown' do
        get :index
        expect(error['detail']).to eq('some message')
      end
    end

    context 'with message as proc' do
      before do
        raises(MessageProcError, 'some_error')
      end

      it 'shows custom error detail' do
        get :index
        expect(error['detail']).to eq('MESSAGEPROCERROR')
      end
    end

    context 'with meta as proc' do
      before do
        raises(MetaProcError, 'some_error')
      end

      it 'shows custom error detail' do
        get :index
        expect(error['meta']).to match('class_name' => 'METAPROCERROR')
      end
    end

    context 'with log: false' do
      before do
        expect(Rails.logger).to_not receive(:error)
      end

      it 'does not log the error' do
        raises(LogFalseError, 'some_error')
        get :index
      end
    end

    context 'with custom error handling class' do
      before do
        raises(CustomHandlerError, 'some message')
      end

      it 'returns status customized by that class' do
        get :index
        expect(response.status).to eq(302)
        expect(error['status']).to eq('302')
        expect(error['code']).to eq('found')
      end
    end
  end

  context 'when JsonapiErrorable disabled' do
    around do |e|
      JsonapiErrorable.disable!
      e.run
      JsonapiErrorable.enable!
    end

    before do
      raises(CustomStatusError, 'some message')
    end

    it 'raises exception normally' do
      expect(Rails.logger).to_not receive(:error)
      expect {
        get :index
      }.to raise_error(CustomStatusError, /some message/)
    end
  end

  context 'when subclass has its own registry' do
    before do
      raises(SpecialPostError, 'some_error')
    end

    context 'and parent controller is hit with that error' do
      it 'is not customized' do
        get :index, params: { error: 'SpecialPostError' }
        expect(error['detail']).to eq(standard_detail)
      end
    end

    context 'and subclass is hit with its registered error' do
      controller(SpecialPostsController) { }

      it 'customizes response' do
        get :index
        expect(error['detail']).to eq('special post')
      end
    end
  end
end
