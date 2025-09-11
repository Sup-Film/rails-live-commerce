require "rails_helper"

RSpec.describe PollFacebookLiveCommentsJob, type: :job do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { User.create!(name: "Job User", email: "job@example.com", password: "secret123") }
  let(:token) { "PAGE_ACCESS_TOKEN" }
  let(:live_id) { "live_adaptive_poll" }
  let(:svc_double) { instance_double(FacebookLiveCommentService) }

  before do
    ActiveJob::Base.queue_adapter = :test
    Rails.cache.clear
    clear_enqueued_jobs
  end

  context "when the live video is active" do
    it "re-enqueues itself with a FAST interval if new comments are found" do
      allow(FacebookLiveCommentService).to receive(:new).and_return(svc_double)
      allow(svc_double).to receive(:fetch_comments).and_return({
        orders: [],
        comments: [{ id: "c1", message: "New Comment" }],
        latest_comment_unix: 1700000000,
      })

      freeze_time do
        # รัน job และเช็คการ enqueue
        described_class.perform_now(live_id: live_id, access_token: token, user_id: user.id)

        # ตรวจสอบว่ามี Job ถูก enqueue และจะรันในอีก 5 วินาทีข้างหน้า
        expect(described_class).to have_been_enqueued.at(5.seconds.from_now).with(
          live_id: live_id,
          access_token: token,
          user_id: user.id,
          since_unix: 1700000000,
          limit: 50,
          order: "reverse_chronological",
          filter: "toplevel",
          live_filter: nil,
        )
      end

      expect(svc_double).to have_received(:fetch_comments)
    end

    it "re-enqueues itself with a SLOW interval if no new comments are found" do
      allow(FacebookLiveCommentService).to receive(:new).and_return(svc_double)
      allow(svc_double).to receive(:fetch_comments).and_return({
        orders: [],
        comments: [],
        latest_comment_unix: 1700000000,
      })

      freeze_time do
        # รัน job และเช็คการ enqueue
        described_class.perform_now(live_id: live_id, access_token: token, user_id: user.id)

        # ตรวจสอบว่ามี Job ถูก enqueue และจะรันในอีก 15 วินาทีข้างหน้า
        expect(described_class).to have_been_enqueued.at(15.seconds.from_now).with(
          live_id: live_id,
          access_token: token,
          user_id: user.id,
          since_unix: 1700000000,
          limit: 50,
          order: "reverse_chronological",
          filter: "toplevel",
          live_filter: nil,
        )
      end

      expect(svc_double).to have_received(:fetch_comments)
    end
  end

  context "when the live video has ended" do
    it "does NOT call the service and does NOT re-enqueue itself" do
      cache_key = "polling_job_live_#{live_id}"
      Rails.cache.write(cache_key, "stop")

      # ใน test environment ใช้ :null_store ทำให้ write ไม่ถูกเก็บจริง
      # จึง stub ให้ read(cache_key) คืนค่า "stop" เพื่อจำลอง live จบ
      allow(Rails.cache).to receive(:read).and_call_original
      allow(Rails.cache).to receive(:read).with(cache_key).and_return("stop")

      # Mock ApplicationLoggerService เพื่อป้องกัน error
      allow(ApplicationLoggerService).to receive(:info)

      # เนื่องจาก Job ควรจะ return ทันที จึงไม่ควรมีการเรียก service
      expect(svc_double).not_to receive(:fetch_comments)
      # และไม่ควรมีการสร้าง FacebookLiveCommentService ใหม่ด้วย
      expect(FacebookLiveCommentService).not_to receive(:new)

      # รัน job โดยตรง
      described_class.perform_now(live_id: live_id, access_token: token, user_id: user.id)

      # ตรวจสอบว่า "ไม่มี" job ถูก enqueue ต่อ
      expect(enqueued_jobs).to be_empty

      # ตรวจสอบว่า log ถูกเรียก
      expect(ApplicationLoggerService).to have_received(:info).with(
        "polling.stopped",
        { live_id: live_id, reason: "Live video ended." }
      )
    end
  end

  context "error handling" do
    it "re-enqueues with FAST_INTERVAL when an error occurs" do
      allow(FacebookLiveCommentService).to receive(:new).and_return(svc_double)
      allow(svc_double).to receive(:fetch_comments).and_raise(StandardError.new("API Error"))
      allow(ApplicationLoggerService).to receive(:error)

      freeze_time do
        # รัน job และเช็คการ enqueue เมื่อเกิด error
        described_class.perform_now(live_id: live_id, access_token: token, user_id: user.id)

        # ตรวจสอบว่ามี Job ถูก enqueue ใหม่หลังจาก error ด้วย FAST_INTERVAL
        expect(described_class).to have_been_enqueued.at(5.seconds.from_now).with(
          live_id: live_id,
          access_token: token,
          user_id: user.id,
          since_unix: nil,
          limit: 50,
          order: "reverse_chronological",
          filter: "toplevel",
          live_filter: nil,
        )
      end

      expect(ApplicationLoggerService).to have_received(:error)
    end
  end

  context "adaptive polling behavior" do
    it "uses latest_comment_unix for the next poll when comments are found" do
      allow(FacebookLiveCommentService).to receive(:new).and_return(svc_double)
      allow(svc_double).to receive(:fetch_comments).and_return({
        orders: [],
        comments: [{ id: "c1", message: "New Comment" }],
        latest_comment_unix: 1700000100,
      })

      freeze_time do
        described_class.perform_now(
          live_id: live_id,
          access_token: token,
          user_id: user.id,
          since_unix: 1700000000,
        )

        # ตรวจสอบว่า since_unix ถูกอัปเดตเป็น latest_comment_unix
        expect(described_class).to have_been_enqueued.with(
          hash_including(since_unix: 1700000100)
        )
      end
    end

    it "keeps the same since_unix when no comments are found" do
      allow(FacebookLiveCommentService).to receive(:new).and_return(svc_double)
      allow(svc_double).to receive(:fetch_comments).and_return({
        orders: [],
        comments: [],
        latest_comment_unix: nil,
      })

      freeze_time do
        described_class.perform_now(
          live_id: live_id,
          access_token: token,
          user_id: user.id,
          since_unix: 1700000000,
        )

        # ตรวจสอบว่า since_unix ยังคงเดิม
        expect(described_class).to have_been_enqueued.with(
          hash_including(since_unix: 1700000000)
        )
      end
    end

    it "logs polling schedule information" do
      allow(FacebookLiveCommentService).to receive(:new).and_return(svc_double)
      allow(ApplicationLoggerService).to receive(:info)
      allow(svc_double).to receive(:fetch_comments).and_return({
        orders: [],
        comments: [{ id: "c1" }],
        latest_comment_unix: 1700000000,
      })

      described_class.perform_now(live_id: live_id, access_token: token, user_id: user.id)

      expect(ApplicationLoggerService).to have_received(:info).with(
        "polling.schedule_next",
        hash_including(
          live_id: live_id,
          comments_found: true,
          next_poll_in_seconds: 5.seconds,
        )
      )
    end

    it "logs polling schedule information with SLOW interval when no comments" do
      allow(FacebookLiveCommentService).to receive(:new).and_return(svc_double)
      allow(ApplicationLoggerService).to receive(:info)
      allow(svc_double).to receive(:fetch_comments).and_return({
        orders: [],
        comments: [],
        latest_comment_unix: 1700000000,
      })

      described_class.perform_now(live_id: live_id, access_token: token, user_id: user.id)

      expect(ApplicationLoggerService).to have_received(:info).with(
        "polling.schedule_next",
        hash_including(
          live_id: live_id,
          comments_found: false,
          next_poll_in_seconds: 15.seconds,
        )
      )
    end
  end

  context "constants validation" do
    it "has correct FAST_INTERVAL value" do
      expect(described_class::FAST_INTERVAL).to eq(5.seconds)
    end

    it "has correct SLOW_INTERVAL value" do
      expect(described_class::SLOW_INTERVAL).to eq(15.seconds)
    end
  end
end
