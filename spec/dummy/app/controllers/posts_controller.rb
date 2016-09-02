class PostsController < ApplicationController
  def index
    if params[:disable]
      JsonapiErrorable.disable!
    else
      JsonapiErrorable.enable!
    end

    if params[:basic]
      raise 'some error'
    else
      raise params[:error].constantize, 'some message'
    end

    render json: {}
  end
end
