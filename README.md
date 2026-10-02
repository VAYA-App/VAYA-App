# VAYA: AI Trip Planner

แอปวางแผนเที่ยวในประเทศไทย ผู้ใช้บอกแค่ว่า **"มีเวลาเท่านี้ มีงบเท่านี้ อยากเที่ยวแบบนี้"** แล้วระบบจะเสนอจังหวัด สร้างแผนรายวัน คำนวณค่าใช้จ่าย และแสดงเป็นไทม์ไลน์กับแผนที่

Flutter (Android + iOS) · Material 3 · Firebase (Auth, Firestore, AI Logic + Gemini) · OpenStreetMap

## เอกสาร

| เอกสาร | อ่านเมื่อ |
|---|---|
| [docs/SPRINT-2W.md](docs/SPRINT-2W.md) | **เริ่มที่นี่**: scope, ใครทำอะไร, ตารางรายวัน |
| [CONTRIBUTING.md](CONTRIBUTING.md) | ก่อนแตก branch หรือเปิด PR ครั้งแรก |
| [docs/DESIGN.md](docs/DESIGN.md) | ก่อนทำหน้าจอใด ๆ (Material 3 เท่านั้น) |
| [CONTEXT.md](CONTEXT.md) | ศัพท์ของโดเมน (Trip Request, Stop, Night Stay, …) |
| [docs/PROJECT-PLAN.md](docs/PROJECT-PLAN.md) | schema, สูตรราคา, pipeline |
| [docs/adr/](docs/adr/) | เหตุผลของการตัดสินใจสำคัญ |

## เริ่มต้น

```bash
flutter --version   # ต้องเป็น 3.44 ขึ้นไป
flutter pub get
flutter run
```

### ดู UI ใน Chrome (ไม่ต้องมี simulator)

```bash
flutter run -d chrome
```

ลากย่อขยายหน้าต่างเพื่อทดสอบขนาดจอตาม M3: แคบกว่า 600px = compact (มือถือ), 840px ขึ้นไป = expanded (แท็บเล็ตแนวนอน) ส่วน web มีไว้ดู UI ระหว่างพัฒนาเท่านั้น แอปจริงคือ Android + iOS

## สถานการณ์สำหรับ Demo

1. เสาร์–อาทิตย์ 2 วัน 1 คืน งบ 6,000 บาท 2 คน ออกจากกรุงเทพฯ ชอบทะเลกับคาเฟ่ เที่ยวแบบชิล → ชลบุรี
2. เที่ยวในกรุงเทพฯ 1 วัน งบ 1,500 บาท 1 คน สายวัดกับประวัติศาสตร์
3. ชลบุรี 3 วัน 2 คืน งบ 3,000 บาท 4 คน → Over Budget
