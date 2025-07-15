require "test_helper"

class FacebookLiveCommentServiceTest < ActiveSupport::TestCase
  setup do
    # สร้างผู้ใช้ทดสอบ
    @user = users(:one) # ใช้ fixture หรือสร้างใหม่ตามต้องการ

    # สร้าง product ทดสอบ
    @product = products(:one) # ใช้ fixture หรือสร้างใหม่ตามต้องการ

    @live_id = "live_12345"
    @access_token = "test_access_token"
    @service = FacebookLiveCommentService.new(@live_id, @access_token, @user)
  end

  test "should detect CF order and create a new order" do
    comment_data = {
      id: "comment1",
      message: "สนใจ CF 7777 ครับ",
      created_time: Time.current.iso8601,
      from: { id: "facebook_user_1", name: "Facebook User One" }
    }

    # Mock Product.find_by เพื่อให้คืนค่า product ที่เราสร้างไว้ 
    # คาดหวังว่า Order.create! จะถูกเรียกด้วยข้อมูลที่ถูกต้อง
    # และยืนยันว่าจำนวน Order เพิ่มขึ้น 1
    assert_difference("Order.count", 1) do
      order = @service.send(:detect_cf_order, comment_data) # ใช้ send เพื่อเข้าถึง method ที่เป็น private
      assert_not_nil order
      assert_equal "CF7777", order.order_number
      assert_equal @product, order.product
      assert_equal @user, order.user
      assert_equal comment_data[:from][:id], order.facebook_user_id
    end
  end
end
