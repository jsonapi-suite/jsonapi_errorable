class SpecialPostsController < PostsController
  register_exception SpecialPostError, message: ->(e) { 'special post' }

  def index
    JsonapiErrorable.enable!
    raise SpecialPostError
  end
end
