require 'omniauth-facebook'

# กรณีใช้เป็น production ให้คอมเมนต์ 2 บรรทัดนี้
OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.silence_get_warning = true

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :facebook, ENV['FACEBOOK_APP_ID'], ENV['FACEBOOK_APP_SECRET'], {
    # URL ที่จะให้ Facebook ส่ง code กลับมา (ต้องตรงกับที่ตั้งใน Facebook Developer)
    callback_url: ENV['FACEBOOK_CALLBACK_URL'] || 'http://localhost:3000/auth/facebook/callback',
    # กำหนดให้ใช้ HTTPS สำหรับการเชื่อมต่อ
    scope: 'pages_manage_engagement,pages_manage_metadata',
    # ชนิดข้อมูลที่ต้องการ
    info_fields: 'name,first_name,last_name,picture',
    # ใช้ HTTPS สำหรับรูปภาพ
    secure_image_url: true
  }
end
