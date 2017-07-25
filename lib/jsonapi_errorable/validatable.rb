module JsonapiErrorable
  module Validatable
    # @param relationships: nil [Hash] list of relationships to be serialized as errors
    # @param record [ ActiveModel ] Object that implements ActiveModel
    def render_errors_for(record, relationships: nil)
      validation = Serializers::Validation.new(
        record,
        relationships || deserialized_params.relationships
      )
      

      render \
        json: { errors: validation.errors },
        status: :unprocessable_entity
    end
  end
end
