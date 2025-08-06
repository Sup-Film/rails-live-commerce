# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# สร้าง ThirdParty สำหรับ Slip Verification Service
ThirdParty.find_or_create_by!(name: 'verify_slip') do |tp|
  tp.slug = 'verify_slip'
  tp.enabled = true
  puts "Created ThirdParty record for slip verification service"
end

puts "Seeds completed successfully!"
