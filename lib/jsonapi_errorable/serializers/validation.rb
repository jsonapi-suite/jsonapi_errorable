module JsonapiErrorable
  module Serializers
    class Validation
      attr_reader :object

      def initialize(object, relationship_params = {}, relationship_message = {})
        @object = object
        @relationship_params = relationship_params || {}
        @relationship_message = relationship_message
      end

      def errors
        return [] unless object.respond_to?(:errors)

        all_errors = object.errors.details.map do |attribute, error_symbols|
          error_symbols.map do |error_hash|
            error_symbol = error_hash[:error]
            message = object.errors.generate_message(attribute, error_symbol)

            meta = { attribute: attribute, message: message, code: error_symbol }
            meta = { relationship: meta } if @relationship_message.present?

            detail = object.errors.full_message(attribute, message)
            detail = message if attribute.to_s.downcase == 'base'

            {
              code:   'unprocessable_entity',
              status: '422',
              title: 'Validation Error',
              detail: detail,
              source: { pointer: pointer_for(object, attribute) },
              meta:   meta
            }
          end
        end.flatten
        all_errors << relationship_errors(@relationship_params)
        all_errors.flatten!
        all_errors.compact!
        all_errors
      end

      def relationship?(name)
        return false unless activemodel?

        relation_names = object.class.reflect_on_all_associations.map(&:name)
        relation_names.include?(name)
      end

      def attribute?(name)
        object.respond_to?(name)
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

      def activemodel?
        object.class.respond_to?(:reflect_on_all_associations)
      end

      def relationship_errors(relationship_params)
        errors = []
        relationship_params.each_pair do |name, payload|
          related = Array(@object.send(name))
          related.each do |r|
            if payload.is_a?(Array)
              related_payload = payload.find { |p| p[:meta][:temp_id] === r.instance_variable_get(:@_jsonapi_temp_id) || p[:meta][:id] == r.id }
            else
              related_payload = payload
            end
            relationship_message = {
              name: name,
              id: r.id,
              :'temp-id' => r.instance_variable_get(:@_jsonapi_temp_id)
            }

            errors << Validation.new(r, related_payload[:relationships], relationship_message).errors
          end
        end
        errors
      end
    end
  end
end
