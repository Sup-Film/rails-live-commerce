# == Schema Information
#
# Table name: pages
#
#  id               :bigint           not null, primary key
#  access_token     :text             not null
#  name             :string
#  token_expires_at :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  page_id          :string           not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_pages_on_page_id  (page_id) UNIQUE
#  index_pages_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Page < ApplicationRecord
  belongs_to :user

  validates :page_id, presence: true, uniqueness: true
  validates :access_token, presence: true
end

