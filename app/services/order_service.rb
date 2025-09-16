class OrderService
  # Class methods สำหรับการดำเนินการกับ order
  class << self
    # สำหรับ update order จาก checkout form
    def update_order(order, params)
      puts "Updating order with params: #{params.inspect}"
      puts "Current order status: #{order.inspect}"
      begin
        quantity = params[:quantity].to_i if params[:quantity].present?
        total_amount = quantity * order.unit_price if quantity

        update_params = {
          customer_address: params[:customer_address],
          customer_name: params[:customer_name],
          customer_phone: params[:customer_phone],
          customer_email: params[:customer_email],
        }

        # เพิ่ม quantity และ total_amount ถ้ามีการเปลี่ยนแปลง
        if quantity && quantity != order.quantity
          update_params[:quantity] = quantity
          update_params[:total_amount] = total_amount
        end

        order.update!(update_params)
        Rails.logger.info "Order #{order.order_number} updated successfully"
        true  # ← สำคัญ! ต้อง return true
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "Order update failed: #{e.message}"
        false
      rescue StandardError => e
        Rails.logger.error "Order update error: #{e.message}"
        false
      end
    end

    # ยกเลิก order
    def cancel_order(order)
      return false unless order.present? && order.cancellable?

      order.update!(
        status: "cancelled",
      )
    end

    # เปลี่ยนสถานะเป็น completed
    def complete_order(order, payment_info = {})
      return false unless order.present? && order.pending?

      order.update(
        status: "completed",
        completed_at: Time.current,
        payment_info: payment_info,
      )
    end
  end
end
