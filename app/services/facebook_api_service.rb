class FacebookApiService
  BASE_URL = "https://graph.facebook.com/v23.0"

  def initialize(access_token)
    @access_token = access_token
  end

  def get_profile(fields = "id,name,email")
    get_resource("/me", { fields: fields })
  end

  # def get_posts(limit = 5)
  #   get_resource("/me/feed", { limit: limit })
  # end

  # def get_friends(limit = 10)
  #   get_resource("/me/friends", { limit: limit })
  # end

  # def get_photos(limit = 10)
  #   get_resource("/me/photos", { limit: limit })
  # end

  private

  def get_resource(path, params = {})
    params[:access_token] = @access_token
    
    begin
      response = HTTParty.get("#{BASE_URL}#{path}", query: params)

      if response.success?
        JSON.parse(response.body)
      else
        { error: response.body, code: response.code }
      end
    rescue StandardError => e
      { error: e.message, code: 500 }
    end
  end
end