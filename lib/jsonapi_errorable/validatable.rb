module JsonapiErrorable
  module Validatable
    def render_errors_for(record)
      validation = Serializers::Validation.new \
        record, deserialized_params.relationships

      render \
        json: { errors: validation.errors },
        status: :unprocessable_entity
    end
  end
end
