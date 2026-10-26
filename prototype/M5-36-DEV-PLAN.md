# #36 Cost summary and breakdown UI — แผนพัฒนา

Branch: `feat/36-cost-summary-ui` (แตกจาก `main` ที่ 51f0050 ซึ่งมี #33–#35 แล้ว)
PR: `feat(trip-plan): add cost summary and breakdown (#36)` · ประมาณ 1–1.5 วัน
จัดทำ 8 ต.ค. 2026

---

## 1. สถานะจริงของหน้าจอ (ต่างจากที่ issue สมมติ)

Issue #36 เขียนเหมือนยังไม่มีการ์ดสรุป แต่ PR #70 ของ @Kritternai ทำ `_TripSummaryCard` ไว้แล้วใน `trip_plan_screen.dart` (บรรทัด 376–505) ประกอบด้วย

1. แท็กความชอบ + ชื่อทริป ("ชลบุรี 2 วัน 1 คืน") + ป้าย "อยู่ในงบ / เกินงบ ฿x"
2. **กล่องงบ**: ยอดรวม / งบ และเฉลี่ยต่อคน
3. บรรทัดที่พัก
4. ป้าย "ราคาโดยประมาณ"

โค้ดมี comment ทิ้งไว้ว่า `The per-category breakdown sheet comes from #36`

สิ่งที่ยังขาดเทียบกับ #36
- แถบสัดส่วนใช้ไป/งบ
- แตะแล้วเปิด bottom sheet แยกหมวด
- เป็น widget แยกไฟล์ที่มี test
- ยังไม่มี widget test ของหน้า Trip Plan เลย

## 2. สิ่งที่จะสร้าง

### `CostSummaryCard` — `lib/features/trip_plan/widgets/cost_summary_card.dart`
รับ `CostEstimate cost` และ `int travellerCount` (ไม่ผูกกับ provider จึงทดสอบง่าย และ #38 นำไปใช้ต่อได้)

```text
┌────────────────────────────────────┐  Card.filled
│ ค่าใช้จ่ายโดยประมาณ                    │  labelLarge
│ ฿6,582  / งบ ฿7,000                 │  headlineMedium + bodyMedium
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░  94%            │  LinearProgressIndicator (determinate)
│ ต่อคน (2 ท่าน) ฿3,291   ดูรายละเอียด › │
└────────────────────────────────────┘
```
- ทั้งการ์ดแตะได้ (`InkWell`) → เปิด breakdown sheet · `Semantics(button, label: 'ดูรายละเอียดค่าใช้จ่าย')`
- แถบ: `value = total / budget` จำกัดที่ 1.0 · เกินงบใช้สี `error` และเขียน "110% ของงบ" (ไม่สื่อด้วยสีอย่างเดียว)
- บรรทัดล่างใช้ `Wrap` เพื่อให้ตัวอักษร 200% ตกบรรทัดได้โดยไม่ล้น

### `showCostBreakdownSheet` — `lib/features/trip_plan/widgets/cost_breakdown_sheet.dart`
`showModalBottomSheet(showDragHandle: true, isScrollControlled: true)` + `ListTile`

| แถว | ไอคอน | ค่า mock |
|---|---|---|
| เดินทางข้ามเมือง | `directions_bus_outlined` | ฿524 |
| ที่พัก | `bed_outlined` | ฿3,000 |
| อาหาร | `restaurant_outlined` | ฿920 |
| ค่าเข้าชม | `confirmation_number_outlined` | ฿1,000 |
| เดินทางในพื้นที่ | `local_taxi_outlined` | ฿540 |
| — เส้นคั่น — | | |
| ค่าใช้จ่ายจริง | | ฿5,984 |
| เงินสำรอง 10% | `savings_outlined` | ฿598 |
| **รวมทั้งหมด** | | **฿6,582** |
| งบ / เฉลี่ยต่อคน | | ฿7,000 / ฿3,291 |

สามบรรทัด "ค่าใช้จ่ายจริง / เงินสำรอง / รวม" มาจากกฎที่อนุมัติ 4 ต.ค. · ป้าย "ราคาโดยประมาณ" อยู่ท้าย sheet

### แก้ `trip_plan_screen.dart`
แทน **กล่องงบ** (ข้อ 2 ในรายการด้านบน ราว 50 บรรทัด) ด้วย `CostSummaryCard` ส่วนชื่อทริป ป้ายสถานะ และบรรทัดที่พักคงเดิม

## 3. เรื่องที่ต้องตัดสินใจ (ใส่ค่าเริ่มต้นไว้)

| # | เรื่อง | ค่าเริ่มต้น | อีกทาง |
|---|---|---|---|
| D1 | วางตรงไหน | แทนกล่องงบเดิมในการ์ดสรุปของ @Kritternai (หน้าตาใกล้ของเดิมที่สุด) | วางเป็นการ์ดแยกใต้การ์ดสรุป: ไม่แตะโค้ดเขา แต่ยอดรวมจะซ้ำสองที่ |
| D2 | หมวดที่เป็น 0 | แสดงครบ 5 หมวดเสมอเป็น ฿0 (AC: "เห็นครบทุกหมวด") | ซ่อนหมวดที่เป็น 0 |
| D3 | เนื้อหา sheet | 5 หมวด + ค่าใช้จ่ายจริง + เงินสำรอง + รวม + งบ + ต่อคน | แค่ 5 หมวด + เงินสำรองตาม wireframe ใน issue |
| D4 | ข้อความเมื่อเกินงบ | #36 แสดงแค่ตัวเลขและแถบสีแดง ข้อความ/คำแนะนำเป็นของ #38 | ใส่ข้อความเกินงบใน sheet เลย |
| D5 | ภาพหน้าจอใน PR | ผมรันแอปบน Chrome แล้วจับภาพ compact light และ expanded dark ให้ | คุณจับภาพเอง |

## 4. ผลกระทบกับงานคนอื่น

- **`trip_plan_screen.dart` เป็นของ @Kritternai** (PR #59, #70) — ตอนนี้เขาไม่มี PR เปิดอยู่ จึงไม่ conflict แต่ควรบอกใน PR ว่าแทนกล่องงบ
- `_BudgetBadge` ("อยู่ในงบ / เกินงบ") ไม่แตะ #38 จะมาต่อเรื่อง banner
- หน้า Trip Plan ไม่มี widget test เดิม จึงไม่มี test ที่จะพัง
- จำนวนคนในหัวการ์ดมาจากคำขอ แต่ราคาใน mock คิดไว้ 2 คน (เห็น "1 ท่าน ฿3,291" ได้ถ้ากรอกฟอร์ม 1 คน) เป็นของเดิม ไม่แก้ใน PR นี้ จะหายเมื่อใช้ pipeline จริง

## 5. ลำดับ commit (ตาม issue)

1. `feat(trip-plan): add cost summary card (#36)` — widget + เสียบเข้าหน้า Trip Plan
2. `feat(trip-plan): add cost breakdown bottom sheet (#36)`
3. `test(trip-plan): cover cost summary widgets (#36)`

## 6. แผน test (`test/features/trip_plan/cost_summary_card_test.dart`)

ครอบ widget ด้วย `MaterialApp(theme: AppTheme.light())` ใช้ `CostEstimate` จาก mock จริง

| กรณี | ตรวจอะไร | AC |
|---|---|---|
| แสดงยอด | เห็น ฿6,582, งบ ฿7,000, ต่อคน ฿3,291, "ราคาโดยประมาณ" | 1 |
| แถบสัดส่วน | `LinearProgressIndicator.value` ≈ 6582/7000 และข้อความ "94%" | 1 |
| เกินงบ | งบ 6,000 → แถบเต็ม 1.0 และเขียน "110% ของงบ" | — |
| งบเป็น 0 | ไม่ throw (ไม่หารด้วยศูนย์) | — |
| แตะการ์ด | sheet เปิด เห็นครบ 5 หมวด + เงินสำรอง + รวม และตัวเลขตรง mock | 2 |
| หมวดเป็น 0 | ทริปในจังหวัดเดียว ยังเห็น "เดินทางข้ามเมือง ฿0" | 2 |
| ตัวอักษร 200% | จอกว้าง 360 `TextScaler.linear(2)` ทั้งการ์ดและ sheet ไม่มี overflow | 4 |
| Dark | pump ด้วย `AppTheme.dark()` ไม่ throw | 4 |
| หน้าจริง | เปิด `TripPlanScreen` ด้วย mock แล้วเห็นการ์ดและแตะเปิด sheet ได้ | 1 |

ตรวจด้วยมือ (test ทำแทนไม่ได้): Light + Dark × Compact + Expanded บน Chrome และ `grep "Colors\.\|fontSize"` ในไฟล์ที่แก้ต้องไม่เจอ

## 7. ไม่อยู่ใน #36

- Banner เกินงบ, การ์ดคำแนะนำ, ข้อความแบบเบาเมื่อเกินเพราะเงินสำรอง → #38
- มาสคอตข้าง banner และ avatar บนปุ่ม "ให้ AI ปรับแผน" (ค้างจาก #83) → คุยกับ @Kritternai ตอนทำ #38
- ป้าย "ประมาณการ" ของคืนที่ไม่มีข้อมูลที่พัก และค่าเข้าชม "ไม่ทราบ" → ต้องแก้ `lib/domain`
- รายละเอียดที่มาของแต่ละหมวด (เช่น "2 คน × 2 ขา") → `CostEstimate` เก็บแค่ยอดรวมต่อหมวด

## 8. หลัง merge

- M5 ครบ (#33–#36) ปิด Epic #7 ได้ถ้า DoD ผ่าน: unit test ครบ ✓, ตัวเลขในหน้า Trip Plan ตรงกับ test, "ราคาโดยประมาณ" ทุกจุด
- เหลือค้างจาก #33: ตรวจราคากับของจริง
- ต่อด้วย M6: #37 (advisor) แล้ว #38 (banner ซึ่งใช้ `CostSummaryCard` ตัวนี้)
