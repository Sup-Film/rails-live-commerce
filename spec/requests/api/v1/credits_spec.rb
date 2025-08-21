require 'rails_helper'

RSpec.describe "Api::V1::Credits", type: :request do
  describe "GET /top_up" do
    it "returns http success" do
      get "/api/v1/credits/top_up"
      expect(response).to have_http_status(:success)
    end
  end

end
