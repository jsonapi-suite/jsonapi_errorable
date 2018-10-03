module JsonapiErrorable
  module Validatable
    # @param relationships: nil [ Hash or FalseClass ] list of relationships whose errors should be serialized
    #   Defaults to the deserialized data.relationships of Json:api Payload
    # @param record [ ActiveModel ] Object that implements ActiveModel
    def render_errors_for(record, relationships: {})
      relationships || deserialized_params.relationships

      validation = Serializers::Validation.new(record, relationships)

      render \
        json: { errors: validation.errors },
        status: :unprocessable_entity
    end
  end
end
