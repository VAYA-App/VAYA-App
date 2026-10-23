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
| [docs/TESTING.md](docs/TESTING.md) | ชนิดของ test, coverage และ CI |
| [docs/USABILITY-TEST.md](docs/USABILITY-TEST.md) | แผนและผล Usability Testing |

## เริ่มต้น

```bash
flutter --version   # ต้องเป็น 3.44 ขึ้นไป
flutter pub get
flutter run
```

### เปิดใช้ Gemini จริง

ถ้าไม่ใส่ key แอปใช้ mock และทุกขั้นที่ใช้ AI จะใช้ fallback ที่คำนวณด้วยโค้ดแทน ถ้าจะใช้ Gemini จริง:

1. สร้าง API key ที่ [Google AI Studio](https://aistudio.google.com/apikey) แล้วจำกัดให้ใช้ได้เฉพาะ Generative Language API
2. copy `env.example.json` เป็น `env.json` แล้วใส่ key (`env.json` อยู่ใน `.gitignore` ห้าม commit)
3. รันด้วย

```bash
flutter run --dart-define-from-file=env.json
```

key จะถูกฝังอยู่ในแอป ใช้สำหรับ demo เท่านั้น เมื่อตั้ง Firebase AI Logic แล้ว (#26) ให้ย้ายไปใช้ตัวนั้น

### ดู UI ใน Chrome (ไม่ต้องมี simulator)

```bash
flutter run -d chrome
```

ลากย่อขยายหน้าต่างเพื่อทดสอบขนาดจอตาม M3: แคบกว่า 600px = compact (มือถือ), 840px ขึ้นไป = expanded (แท็บเล็ตแนวนอน) ส่วน web มีไว้ดู UI ระหว่างพัฒนาเท่านั้น แอปจริงคือ Android + iOS

## สถานการณ์สำหรับ Demo

1. เสาร์–อาทิตย์ 2 วัน 1 คืน งบ 6,000 บาท 2 คน ออกจากกรุงเทพฯ ชอบทะเลกับคาเฟ่ เที่ยวแบบชิล → ชลบุรี
2. เที่ยวในกรุงเทพฯ 1 วัน งบ 1,500 บาท 1 คน สายวัดกับประวัติศาสตร์
3. ชลบุรี 3 วัน 2 คืน งบ 3,000 บาท 4 คน → Over Budget

ทั้ง 3 สถานการณ์เป็น test ใน [`test/planner/demo_scenarios_test.dart`](test/planner/demo_scenarios_test.dart) (รันผ่าน pipeline จริงกับข้อมูลใน `assets/data/` แทนแค่ Gemini ด้วยคำตอบจาก `test/fixtures/`)

| | ค่าที่กรอก | ผลที่ต้องได้ |
|---|---|---|
| 1 | 14–15 พ.ย. 2026 · กทม→ชลบุรี · รถทัวร์ · รถสาธารณะ · ทะเล, คาเฟ่ · ชิล | แผน 2 วัน 1 คืนจากที่ Gemini เลือก อยู่ในงบ |
| 2 | 14 พ.ย. 2026 · กทม→กทม · รถสาธารณะ · วัด/ประวัติศาสตร์ · ปกติ | ไม่มีขาเดินทางข้ามเมือง (ค่าเดินทางข้ามเมือง 0) ไม่มีที่พัก อยู่ในงบ |
| 3 | 14–16 พ.ย. 2026 · กทม→ชลบุรี · รถทัวร์ · แท็กซี่ · ทะเล, ซีฟู้ด · ชิล | Over Budget พร้อมคำแนะนำ 2–3 ข้อ (ใช้ fallback แทน Gemini เหมือนตอน Gemini ล่ม) |

รันเฉพาะชุดนี้: `flutter test test/planner/demo_scenarios_test.dart`
