require 'spec_helper'

RSpec.describe JsonapiErrorable::Serializers::Validation do
  let(:errors_hash) { { username: ["can't be blank"] } }

  let(:object) { double(id: 123).as_null_object }
  let(:instance) { described_class.new(object) }

  before do
    allow(instance).to receive(:activerecord?) { true }
    allow(object.class)
      .to receive(:reflect_on_all_associations)
      .and_return([double(name: :pets)])
    allow(object).to receive_message_chain(:errors, :to_hash) { errors_hash }
  end

  describe '#errors' do
    subject { instance.errors }

    before do
      allow(object).to receive(:respond_to?).with(:username) { true }
    end

    context 'when the error is on an attribute' do
      it 'renders valid JSONAPI error format' do
        expect(subject).to eq(
          [
            {
              code:  'unprocessable_entity',
              status: '422',
              title: "Validation Error",
              detail: "Username can't be blank",
              source: { pointer: '/data/attributes/username' },
              meta: {
                attribute: :username,
                message: "can't be blank"
              }
            }
          ]
        )
      end
    end

    context 'when the error is on a relationship' do
      let(:errors_hash) { { pets: ["is invalid"] } }

      it 'puts the source pointer on relationships' do
        expect(subject).to eq(
          [
            {
              code:  'unprocessable_entity',
              status: '422',
              title: 'Validation Error',
              detail: 'Pets is invalid',
              source: { pointer: '/data/relationships/pets' },
              meta: { attribute: :pets, message: 'is invalid' }
            }
          ]
        )
      end

      context 'but the object is not activerecord' do
        before do
          allow(instance).to receive(:activerecord?) { false }
          allow(object).to receive(:respond_to?).with(:pets) { true }
        end

        it 'places the error on attribute' do
          expect(subject).to eq(
            [
              {
                code:  'unprocessable_entity',
                status: '422',
                title: 'Validation Error',
                detail: 'Pets is invalid',
                source: { pointer: '/data/attributes/pets' },
                meta: { attribute: :pets, message: 'is invalid' }
              }
            ]
          )
        end

        context 'but the object does not respond to this property' do
          before do
            allow(object).to receive(:respond_to?).with(:pets) { false }
          end

          it 'defaults to relationship' do
            expect(subject).to eq(
              [
                {
                  code:  'unprocessable_entity',
                  status: '422',
                  title: 'Validation Error',
                  detail: 'Pets is invalid',
                  source: { pointer: '/data/relationships/pets' },
                  meta: { attribute: :pets, message: 'is invalid' }
                }
              ]
            )
          end
        end
      end
    end

    context 'when the error is neither a relationship or attribute of the object' do
      let(:errors_hash) { { :'foo.bar' => ["is invalid"] } }

      before do
        allow(object).to receive(:respond_to?).with(:'foo.bar') { false }
      end

      it 'puts the source pointer on relationships' do
        expect(subject).to eq(
          [
            {
              code:  'unprocessable_entity',
              status: '422',
              title: 'Validation Error',
              detail: 'Foo.bar is invalid',
              source: { pointer: '/data/relationships/foo.bar' },
              meta: { attribute: :'foo.bar', message: 'is invalid' }
            }
          ]
        )
      end
    end
  end

  describe '#relationship?' do
    subject { instance.relationship?(:pets) }

    context 'when activerecord' do
      context 'and is a valid relation' do
        it { is_expected.to be(true) }
      end

      context 'but not a valid relation' do
        before do
          allow(object.class).to receive(:reflect_on_all_associations) { [] }
        end

        it { is_expected.to be(false) }
      end
    end

    context 'when not activerecord' do
      before do
        allow(instance).to receive(:activerecord?) { false }
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#attribute?' do
    subject { instance.attribute?(:foo) }

    context 'when object responds to name' do
      before do
        allow(object).to receive(:respond_to?).with(:foo) { true }
      end

      it { is_expected.to be(true) }
    end

    context 'when object does not respond to name' do
      before do
        allow(object).to receive(:respond_to?).with(:foo) { false }
      end

      it { is_expected.to be(false) }
    end
  end
end
