require "rails_helper"

RSpec.describe PollFacebookLiveCommentsJob, type: :job do
  include ActiveJob::TestHelper

  let(:user) { User.create!(name: "Job User", email: "job@example.com", password: "secret123") }
  let(:token) { "PAGE_ACCESS_TOKEN" }
  let(:live_id) { "live_abc" }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  it "calls service and re-enqueues itself with updated since" do
    # ให้ service คืนค่า latest_comment_unix = 1234567890
    svc_double = instance_double(FacebookLiveCommentService)
    allow(FacebookLiveCommentService).to receive(:new).and_return(svc_double)
    allow(svc_double).to receive(:fetch_comments).and_return({ orders: [], comments: [], latest_comment_unix: 1_234_567_890 })

    expect {
      described_class.perform_now(
        live_id: live_id,
        access_token: token,
        user_id: user.id,
        since_unix: nil,
        interval_seconds: 5,
        limit: 50,
        filter: "toplevel",
        live_filter: "stream",
      )
    }.to have_enqueued_job(described_class).with(
      hash_including(live_id: live_id, access_token: token, user_id: user.id, since_unix: 1_234_567_890)
    )

    expect(svc_double).to have_received(:fetch_comments).with(hash_including(:since_unix, :filter, :live_filter))
  end
end
