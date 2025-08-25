require 'rails_helper'

RSpec.describe "Api::V1::Orders", type: :request do
  describe "GET /submit_payment" do
    it "returns http success" do
      get "/api/v1/orders/submit_payment"
      expect(response).to have_http_status(:success)
    end
  end

end
