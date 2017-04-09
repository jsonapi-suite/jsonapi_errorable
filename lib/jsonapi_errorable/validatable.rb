module JsonapiErrorable
  module Validatable
    def render_errors_for(record)
      validation = Serializers::Validation.new(record)

      render \
        json: validation.errors,
        status: :unprocessable_entity
    end
  end
end
