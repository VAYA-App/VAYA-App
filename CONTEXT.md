# AI Trip Planner

แอปวางแผนการเดินทางในประเทศไทย ผู้ใช้บอกแค่เวลา งบ และสไตล์ที่อยากเที่ยว แล้วระบบจะเสนอจุดหมายและสร้างแผนการเดินทางพร้อมค่าใช้จ่ายและเส้นทางบนแผนที่

## Language

### คำขอและผู้ใช้

**Trip Request** (คำขอทริป):
ข้อมูลที่ผู้ใช้ป้อนเพื่อขอแผน ได้แก่ วันเดินทาง งบ จำนวนผู้เดินทาง จุดเริ่มต้น และความชอบ โดยยังไม่ต้องระบุจุดหมาย
_Avoid_: Query, Search, Form

**Traveller Count** (จำนวนผู้เดินทาง):
จำนวนคนที่ร่วมทริปเดียวกันภายใต้แผนเดียว
_Avoid_: Group size, Pax

**Budget** (งบประมาณ):
งบรวมของทั้งทริปสำหรับผู้เดินทางทุกคน ส่วนยอดต่อคนคำนวณออกมาเพื่อแสดงผลเท่านั้น
_Avoid_: Price limit, Max cost

**Preference Tags** (แท็กความชอบ):
สไตล์การเที่ยวที่ผู้ใช้เลือกจากรายการที่กำหนดไว้ เช่น ธรรมชาติ ทะเล คาเฟ่ วัด/ประวัติศาสตร์ ใช้คู่กับ Free-text Note
_Avoid_: Interests, Categories

**Free-text Note** (ข้อความเพิ่มเติม):
ความต้องการที่ผู้ใช้พิมพ์เองโดยไม่บังคับ ซึ่งระบบจะตีความเป็นข้อจำกัดหรือความชอบ
_Avoid_: Comment, Prompt

**Pace** (จังหวะการเที่ยว):
ความหนาแน่นของกิจกรรมต่อวัน มีสามระดับ คือ ชิล ปกติ และอัดแน่น
_Avoid_: Speed, Intensity

**Origin** (จุดเริ่มต้น):
เมืองหรือจังหวัดที่ผู้ใช้ออกเดินทางและจะกลับไป
_Avoid_: Home, Start location

### จุดหมายและสถานที่

**Destination** (จุดหมายปลายทาง):
จังหวัดหนึ่งในชุดจังหวัดที่ระบบรองรับ ซึ่งเป็นที่ที่ทริปเกิดขึ้น
_Avoid_: City, Location, Place

**Place** (สถานที่):
จุดที่มีอยู่จริงในข้อมูลของระบบภายใน Destination แบ่งเป็น Attraction, Accommodation และ Restaurant
_Avoid_: POI, Spot, Location

**Attraction** (สถานที่ท่องเที่ยว):
Place ที่ผู้ใช้ไปเที่ยวหรือทำกิจกรรม
_Avoid_: Sight, Activity

**Accommodation** (ที่พัก):
Place ที่ผู้เดินทางพักค้างคืน
_Avoid_: Hotel, Lodging

**Restaurant** (ร้านอาหาร):
Place ที่ผู้เดินทางไปรับประทานอาหาร
_Avoid_: Food spot, Eatery

**Price Level** (ระดับราคา):
ระดับราคาโดยประมาณของ Place (฿ ถึง ฿฿฿฿) ซึ่งระบบใช้แปลงเป็นเงินบาทด้วยตารางประมาณการของโปรเจกต์
_Avoid_: Price, Rate

### แผนและค่าใช้จ่าย

**Destination Suggestion** (จังหวัดที่ระบบเสนอ):
จังหวัดที่ระบบเสนอ 2–3 ตัวเลือกพร้อมเหตุผลและงบประมาณคร่าว ๆ ในกรณีที่ผู้ใช้ไม่ได้ระบุ Destination
_Avoid_: Recommendation, Option

**Trip Plan** (แผนการเดินทาง):
ผลลัพธ์ของ Trip Request หนึ่งรายการ ประกอบด้วย Destination หนึ่งจังหวัด, Day Plan ครบทุกวัน, Intercity Transport และ Cost Estimate
_Avoid_: Itinerary, Schedule, Trip

**Day Plan** (แผนรายวัน):
ลำดับของ Stop ภายในหนึ่งวันของ Trip Plan
_Avoid_: Day, Daily schedule

**Stop** (จุดแวะ):
การไป Place หนึ่งแห่งใน Day Plan โดยมีเวลาเริ่ม ระยะเวลาที่อยู่ และค่าใช้จ่าย Place เดียวกันอาจเป็นหลาย Stop ได้ เช่น Accommodation ที่กลับไปทุกคืน
_Avoid_: Item, Activity, Visit

**Night Stay** (การพักค้างคืน):
การกำหนดว่าคืนหนึ่งของทริปพักที่ Accommodation ใด ปกติทุกคืนจะพักที่เดียวกัน แต่แยกเป็นคนละที่ได้ถ้า Attraction ของวันนั้นอยู่ไกล หรือผู้ใช้เปลี่ยนเอง
_Avoid_: Booking, Check-in

**Local Transport Mode** (วิธีเดินทางในพื้นที่):
วิธีที่ผู้เดินทางใช้ไปมาระหว่าง Stop ภายใน Destination เช่น เช่ารถยนต์ เช่ามอเตอร์ไซค์ Grab/แท็กซี่ หรือรถสาธารณะ
_Avoid_: Vehicle, Transport

**Over Budget** (เกินงบ):
สถานะของ Trip Plan ที่ Cost Estimate สูงกว่า Budget ระบบยังคงแสดงแผนนั้น พร้อมบอกยอดที่เกินและคำแนะนำ
_Avoid_: Invalid plan

**Plan Edit** (การแก้แผน):
การเปลี่ยนแปลง Trip Plan หลังสร้างเสร็จแล้ว ไม่ว่าผู้ใช้จะแก้เองหรือสั่งผ่านแชทกับ AI ทุกครั้งที่แก้ ระบบจะคำนวณ Cost Estimate และลำดับเส้นทางใหม่
_Avoid_: Update, Modify

**Intercity Transport** (การเดินทางข้ามเมือง):
การเดินทางระหว่าง Origin กับ Destination ทั้งขาไปและขากลับ โดยระบบประเมินราคาแต่ไม่จองให้
_Avoid_: Flight, Transfer

**Cost Estimate** (ค่าใช้จ่ายโดยประมาณ):
ยอดเงินรวมที่ระบบคำนวณได้ของแผน แยกเป็นหมวด ได้แก่ เดินทาง ที่พัก อาหาร และค่าเข้าชม
_Avoid_: Price, Total, Bill

### การเรียนรู้จากผู้ใช้

**Place Feedback** (ความเห็นต่อสถานที่):
การกด 👍 หรือ 👎 ของผู้ใช้ที่ Stop หนึ่ง ซึ่งระบบนำไปใช้ปรับการแนะนำครั้งต่อไป
_Avoid_: Rating, Review

**Taste Profile** (โปรไฟล์ความชอบ):
ความชอบสะสมของผู้ใช้ที่ได้จาก Place Feedback เก็บเป็นน้ำหนักของ Preference Tags แต่ละตัว พร้อมรายการ Place ที่ผู้ใช้ไม่ชอบ
_Avoid_: User preferences, Settings
