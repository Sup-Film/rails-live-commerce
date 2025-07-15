class ProductsController < ApplicationController
  before_action :set_product, only: %i[ show edit update destroy ]
  before_action :require_login, only: %i[ new create edit update destroy index show ]

  # GET /products or /products.json
  def index
    @products = current_user.products.active.order(created_at: :asc)
  end

  # GET /products/1 or /products/1.json
  def show
  end

  # GET /products/new
  def new
    # @product = Product.new # ถ้าใช้แบบนี้จะไม่มี user_id จะ error!
    @product = current_user.products.build
  end

  # GET /products/1/edit
  def edit
  end

  # POST /products or /products.json
  def create
    @product = current_user.products.build(product_params)
    # @product = Product.new(product_params) # ถ้าใช้แบบนี้จะไม่มี user_id จะ error!

    respond_to do |format|
      if @product.save
        format.html { redirect_to @product, notice: "สินค้าถูกสร้างเรียบร้อยแล้ว" }
        format.json { render :show, status: :created, location: @product }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /products/1 or /products/1.json
  def update
    respond_to do |format|
      if @product.update(product_params)
        format.html { redirect_to @product, notice: "แก้ไขสินค้าสำเร็จ" }
        format.json { render :show, status: :ok, location: @product }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /products/1 or /products/1.json
  def destroy
    @product.soft_delete!

    respond_to do |format|
      format.html { redirect_to products_path, status: :see_other, notice: "ลบสินค้าสำเร็จ" }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_product
    @product = current_user.products.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def product_params
    params.require(:product).permit(:productName, :productDetail, :productPrice, :productCode, :image, :product_image)
  end

  # Method สำหรับตรวจสอบว่าผู้ใช้ล็อกอินอยู่หรือไม่
  def require_login
    unless user_signed_in?
      redirect_to root_path, alert: "กรุณาเข้าสู่ระบบก่อนดำเนินการ."
    end
  end
end
