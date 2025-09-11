class Rack::Attack
  # จำกัดการ Login ต่อ IP: ลดการยิงเดารหัส/enum อีเมล
  throttle("logins/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/login" && req.post?
  end

  # จำกัดการ Login 5 ครั้งต่อ 5 นาที ต่อ IP
  throttle("logins/email", limit: 5, period: 5.minute) do |req|
    if req.path == "/login" && req.post?
      # Normalize a case-insensitive email address
      req.params["session"]["email"].to_s.downcase.strip if req.params["session"].present?
    end
  end

  # จำกัดการขอ Password Reset ต่อ IP: ป้องกัน spam email
  throttle("password_resets/ip", limit: 3, period: 15.minutes) do |req|
    req.ip if req.path == "/password_resets" && req.post?
  end

  # จำกัดการขอ Password Reset ต่อ email: ป้องกัน spam
  throttle("password_resets/email", limit: 5, period: 5.minutes) do |req|
    if req.path == "/password_resets" && req.post?
      req.params["email"].to_s.downcase.strip if req.params["email"].present?
    end
  end

  # Custom response: กำหนดข้อความที่จะแสดงเมื่อถูกบล็อค
  self.throttled_responder = ->(env) {
    # บังคับ redirect ทุกกรณี (เหมาะกับเว็บที่ไม่มี API)
    [
      302,
      {
        "Location" => "/login",
        "Content-Type" => "text/html",
        "Set-Cookie" => "flash_alert=too_many_attempts; path=/"
      },
      ["Redirecting..."]
    ]
  }

  # Log เมื่อมีการ block หรือ throttle
  ActiveSupport::Notifications.subscribe("rack.attack") do |name, start, finish, request_id, req_or_env|
    req = req_or_env.is_a?(Rack::Request) ? req_or_env : Rack::Request.new(req_or_env)
    Rails.logger.info "Rack::Attack: #{req.path} was throttled for IP: #{req.ip}"
  end
end
