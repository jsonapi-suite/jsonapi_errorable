module JsonapiErrorable
  module Validatable
    def render_errors_for(record)
      render \
        json: record,
        status: :unprocessable_entity,
        serializer: Serializers::SerializableValidation,
        adapter: :attributes
    end
  end
end
