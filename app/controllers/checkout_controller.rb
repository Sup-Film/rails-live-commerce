class CheckoutController < ApplicationController
  before_action :find_order, only: [:show, :update, :confirmation, :complete, :cancel]
  before_action :check_expiry, only: [:show, :update]

  def index
    # หน้ารายการคำสั่งซื้อทั้งหมด
    @orders = Order.where(status: "pending").order(created_at: :desc)
    @user = current_user
  end

  def show
    # แสดงหน้าฟอร์มกรอกข้อมูล
    # ตรวจสอบสถานะของ order
    if @order.status != "pending"
      # ถ้าไม่ใช่ pending แสดงว่าดำเนินการแล้ว ให้ไปหน้า confirmation
      redirect_to checkout_confirmation_path(@order.checkout_token),
                  notice: "คำสั่งซื้อนี้อยู่ในสถานะ: #{@order.status}"
      return
    end
  end

  def update
    @order.assign_attributes(order_params)

    # คำนวณราคาขนส่งจากการเรียกใช้ 3rd party skybox
    # TODO: ต้องแทนที่ด้วย SkyboxService เพื่อเช็คราคาขนส่ง
    shipping_cost_cents = 5000 # สมมุติค่าส่ง

    seller = @order.user
    if seller.has_sufficient_credit?(shipping_cost_cents)
      @order.status = :awaiting_payment
      if @order.save
        redirect_to checkout_confirmation_path(@order.checkout_token),
                    notice: "บันทึกข้อมูลเรียบร้อยแล้ว"
      else
        flash.now[:alert] = "ไม่สามารถบันทึกข้อมูลได้: #{@order.errors.full_messages.join(", ")}"
        render :show
      end
    else
      # ถ้าเครดิตไม่พอ
      @order.status = :on_hold_insufficient_credit
      @order.save(validate: false) # ต้องข้าม validation บางอย่างถ้ามี

      # TODO: เปิดเมลแจ้งเตือนไปยังผู้ขาย
      # แจ้งเตือนไปยังผู้ขาย
      SellerMailer.insufficient_credit_notification(
        user: @user,
        order_details: {
          customer_name: @order.customer_name,
          product_name: @order.product&.productName || @order.product&.name,
          product_code: @order.product&.productCode || @order.product&.code,
        },
        required_credit: shipping_cost_cents,
      ).deliver_later

      # 5. แสดงหน้าพักออเดอร์ให้ผู้ซื้อเห็น
      redirect_to checkout_on_hold_path(@order.checkout_token)
    end
  end

  def on_hold
    # View ที่จะบอกว่า "ออเดอร์ถูกพักไว้ชั่วคราว"
  end

  def confirmation
    unless @order.awaiting_payment? || @order.paid?
      return redirect_to appropriate_checkout_path, alert: "สถานะออเดอร์มีการเปลี่ยนแปลง"
    end
  end

  def complete
    # ทำให้คำสั่งซื้อเสร็จสิ้น
    if OrderService.complete_order(@order)
      redirect_with_success("คำสั่งซื้อเสร็จสิ้นเรียบร้อยแล้ว")
    else
      redirect_with_error("ไม่สามารถทำให้คำสั่งซื้อเสร็จสิ้นได้")
    end
  end

  def cancel
    # ยกเลิกคำสั่งซื้อ
    if OrderService.cancel_order(@order)
      redirect_with_success("ยกเลิกคำสั่งซื้อเรียบร้อยแล้ว"); return
    else
      redirect_with_error("ไม่สามารถยกเลิกคำสั่งซื้อได้"); return
    end
  end

  private

  def find_order
    # ดึงค่า token จาก params[:token] หรือ params[:id]
    @order = Order.find_by!(checkout_token: params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "ไม่พบคำสั่งซื้อ หรือลิงค์ไม่ถูกต้อง"
  end

  def check_expiry
    if @order.checkout_expired?
      redirect_to checkout_expired_path, alert: "ลิงค์หมดอายุแล้ว"
    end
  end

  def redirect_with_success(message)
    redirect_to checkout_confirmation_path(@order.checkout_token), notice: message
  end

  def redirect_with_error(message)
    redirect_to checkout_confirmation_path(@order.checkout_token), alert: message
  end

  def order_params
    params.require(:order).permit(
      :quantity, :customer_name, :customer_phone,
      :customer_email, :customer_address, :notes
    )
  end

  # Helper method เพื่อหา path ที่ถูกต้องตามสถานะของ order
  def appropriate_checkout_path
    case @order.status
    when "on_hold_insufficient_credit"
      checkout_on_hold_path(@order.checkout_token)
    when "pending"
      checkout_path(@order.checkout_token)
    else
      checkout_confirmation_path(@order.checkout_token)
    end
  end
end
