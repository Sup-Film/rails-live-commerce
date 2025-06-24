# Clean Code Principles: ตัวอย่างจาก FacebookLiveWebhookService

## 1. Separation of Concerns (แยกหน้าที่)
- แต่ละเมธอดใน service นี้รับผิดชอบงานเฉพาะส่วน เช่น
  - `process` รับข้อมูล webhook และวนลูปข้อมูล entry เพื่อส่งต่อไปประมวลผล
  - `process_entry` รับข้อมูลแต่ละกลุ่ม (entry) และวนลูปข้อมูล (changes) ที่อยู่ภายใน entry เพื่อส่งต่อไปประมวลผล
  - `process_live_change` รับข้อมูลการเปลี่ยนแปลงแต่ละรายการ (change) แล้วแยกประเภท event เพื่อส่งต่อไปยัง handler ที่เหมาะสม
- การแยกหน้าที่แบบนี้ทำให้โค้ดอ่านง่ายและแก้ไขเฉพาะจุดได้ง่าย

## 2. Single Responsibility Principle (SRP)
- ทุกเมธอดมีหน้าที่เดียวชัดเจน เช่น `handle_live_started` มีหน้าที่แค่จัดการ event live start เท่านั้น
- ถ้าต้องเปลี่ยน logic เฉพาะส่วน จะไม่กระทบเมธอดอื่น

## 3. Readability & Maintainability
- โค้ดที่แบ่งย่อยเป็นเมธอดสั้น ๆ ช่วยให้ลำดับการประมวลผลของโปรแกรมชัดเจน
- สามารถ debug หรือเพิ่ม log เฉพาะจุดได้ง่าย
- ถ้าต้องเพิ่ม event ใหม่ เช่น live_paused สามารถเพิ่ม handler ใหม่ได้โดยไม่ยุ่งกับ logic เดิม

## 4. Testability
- สามารถเขียน unit test แยกแต่ละเมธอดได้ เช่น ทดสอบเฉพาะ `process_entry` หรือ `process_live_change`
- ลดความซับซ้อนของ test case

## 5. Reusability
- เมธอดย่อยสามารถนำกลับมาใช้ซ้ำใน service อื่น ๆ ได้
- ถ้าต้องการประมวลผลข้อมูลรูปแบบอื่นในอนาคต สามารถ reuse โครงสร้างนี้ได้ทันที

---

**ตัวอย่างโค้ด:**

```ruby
class FacebookLiveWebhookService
  attr_reader :data

  def initialize(data)
    @data = data
  end

  def process
    return unless data['entry']
    # รับข้อมูล webhook แล้วแยกข้อมูลแต่ละกลุ่ม (entry) เพื่อส่งต่อไปประมวลผล
    data['entry'].each do |entry|
      process_entry(entry)
    end
  end

  private

  def process_entry(entry)
    # รับข้อมูลแต่ละกลุ่ม (entry) แล้วแยกข้อมูลย่อย (changes) เพื่อส่งต่อไปประมวลผล
    entry['changes']&.each do |change|
      process_live_change(change) if live_video_change?(change)
    end
  end

  def live_video_change?(change)
    change['field'] == 'live_videos'
  end

  def process_live_change(change)
    value = change['value']
    case value['status']
    when 'live'
      handle_live_started(value)
    when 'live_stopped'
      Rails.logger.info "Live stopped event received: #{value}"
      handle_live_ended(value)
    when 'vod'
      handle_live_to_vod(value)
    end
  end

  def handle_live_started(value)
    FacebookLiveProcessor.new(value).process_live_start
  end

  def handle_live_ended(value)
    FacebookLiveProcessor.new(value).process_live_end
  end

  def handle_live_to_vod(value)
    FacebookLiveProcessor.new(value).process_live_to_vod
  end
end
```

---

**ตัวอย่างโค้ดที่ดี:**
- ไม่เขียนทุกอย่างในเมธอดเดียว
- ใช้ชื่อเมธอดสื่อความหมาย
- รับผิดชอบงานเดียวต่อเมธอด
- ง่ายต่อการขยายและดูแลในอนาคต

---

**สรุป:**  
การแยกเมธอดย่อยใน FacebookLiveWebhookService ตามหลัก Clean Code ช่วยให้โค้ดอ่านง่าย ทดสอบง่าย ดูแลง่าย และลด bug ในระยะยาว เหมาะกับการนำไปใช้ใน production และการทำงานร่วมกับทีม!