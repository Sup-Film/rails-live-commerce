class ProcessHeldOrdersJob < ApplicationJob
  queue_as :default

  # รับ user_id เข้ามาเป็น argument
  def perform(user_id)
    # หา user ที่ต้องการจะประมวลผล
    user = User.find(user_id)
    return unless user # คืนค่า nil ถ้าไม่พบ user

    # ค้นหาออเดอร์ทั้งหมดของผู้ขายที่ถูก on_hold_insufficient_credit ไว้
    held_orders = user.orders.where(status: :on_hold_insufficient_credit)
    return if held_orders.empty? # ถ้าไม่มีออเดอร์ที่ถูกพักไว้ ก็ไม่ต้องทำอะไร
    puts "Found #{held_orders.count} held orders for User ##{user.id}. Processing..."

    held_orders.each do |order|
      # ประมวลผลออเดอร์ที่ถูกพักไว้
      process_held_order(order, user)
    end
  end

  private

  def process_held_order(order, user)
    # TODO: ต้องแทนที่ด้วย SkyboxService เพื่อเช็คราคาขนส่ง
    shipping_cost_cents = 5000

    # ตรวจสอบเครดิตอีกครั้งด้วยยอดเงินล่าสุด
    if user.has_sufficient_credit?(shipping_cost_cents)
      puts "Credit is now sufficient for Order ##{order.id}. Updating status..."

      # ถ้าเครดิตพอให้เปลี่ยนสถานะเป็นรอชำระเงิน
      order.update(status: :awaiting_payment)

    else
      # ถ้าเครดิตไม่พอก็ไม่ต้องทำอะไร
      puts "Credit is insufficient for Order ##{order.id}. Keeping on hold."
    end
  rescue => e
    # ดักจับ Error ที่อาจเกิดขึ้นระหว่างประมวลผลแต่ละออเดอร์
    # เพื่อไม่ให้ Job ทั้งหมดล่มเพราะออเดอร์เดียว
    puts "Error processing Order ##{order.id}: #{e.message}"
  end
end
