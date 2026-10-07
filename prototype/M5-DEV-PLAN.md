# M5 Cost Estimate — แผนพัฒนา

เจ้าของ: @tp-job · Epic #7 · sub-issues #33 → #34 → #35, และ #36 (คู่ขนาน)
จัดทำ 7 ต.ค. 2026 จาก issue บน GitHub + โค้ดที่ `origin/main` (341d7a2)

ไฟล์นี้อยู่ใน `prototype/` (untracked) ยังไม่ได้ commit

---

## 1. สถานะตอนนี้

| เรื่อง | สถานะ |
|---|---|
| #12 Domain contract (สิ่งที่ M5 ขึ้นกับ) | ปิดแล้ว — `CostEstimate`, `CostCalculator` interface, mock plan มีครบ |
| #33 #34 #35 #36 | ยังไม่เริ่ม ไม่มี branch ไม่มี PR |
| `assets/data/pricing.json` | ยังไม่มี |
| `costCalculatorProvider` | ยัง `throw UnimplementedError('CostCalculator: see #34')` |
| pipeline จริง (#31) | merge แล้ว แต่ยังใช้ไม่ได้เพราะรอ `CostCalculator` (#34) และ advisor (#37) |
| หน้า Trip Plan | มีการ์ดสรุปงบแบบ private อยู่แล้วใน `trip_plan_screen.dart` (ยอดรวม / งบ / ต่อคน / ป้าย "ราคาโดยประมาณ") ยังไม่มี breakdown |
| ตารางสปรินต์ (SPRINT-2W) | แผนเดิม #33 จ.5 · #34 อ.6–พฤ.8 · #35 ศ.9 · #36 จ.12 → ตอนนี้ช้ากว่าแผนราว 2 วัน |
| branch ในเครื่อง `proto/m5-m6-ui` | ตามหลัง `origin/main` 5 commit (ไม่มี commit ไหนแตะ `lib/domain`, `lib/planner`, `assets/data`) |

งานคนอื่นที่รอ M5: **#24** ของ @Nirapada-p (นัดไว้ อ.13) เรียก `minimumTripCost` จาก #35

---

## 2. สิ่งที่ issue เขียนไม่ตรงกับโค้ดจริง

ต้องยึดโค้ด เพราะเป็น contract ที่ merge แล้วและ `DefaultPlannerService` เรียกใช้อยู่

1. **ชื่อ method** — #34 เขียน `CostCalculator.estimate()` แต่ interface จริงคือ
   `applyCosts({request, plan, catalog}) → TripPlan` (เติม `cost` ของทุก Stop / NightStay / IntercityLeg + `plan.cost` + `plan.status`)
2. **`minimumTripCost({request, province}) → int`** ไม่รับ catalog และไม่รับตารางราคา
   → `DefaultCostCalculator` ต้องถือ `PricingTable` ไว้ใน constructor
3. **`lib/planner/` ห้าม import Flutter** (AC ของ #12) → `PricingTable.fromJson` อยู่ใน planner ได้ แต่ตัวอ่าน asset (`rootBundle`) ต้องอยู่ `lib/data/` แบบเดียวกับ `asset_place_catalog.dart`
4. **provider เป็น sync แต่การโหลด asset เป็น async** — `costCalculatorProvider` เป็น `Provider<CostCalculator>` และ `pipelinePlannerServiceProvider` `ref.watch` แบบ sync ต้องเลือกวิธีต่อ (ดูข้อ D3)
5. **#36 บอกให้สร้าง `CostSummaryCard`** แต่หน้า Trip Plan มีการ์ดสรุปของ @Kritternai อยู่แล้ว → งานจริงคือแยกส่วนงบออกมาเป็น widget ใหม่แล้วเสียบกลับ ต้องแตะ `trip_plan_screen.dart` ของคนอื่น
6. **`formatBaht(int)` มีแล้ว** ใน `lib/shared/formatters.dart` ไม่ต้องเขียนใหม่

---

## 3. เรื่องที่ต้องตัดสินใจก่อนเริ่ม #34

#33 เริ่มได้เลยโดยไม่ต้องรอข้อใด

**D1 — ใช้กฎตาม issue หรือกฎที่อนุมัติเมื่อ 4 ต.ค.**
ตัวเลข mock `trip_plan_chonburi_2d.json` (2 คน, 2 วัน 1 คืน, รถทัวร์, รถสาธารณะ, งบ 7,000):

| หมวด | กฎตาม issue (= mock ปัจจุบัน) | กฎที่อนุมัติ 4 ต.ค. |
|---|---|---|
| เดินทางข้ามเมือง | 524 | 524 |
| ที่พัก | 3,000 | 3,000 |
| อาหาร | 720 | 920 (+ มื้อเช้าวันแรก 100 × 2) |
| ค่าเข้าชม | 1,000 | 1,000 |
| เดินทางในพื้นที่ | 480 (8 เที่ยว) | 540 (+ เที่ยวกลับที่พักคืนที่ 1) |
| เงินสำรอง 10% | 572 | 598.40 |
| **รวม** | **6,296** | **6,582.40** |

ถ้าใช้กฎที่อนุมัติ ต้องแก้ mock ใน PR #34 (AC ข้อ 4 อนุญาต) และควรแจ้งทีม เพราะ test ของ #39/#66 อาจอ้างเลขเดิม
ข้อเสนอ: ใช้กฎที่อนุมัติ

**D2 — ทศนิยม**
`CostEstimate` ทุกช่องเป็น `int` กฎที่อนุมัติบอก "แสดงค่าจริง ไม่ปัด" ซึ่งต้องแก้ `lib/domain` (ต้องแจ้งกลุ่มก่อน merge และยังไม่ได้คุยกับ @Kritternai)
ข้อเสนอ: M5 คง `int` ไว้ — คำนวณเป็น `double` ภายใน แล้วปัดครั้งเดียวตอนใส่ `CostEstimate` (เงินสำรองปัดปกติ, ต่อคนปัดขึ้นตาม #34) ยอดรวม mock จะเป็น 6,582 เรื่อง `double` แยกเป็น issue ต่างหาก

**D3 — โหลด `pricing.json` เข้า provider อย่างไร**
ข้อเสนอ: เพิ่ม `pricingTableProvider` (`FutureProvider`) ใน `data_providers.dart` แล้วให้ `DefaultPlannerService` ได้ calculator หลังโหลดเสร็จ วิธีที่แตะโค้ดคนอื่นน้อยสุดคือแก้เฉพาะ `planner_providers.dart` (ไฟล์นี้อยู่ในรายการของ #34 อยู่แล้ว) รายละเอียดสรุปตอนเริ่ม #34 หลังเห็น `PricingTable` จริง

**D4 — กฎที่อนุมัติแล้วแต่ทำใน M5 ไม่ได้ถ้าไม่แก้ domain/data**
- ค่าเข้าชม "ไม่ทราบ ≠ ฟรี": `Place.entranceFee` เป็น `int` default 0 และ `docs/DATA.md` กำหนดว่า "เข้าฟรีไม่ต้องใส่" → แยกไม่ออก
- ป้าย "ประมาณการ" เมื่อไม่มีข้อมูลที่พัก: ไม่มีช่องเก็บใน `NightStay` / `CostEstimate`
ข้อเสนอ: M5 ไม่แก้ domain — ที่พักไม่มีข้อมูลยังคิดราคาตาม tier จาก `CandidateBuilder.priceCap` ได้ (ไม่เป็น 0) แต่ยังไม่มีป้าย ส่วนค่าเข้าชมไม่ทราบ เปิดเป็นเรื่องคุยกับ @Nirapada-p แยก

**D5 — มื้อเช้า**
ที่ทำไว้ใน prototype: มื้อเช้าที่ต้องจ่าย = จำนวนวัน − จำนวนคืน เมื่อที่พักรวมมื้อเช้า (วันแรกยังจ่าย) คุณยังไม่ได้ยืนยันการตีความนี้

สิ่งที่ทำได้ทันทีโดยไม่แก้ domain: UI 3 บรรทัด (ค่าใช้จ่ายจริง = `total − buffer` / เงินสำรอง / รวม) และข้อความแบบเบาเมื่อ `total > budget` แต่ `total − buffer ≤ budget`

---

## 4. แผนรายงาน

### #33 Pricing table — `feat/33-pricing-table` · ~0.5 วัน
ไฟล์
- `assets/data/pricing.json` (โฟลเดอร์ `assets/data/` ลงทะเบียนใน `pubspec.yaml` แล้ว)
- `lib/planner/pricing_table.dart` — `PricingTable` + `fromJson` (Dart ล้วน)
- `lib/data/asset_pricing_table.dart` — `loadPricingTable(AssetBundle)`
- `lib/app/providers/data_providers.dart` — `pricingTableProvider`
- `test/planner/pricing_table_test.dart`

โครง `pricing.json` (ค่าจาก PROJECT-PLAN §9)
```json
{
  "roomPerNight":  { "1": 700, "2": 1500, "3": 3000, "4": 6000 },
  "mealPerPerson": { "1": 80,  "2": 200,  "3": 450,  "4": 1000 },
  "breakfastPerPerson": 100,
  "localTransport": {
    "rentalCar":       { "perDay": 1000, "perKm": 2.5, "capacity": 4 },
    "rentalMotorbike": { "perDay": 250,  "perKm": 1,   "capacity": 2 },
    "taxi":            { "perTrip": 40,  "perKm": 12,  "capacity": 4 },
    "publicTransport": { "perTripPerPerson": 30 }
  },
  "selfDrivePerKm": 2.5,
  "bufferRate": 0.10
}
```
ค่าทางด่วนอยู่ใน `provinces.json` (`intercity.<origin>.car.toll`) อยู่แล้ว ไม่ใส่ซ้ำ — ต่างจากที่ #33 เขียน ควรหมายเหตุใน PR

ขั้นตอน
1. เขียน JSON + model + loader
2. test: โหลดไฟล์จริงแล้วค่าตรง, key ขาด/enum ไม่ครบ 4 โหมดต้อง throw
3. ตรวจราคากับของจริง กทม./ชลบุรี จดแหล่งที่มาใน PR

### #34 Cost calculator — `feat/34-cost-calculator` · ~2 วัน
ไฟล์
- `lib/planner/default_cost_calculator.dart`
- `lib/app/providers/planner_providers.dart` (เปลี่ยน `costCalculatorProvider`)
- `test/planner/cost_calculator_test.dart`
- `assets/mock/trip_plan_chonburi_2d.json` (ถ้า D1 = กฎที่อนุมัติ)

ลำดับ commit ตาม issue
1. ที่พัก + อาหาร — ห้อง = ⌈คน/2⌉, ราคาตาม `priceLevel` ของที่พักใน `NightStay`, มื้อตาม `priceLevel` ร้าน × คน, มื้อเช้าตาม D5
2. ค่าเข้าชม + เดินทางในพื้นที่ — ใช้ `Stop.travelFromPrevKm` ตรง ๆ (มี ×1.3 แล้ว ห้ามคูณซ้ำ), เที่ยวกลับที่พักคำนวณจากพิกัดใน catalog ด้วย `geo.dart`, รถเช่าคิดทุกวันของทริป
3. ข้ามเมือง — จาก `Province.intercity[originId][mode]`; `request.staysInOrigin(...)` → 0 และ `plan.intercity == null`
4. เงินสำรอง, รวม, ต่อคน, `status`
5. test: ทุกหมวด × 4 โหมด × คน 1/2/3/5, กทม→กทม, ทริป 1 วัน, mock ตรงกับเครื่องคิดเลข

ผลพลอยได้: หลัง merge แล้ว pipeline จริงของ #31 เหลือรอแค่ #37

### #35 Minimum trip cost — `feat/35-minimum-trip-cost` · ~0.5 วัน
- เพิ่ม `minimumTripCost` ใน `default_cost_calculator.dart`
- = ข้ามเมืองถูกสุดในบรรดาโหมดที่ `Province.intercity[originId]` มี + ห้อง ฿ + อาหาร ฿ + มื้อเช้า + รถสาธารณะ/โหมดถูกสุด + เงินสำรอง
- ต้องกำหนดสมมติฐาน "จำนวนมื้อและจำนวนเที่ยวต่อวัน" ให้ชัดใน doc comment (prototype ใช้ 2 มื้อ/วัน ลบมื้อสุดท้าย และจำนวน Stop ต่อวันคงที่)
- test: ต้นทาง = ปลายทาง, 1 วัน, หลายวัน, หลายคน และต้อง ≤ ผลของ `applyCosts` บน mock
- merge แล้วแจ้ง @Nirapada-p ว่า #24 เริ่มได้

### #36 Cost summary UI — `feat/36-cost-summary-ui` · ~1.5 วัน (ไม่ขึ้นกับ #33–#35)
ไฟล์
- `lib/features/trip_plan/widgets/cost_summary_card.dart`
- `lib/features/trip_plan/widgets/cost_breakdown_sheet.dart`
- `lib/features/trip_plan/trip_plan_screen.dart` (เสียบ widget ใหม่แทนส่วนงบเดิม)
- `test/features/trip_plan/cost_summary_card_test.dart`

ขั้นตอน
1. คุยกับ @Kritternai ก่อนว่าจะแทนส่วนงบในการ์ดเดิมหรือวางเป็นการ์ดแยก
2. `CostSummaryCard`: `Card.filled`, ยอดรวม `headlineMedium`, `LinearProgressIndicator` ใช้ไป/งบ (clamp ที่ 1.0 เมื่อเกินงบ), ต่อคน, ป้าย "ราคาโดยประมาณ"
3. `CostBreakdownSheet`: `showModalBottomSheet(showDragHandle: true)` + `ListTile` 5 หมวด + เงินสำรอง + รวม
4. widget test: แตะแล้วเห็นครบทุกหมวด และตัวเลขตรงกับ mock
5. ตรวจ Light/Dark, Compact/Expanded, ตัวอักษร 200% แล้วถ่ายภาพแนบ PR
ใช้ `prototype/index.html` เป็นแบบอ้างอิงของ layout

---

## 5. ลำดับและกำหนดเวลาที่เสนอ

```
#33 ──► #34 ──► #35 ──► (#24 ของ Nirapada-p)
                 └────► #37 (M6)
#36 (ทำบน mock ได้ตลอด) ──► #38 (M6)
```

| วัน | งาน |
|---|---|
| พ. 7 ต.ค. | #33 เปิด PR + ตัดสินใจ D1–D5 |
| พฤ. 8 – ศ. 9 | #34 |
| จ. 12 (เช้า) | #35 → ปลดล็อก #24 ทันกำหนด อ. 13 |
| จ. 12 – อ. 13 | #36 |

M6 (#37, #38) จะเลื่อนจากแผนเดิม อ.13–พ.14 ไปราว 1–2 วัน ต้องเทียบกับวัน feature freeze (#44) อีกที
ถ้าต้องการกู้เวลา: #36 ไม่ขึ้นกับ #34 ทำสลับช่วงรอ review ได้

---

## 6. ความเสี่ยง

- **mock เปลี่ยนเลข** (D1) กระทบ test ของหน้า Trip Plan และ generating — รัน `flutter test` ทั้งชุดก่อนเปิด PR #34
- **แตะไฟล์ของ @Kritternai** สองจุด: `planner_providers.dart` (#34) และ `trip_plan_screen.dart` (#36) — PR #90–#93 ของเขายังเปิดอยู่ อาจ conflict
- **ข้อมูลสถานที่ยังเป็นตัวอย่าง** (กทม. 8 แห่ง, ชลบุรี 10 แห่ง; #20–#22 ยังเปิด) — test ของ calculator ต้องใช้ fixture ของตัวเอง (`test/planner/test_data.dart`) ไม่ผูกกับ asset จริง
- **กฎที่อนุมัติบางข้อยังทำไม่ได้** (D4) — ต้องเขียนไว้ใน PR ว่าตั้งใจเลื่อน ไม่ใช่ลืม

## 7. ทุก PR ต้องผ่าน

```
dart format lib test
flutter analyze
flutter test
```
ชื่อ branch / PR / commit ตามที่แต่ละ issue กำหนด · Squash and merge · `lib/domain` ไม่แตะใน M5
