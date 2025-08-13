class Rack::Attack
  # จำกัดการ Login 5 ครั้งต่อ 5 นาที ต่อ IP
  throttle("logins/email", limit: 5, period: 5.minute) do |req|
    if req.path == "/login" && req.post?
      # Normalize a case-insensitive email address
      req.params["session"]["email"].to_s.downcase.strip if req.params["session"].present?
    end
  end

  # Custom response: กำหนดข้อความที่จะแสดงเมื่อถูกบล็อค
  self.throttled_response = ->(env) {
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
