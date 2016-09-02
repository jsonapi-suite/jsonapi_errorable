module JsonapiErrorable
  module Validatable
    def render_errors_for(record)
      render \
        json: record,
        status: :unprocessable_entity,
        serializer: Serializers::ValidationSerializer,
        adapter: :attributes
    end
  end
end
