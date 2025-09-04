# == Schema Information
#
# Table name: instagram_media
#
#  id                 :bigint           not null, primary key
#  caption            :text
#  media_type         :string
#  media_url          :string
#  permalink          :string
#  timestamp          :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  instagram_media_id :string
#  user_id            :bigint           not null
#
# Indexes
#
#  index_instagram_media_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require 'rails_helper'

RSpec.describe InstagramMedium, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
