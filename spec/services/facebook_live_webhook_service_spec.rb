require "rails_helper"

RSpec.describe FacebookLiveWebhookService, type: :service do
  include ActiveJob::TestHelper

  let(:user) { User.create!(name: "WH User", email: "wh@example.com", password: "secret123") }
  let(:token) { "PAGE_ACCESS_TOKEN" }
  let(:live_id) { "live_wh_1" }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  it "does an initial fetch and enqueues polling job with since from latest comment" do
    payload = {
      "entry" => [
        {
          "changes" => [
            { "field" => "live_videos", "value" => { "id" => live_id, "status" => "live" } }
          ]
        }
      ]
    }

    svc_double = instance_double(FacebookLiveCommentService)
    allow(FacebookLiveCommentService).to receive(:new).and_return(svc_double)
    allow(svc_double).to receive(:fetch_comments).and_return({ orders: [], comments: [], latest_comment_unix: 1_700_000_000 })

    expect {
      described_class.new(payload, token, user).process
    }.to have_enqueued_job(PollFacebookLiveCommentsJob).with(
      hash_including(live_id: live_id, access_token: token, user_id: user.id, since_unix: 1_700_000_000)
    )

    expect(svc_double).to have_received(:fetch_comments).with(hash_including(filter: "toplevel", live_filter: "stream"))
  end
end
