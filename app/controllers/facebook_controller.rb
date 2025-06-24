class FacebookController < ApplicationController
  before_action :authenticate_user!
  
  def profile
    service = FacebookApiService.new(current_user.oauth_token)
    @profile = service.get_profile("id,name,email,birthday,gender,location")
    
    respond_to do |format|
      format.html
      format.json { render json: @profile }
    end
  end
  
  # def posts
  #   service = FacebookApiService.new(current_user.oauth_token)
  #   @posts = service.get_posts(params[:limit] || 5)
    
  #   respond_to do |format|
  #     format.html
  #     format.json { render json: @posts }
  #   end
  # end
  
  # def friends
  #   service = FacebookApiService.new(current_user.oauth_token)
  #   @friends = service.get_friends(params[:limit] || 10)
    
  #   respond_to do |format|
  #     format.html
  #     format.json { render json: @friends }
  #   end
  # end
  
  # def photos
  #   service = FacebookApiService.new(current_user.oauth_token)
  #   @photos = service.get_photos(params[:limit] || 10)
    
  #   respond_to do |format|
  #     format.html
  #     format.json { render json: @photos }
  #   end
  # end
  
  private
  
  def authenticate_user!
    redirect_to root_path, alert: "Please login to access Facebook data" unless user_signed_in?
  end
end
