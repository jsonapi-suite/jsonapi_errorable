module GraphitiErrors
  module Serializers
    class Validation
      attr_reader :object

      def initialize(object, relationship_payloads = {}, relationship_meta = {})
        @object = object
        @relationship_payloads = relationship_payloads
        @relationship_meta = relationship_meta
      end

      def attribute_errors
        [].tap do |errors|
          each_error do |attribute, message, code|
            error = {
              code:   'unprocessable_entity',
              status: '422',
              title: 'Validation Error',
              detail: detail_for(attribute, message),
              source: { pointer: pointer_for(object, attribute) },
              meta:   meta_for(attribute, message, code, @relationship_meta)
            }

            errors << error
          end
        end
      end

      def errors
        return [] unless object.respond_to?(:errors)

        all_errors = attribute_errors
        all_errors |= relationship_errors(object, @relationship_payloads)
        all_errors
      end

      private

      def each_error
        object.errors.messages.each_pair do |attribute, messages|
          details = if Rails::VERSION::MAJOR >= 5
                      object.errors.details.find { |k,v| k == attribute }[1]
                    end

          messages.each_with_index do |message, index|
            code = details[index][:error] if details
            yield attribute, message, code
          end
        end
      end

      def relationship?(name)
        relationship_names = []
        if activerecord?
          relationship_names = object.class
            .reflect_on_all_associations.map(&:name)
        elsif object.respond_to?(:relationship_names)
          relationship_names = object.relationship_names
        end

        relationship_names.include?(name)
      end

      def attribute?(name)
        object.respond_to?(name)
      end

      def meta_for(attribute, message, code, relationship_meta)
        meta = {
          attribute: attribute,
          message: message
        }
        meta.merge!(code: code) if Rails::VERSION::MAJOR >= 5

        unless relationship_meta.empty?
          meta = {
            relationship: meta.merge(relationship_meta)
          }
        end

        meta
      end

      def detail_for(attribute, message)
        detail = object.errors.full_message(attribute, message)
        detail = message if attribute.to_s.downcase == 'base'
        detail
      end

      # @richmolj: Keeping this to support ember-data, but I hate the concept.
      def pointer_for(object, name)
        if relationship?(name)
          "/data/relationships/#{name}"
        elsif attribute?(name)
          "/data/attributes/#{name}"
        elsif name == :base
          nil
        else
          # Probably a nested relation, like post.comments
          "/data/relationships/#{name}"
        end
      end

      def activerecord?
        object.class.respond_to?(:reflect_on_all_associations)
      end

      def traverse_relationships(model, relationship_params)
        return unless relationship_params

        relationship_params.each_pair do |name, payload|
          relationship_objects = Array(model.send(name))

          relationship_objects.each do |relationship_object|
            related_payload = payload
            if payload.is_a?(Array)
              related_payload = payload.find do |p|
                temp_id = relationship_object
                  .instance_variable_get(:@_jsonapi_temp_id)
                p[:meta][:temp_id] === temp_id ||
                  p[:meta][:id] == relationship_object.id.to_s
              end
            end

            yield name, relationship_object, related_payload
            relationship_errors(relationship_object, related_payload[:relationships])
          end
        end
      end

      def relationship_errors(model, relationship_payloads)
        errors = []
        traverse_relationships(model, relationship_payloads) do |name, model, payload|
          meta = {}.tap do |hash|
            hash[:name] = name
            hash[:type] = payload[:meta][:jsonapi_type]
            if temp_id = model.instance_variable_get(:@_jsonapi_temp_id)
              hash[:'temp-id'] = temp_id
            else
              hash[:id] = model.id
            end
          end

          serializer = self.class.new(model, payload[:relationships], meta)
          errors |= serializer.errors
        end
        errors
      end
    end
  end
end
