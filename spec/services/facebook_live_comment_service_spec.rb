require "rails_helper"

RSpec.describe FacebookLiveCommentService, type: :service do
  let(:user) { User.create!(name: "Test User", email: "u@example.com", password: "secret123") }
  let(:token) { "PAGE_ACCESS_TOKEN" }
  let(:live_id) { "live_123" }

  let!(:product) { Product.create!(user: user, productName: "P1", productDetail: "D", productPrice: 100, productCode: 7777) }

  subject(:service) { described_class.new(live_id, token, user) }

  before do
    allow(user).to receive(:has_sufficient_credit?).and_return(true)
  end

  def fake_response(json_hash)
    instance_double(HTTParty::Response,
      success?: true,
      headers: { "content-type" => "application/json; charset=UTF-8" },
      parsed_response: json_hash,
      body: json_hash.to_json,
      code: 200
    )
  end

  it "fetches comments, creates orders, and returns latest_comment_unix" do
    t1 = 2.minutes.ago
    t2 = 1.minute.ago
    data = {
      "data" => [
        { "id" => "c1", "message" => "CF 7777", "created_time" => t1.iso8601, "from" => { "id" => "fb1", "name" => "A" } },
        { "id" => "c2", "message" => "not related", "created_time" => t2.iso8601, "from" => { "id" => "fb2", "name" => "B" } }
      ]
    }
    allow(HTTParty).to receive(:get).and_return(fake_response(data))

    result = service.fetch_comments(since_unix: nil, filter: "toplevel", live_filter: "stream")

    expect(result).to be_a(Hash)
    expect(result[:comments].size).to eq(2)
    expect(result[:orders].compact.size).to eq(1)
    expect(result[:latest_comment_unix]).to eq([t1.to_i, t2.to_i].max)

    order = result[:orders].compact.first
    expect(order).to be_a(Order)
    expect(order.order_number).to eq("7777")
    expect(order.facebook_comment_id).to eq("c1")
  end
end

