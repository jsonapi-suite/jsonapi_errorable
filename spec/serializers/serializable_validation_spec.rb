require 'spec_helper'
require 'active_model'

RSpec.describe JsonapiErrorable::Serializers::Validation do
  let(:klass) do
    Class.new do
      def self.name;'Dummy';end # required for anonymous class
      # users
      attr_accessor :id, :username, :pets
      # pets
      attr_accessor :name, :favorite_toy
      # toys
      attr_accessor :cost
      include ActiveModel::Validations

      def initialize(attrs = {})
        attrs.each_pair { |k,v| send("#{k}=", v) }
      end
    end
  end

  let(:object)   { klass.new }
  let(:instance) { described_class.new(object) }

  def assert_error(actual, expected)
    if Rails::VERSION::MAJOR < 5
      expected[:meta].delete(:code)

      if relationship = expected[:meta][:relationship]
        relationship.delete(:code)
      end
    end

    expect(actual).to eq(expected)
  end

  def assert_errors(actual, expected)
    expect(actual.length).to eq(expected.length)
    actual.each_with_index do |a, index|
      assert_error(a, expected[index])
    end
  end

  describe '#errors' do
    subject { instance.errors }

    context 'when the error is on an attribute' do
      before do
        object.errors.add(:username, :blank, message: "can't be blank")
      end

      it 'renders valid JSONAPI error format' do
        assert_errors(subject, [
          {
            code:  'unprocessable_entity',
            status: '422',
            title: "Validation Error",
            detail: "Username can't be blank",
            source: { pointer: '/data/attributes/username' },
            meta: {
              attribute: :username,
              message: "can't be blank",
              code: :blank
            }
          }
        ])
      end
    end

    context 'when the error attribute is "base"' do
      before do
        object.errors.add(:base, :invalid, message: 'Model is invalid')
      end

      it 'should not render the attribute in the message detail' do
        assert_errors(subject, [{
          code:  'unprocessable_entity',
          status: '422',
          title: "Validation Error",
          detail: "Model is invalid",
          source: { pointer: nil },
          meta: {
            attribute: :base,
            message: "Model is invalid",
            code: :invalid
          }
        }])
      end
    end

    context 'when the error is on a relationship' do
      before do
        klass.class_eval do
          attr_accessor :pets
          validates :pets, presence: true
        end
        object.errors.add(:pets, :invalid, message: 'is invalid')
      end

      context 'and the object is activerecord' do
        before do
          allow(object.class).to receive(:reflect_on_all_associations)
            .and_return([double(name: :pets)])
        end

        it 'puts the source pointer on the relationship' do
          assert_errors(subject, [{
            code:  'unprocessable_entity',
            status: '422',
            title: 'Validation Error',
            detail: 'Pets is invalid',
            source: { pointer: '/data/relationships/pets' },
            meta: {
              attribute: :pets,
              message: 'is invalid',
              code: :invalid
            }
          }])
        end
      end

      context 'and the object is not activerecord' do
        context 'but it defines #relationship_names' do
          before do
            klass.class_eval do
              def relationship_names
                [:pets]
              end
            end
          end

          it 'puts the source pointer on the relationship' do
            assert_errors(subject, [{
              code:  'unprocessable_entity',
              status: '422',
              title: 'Validation Error',
              detail: 'Pets is invalid',
              source: { pointer: '/data/relationships/pets' },
              meta: {
                attribute: :pets,
                message: 'is invalid',
                code: :invalid
              }
            }])
          end
        end

        # We have no way to tell this is a relationship :(
        context 'and it does not define #relationship_names' do
          it 'puts the source pointer on attributes' do
            assert_errors(subject, [{
              code:  'unprocessable_entity',
              status: '422',
              title: 'Validation Error',
              detail: 'Pets is invalid',
              source: { pointer: '/data/attributes/pets' },
              meta: {
                attribute: :pets,
                message: 'is invalid',
                code: :invalid
              }
            }])
          end
        end
      end
    end

    context 'when the object does not respond to the attribute' do
      before do
        object.errors.add(:"foo.bar", 'is invalid')
      end

      it 'is treated as a nested relationship' do
        assert_errors(subject, [{
          code:  'unprocessable_entity',
          status: '422',
          title: 'Validation Error',
          detail: 'Foo bar is invalid',
          source: { pointer: '/data/relationships/foo.bar' },
          meta: {
            attribute: :"foo.bar",
            message: 'is invalid',
            code: 'is invalid'
          }
        }])
      end
    end

    context 'when the error is on a sideposted object' do
      let(:relationship_params) do
        {
          pets: [{
            meta: {
              id: '444',
              jsonapi_type: 'pets'
            },
            relationships: {
              favorite_toy: {
                meta: {
                  id: '555',
                  jsonapi_type: 'toys'
                }
              }
            }
          }]
        }
      end

      let(:instance) { described_class.new(object, relationship_params) }

      let(:toy) { klass.new(id: '555') }
      let(:pet) { klass.new(id: '444', favorite_toy: toy) }

      before do
        toy.errors.add(:cost, :too_high, message: "is too high")
        pet.errors.add(:name, :blank, message: "can't be blank")
        object.pets = [pet]
      end

      it 'stores the error under meta > relationship' do
        assert_error(subject[0], {
          code:  'unprocessable_entity',
          status: '422',
          title: 'Validation Error',
          detail: "Name can't be blank",
          source: { pointer: '/data/attributes/name' },
          meta: {
            relationship: {
              attribute: :name,
              message: "can't be blank",
              code: :blank,
              name: :pets,
              id: '444',
              type: 'pets'
            }
          }
        })

        assert_error(subject[1], {
          code:  'unprocessable_entity',
          status: '422',
          title: 'Validation Error',
          detail: 'Cost is too high',
          source: { pointer: '/data/attributes/cost' },
          meta: {
            relationship: {
              attribute: :cost,
              message: 'is too high',
              code: :too_high,
              name: :favorite_toy,
              id: '555',
              type: 'toys'
            }
          }
        })
      end

      context 'that is 3 levels deep, with no error at second level' do
        before do
          pet.errors.clear
        end

        it 'still renders the error correctly' do
          assert_errors(subject, [{
            code:  'unprocessable_entity',
            status: '422',
            title: 'Validation Error',
            detail: 'Cost is too high',
            source: { pointer: '/data/attributes/cost' },
            meta: {
              relationship: {
                attribute: :cost,
                message: 'is too high',
                code: :too_high,
                name: :favorite_toy,
                id: '555',
                type: 'toys'
              }
            }
          }])
        end
      end

      context 'and the sideposted object has a temp id' do
        before do
          toy.errors.clear
          pet.id = nil
          pet.instance_variable_set(:@_jsonapi_temp_id, 't3mp-1d')
          relationship_params[:pets][0][:meta][:temp_id] = 't3mp-1d'
        end

        it 'is returned instead of id' do
          assert_errors(subject, [{
            code:  'unprocessable_entity',
            status: '422',
            title: 'Validation Error',
            detail: "Name can't be blank",
            source: { pointer: '/data/attributes/name' },
            meta: {
              relationship: {
                attribute: :name,
                message: "can't be blank",
                code: :blank,
                name: :pets,
                :'temp-id' => 't3mp-1d',
                type: 'pets'
              }
            }
          }])
        end
      end
    end
  end
end
