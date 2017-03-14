module JsonapiErrorable
  module Serializers
    class SerializableValidation < JSONAPI::Serializable::Resource
      type :validation_errors

      attribute :errors do
        @object.errors.to_hash.map do |attribute, messages|
          messages.map do |message|
            {
              code:   'unprocessable_entity',
              status: '422',
              title: 'Validation Error',
              detail: "#{attribute.capitalize} #{message}",
              source: { pointer: pointer_for(@object, attribute) },
              meta:   { attribute: attribute, message: message }
            }
          end
        end.flatten
      end

      def relationship?(name)
        return false unless activerecord?

        relation_names = @object.class.reflect_on_all_associations.map(&:name)
        relation_names.include?(name)
      end

      def attribute?(name)
        @object.respond_to?(name)
      end

      private

      def pointer_for(object, name)
        if relationship?(name)
          "/data/relationships/#{name}"
        elsif attribute?(name)
          "/data/attributes/#{name}"
        else
          # Probably a nested relation, like post.comments
          "/data/relationships/#{name}"
        end
      end

      def activerecord?
        object.is_a?(ActiveRecord::Base)
      end
    end
  end
end
