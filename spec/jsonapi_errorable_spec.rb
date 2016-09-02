require 'spec_helper'

describe JsonapiErrorable do
  let(:klass) do
    Class.new do
      include JsonapiErrorable
    end
  end

  let(:instance) { klass.new }

  it 'includes validatable' do
    expect(instance).to respond_to(:render_errors_for)
  end
end
