class FacebookApiService
  BASE_URL = "https://graph.facebook.com/v23.0"

  def initialize(access_token)
    @access_token = access_token
  end

  def get_profile(fields = "id,name,email")
    get_resource("/me", { fields: fields })
  end

  def get_pages
    # Requires proper page permissions granted during OAuth
    get_resource("/me/accounts", { fields: "id,name,access_token" })
  end

  # Instagram-related methods
  def get_instagram_account(page_id)
    get_resource("/#{page_id}", { fields: "instagram_business_account{id,username}" })
  end

  def get_instagram_media(instagram_user_id, limit = 25)
    get_resource("/#{instagram_user_id}/media", { 
      fields: "id,media_type,media_url,permalink,caption,timestamp,comments_count,like_count",
      limit: limit 
    })
  end

  def get_instagram_live_media(instagram_user_id)
    get_resource("/#{instagram_user_id}/live_media", { 
      fields: "id,media_url,permalink,status,creation_time" 
    })
  end

  def get_instagram_comments(media_id, limit = 50)
    get_resource("/#{media_id}/comments", { 
      fields: "id,text,timestamp,username,like_count,replies",
      limit: limit 
    })
  end

  def get_instagram_live_comments(live_video_id, limit = 50)
    get_resource("/#{live_video_id}/live_comments", { 
      fields: "id,text,timestamp,from{id,username},created_time",
      limit: limit 
    })
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
