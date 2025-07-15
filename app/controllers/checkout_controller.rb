class CheckoutController < ApplicationController
  before_action :find_order, only: [:show, :update, :confirmation, :complete, :cancel]
  before_action :check_expiry, only: [:show, :update]

  def index
    # หน้ารายการคำสั่งซื้อทั้งหมด
    @orders = Order.where(status: "pending").order(created_at: :desc)
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

    # ถ้า status เป็น pending จะแสดงฟอร์มให้กรอกข้อมูล
    # Rails จะ render app/views/checkout/show.html.erb โดยอัตโนมัติ
    # พร้อมส่ง @order ไปให้ view ใช้งาน
  end

  def update
    # อัพเดทข้อมูลลูกค้าและจำนวนสินค้า
    result = OrderService.update_order(@order, order_params)

    if result
      redirect_to checkout_confirmation_path(@order.checkout_token),
                  notice: "บันทึกข้อมูลเรียบร้อยแล้ว"
    else
      flash.now[:alert] = "ไม่สามารถบันทึกข้อมูลได้: #{@order.errors.full_messages.join(", ")}"
      render :show
    end
  end

  def confirmation
    # หน้ายืนยันข้อมูลก่อนชำระเงิน
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
      redirect_to expired_checkout_path, alert: "ลิงค์หมดอายุแล้ว"
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
end
