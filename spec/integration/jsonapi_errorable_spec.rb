require 'spec_helper'

class CustomStatusError < StandardError;end

RSpec.describe 'jsonapi_errorable', type: :request do
  def json
    JSON.parse(response.body)
  end

  def error
    json['errors'][0]
  end

  def standard_detail
    "We've notified our engineers and hope to address this issue shortly."
  end

  context 'when a random error thrown' do
    it 'gives stock jsonapi-compatible error response' do
      expect(Rails.logger).to receive(:error).twice
      get '/posts', params: { basic: true }

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
      it 'returns correct status code' do
        get '/posts', params: { error: 'CustomStatusError' }
        expect(response.status).to eq(301)
        expect(error['status']).to eq('301')
        expect(error['code']).to eq('moved_permanently')
      end
    end

    context 'with custom title' do
      it 'returns correct title' do
        get '/posts', params: { error: 'CustomTitleError' }
        expect(error['title']).to eq('My Title')
      end
    end

    context 'with message == true' do
      it 'shows error message thrown' do
        get '/posts', params: { error: 'MessageTrueError' }
        expect(error['detail']).to eq('some message')
      end
    end

    context 'with message as proc' do
      it 'shows custom error detail' do
        get '/posts', params: { error: 'MessageProcError' }
        expect(error['detail']).to eq('MESSAGEPROCERROR')
      end
    end

    context 'with log: false' do
      it 'does not log the error' do
        expect(Rails.logger).to_not receive(:error)
        get '/posts', params: { error: 'LogFalseError' }
      end
    end

    context 'with custom error handling class' do
      it 'returns status customized by that class' do
        get '/posts', params: { error: 'CustomHandlerError' }
        expect(response.status).to eq(302)
        expect(error['status']).to eq('302')
        expect(error['code']).to eq('found')
      end
    end
  end

  context 'when JsonapiErrorable disabled' do
    it 'raises exception normally' do
      expect(Rails.logger).to_not receive(:error)
      expect {
        get '/posts', params: { disable: true, error: 'CustomStatusError' }
      }.to raise_error(CustomStatusError, /some message/)
    end
  end

  context 'when subclass has its own registry' do
    context 'and parent controller is hit with that error' do
      it 'is not customized' do
        get '/posts', params: { error: 'SpecialPostError' }
        expect(error['detail']).to eq(standard_detail)
      end
    end

    context 'and subclass is hit with its registered error' do
      it 'customizes response' do
        get '/special_posts'
        expect(error['detail']).to eq('special post')
      end
    end
  end
end
