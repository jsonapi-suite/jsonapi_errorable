### jsonapi_errorable

Global error handling compatible with [the jsonapi.org spec](http://jsonapi.org/format/#errors)

### Installation

Add to your ApplicationController:

```ruby
class ApplicationController < ActionController::Base
  include JsonapiErrorable

  rescue_from Exception do |e|
    handle_exception(e)
  end
end
```

### Global Error Handling

Once installed, all errors will return a valid error response. `raise "foo"` would render:

```ruby
{
  errors: [
    code: 'internal_server_error',
    status: '500',
    title: 'Error',
    detail: "We've notified our engineers and hope to address this issue shortly.",
    meta: {}
  ]
}
```

### Validation Error Handling

Given a record fails [validations](http://api.rubyonrails.org/classes/ActiveModel/Validations.html), you probably want to render a custom error message specific to the validation failure. Use `render_errors_for`:

```ruby
def create
  post = Post.new(post_params)

  if post.save
    render json: post
  else
    render_errors_for(post)
  end
end
```

Assuming the Post's `title` was missing, this would render:

```ruby
{
  errors: [
    {
      code: 'unprocessable_entity',
      status: '422',
      title: 'Validation Error',
      detail: "Title can't be blank",
      source: { pointer: '/data/attributes/title' },
      meta: {
        attribute: 'title',
        message: "can't be blank"
        code: 'blank'
      }
    }
  ]
}
```

This will work for any PORO including [ActiveModel::Validations](http://api.rubyonrails.org/classes/ActiveModel/Validations.html)

*Note: 'meta/code' is only available in ActiveModel >= 5*

#### Nested Validation Error Handing

We use the `meta` section of the error payload handle nested relationships. Let's say we were [sideposting](https://jsonapi-suite.github.io/jsonapi_suite/concepts#sideposting) a comment that had a validation error on `body`.  You'd get back:

```ruby
{
  errors: [
    {
      code: 'unprocessable_entity',
      status: '422',
      title: 'Validation Error',
      detail: "Body can't be blank",
      source: { pointer: '/data/attributes/body' },
      meta: {
        relationship: {
          attribute: 'body',
          message: "can't be blank"
          code: 'blank'
          id: '123',
          type: 'comments'
        }
      }
    }
  ]
}
```

### Customizing Error Responses

You can customize an error's response by using `register_exception` in your controller. Let's say we want `ActiveRecord::RecordNotFound` to have status code `404` instead of `500`:

```ruby
class ApplicationController < ActionController::Base
  # ...installation code...
  register_exception ActiveRecord::RecordNotFound, status: 404
end
```

Would now render http status code `404`, with the error JSON containing `status: '404'` and `code: 'not_found'`.

Available options are:

* `status`: An http status code
* `title`: Custom title
* `log`: Pass `false` to avoid logging the error
* `message`: Pass `true` to render the error's message directly. Alternatively, this can accept a proc, e.g. `register_exception FooError, message: ->(e) { e.message.upcase }`

### Showing Raw Errors

You may want to render the actual error message and backtrace - for instance, if the user is an admin, or if `Rails.env.staging?`. In this case:

```ruby
handle_exception(e, show_raw_error: current_user.admin?)
```

This will add `__raw_error__` to the `meta` section of the payload, containing the message and backtrace.

### Custom Exception Handler

The final option `register_exception` accepts is `handler`. Here you can inject your own error handling class that customizes [JsonapiErrorable::ExceptionHandler](https://bbgithub.dev.bloomberg.com/InfrastructureExperience/jsonapi_errorable/blob/master/lib/jsonapi_errorable/exception_handler.rb). For example:

```ruby
class MyCustomHandler < JsonapiErrorable::ExceptionHandler
  def status_code(error)
    # ...customize...
  end

  def error_code(error)
    # ...customize...
  end

  def title
    # ...customize...
  end

  def detail(error)
    # ...customize...
  end

  def meta(error)
    # ...customize...
  end

  def log(error)
    # ...customize...
  end
end

register_exception FooError, handler: MyCustomHandler
```

If you would like to use the same custom handler for all errors, override `default_exception_handler`:

```ruby
# app/controllers/application_controller.rb
def self.default_exception_handler
  MyCustomHandler
end
```

### Exception Handling in Subclasses

All controllers will inherit any registered exceptions from their parent. They can also add their own. In this example, `FooError` will only throw a custom status code when thrown from `FooController`:

```ruby
class FooController < ApplicationController
  register_exception FooError, status: 422
end
```

### Custom Logger

You can assign any logger using `JsonapiErrorable.logger = your_logger`

### Within Tests

You may want your tests to actually raise errors instead of returning error JSON. In this case use `disabled!` and `enabled`:

```ruby
before :each do
  JsonapiErrorable.disable!
end

it 'renders correct error response' do
  JsonapiErrorable.enable! # enabled just for this test
end
```
