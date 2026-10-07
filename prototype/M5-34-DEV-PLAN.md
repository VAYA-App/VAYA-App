# #34 Cost calculator — แผนพัฒนา

Branch: `feat/34-cost-calculator` (แตกจาก `main` ที่ ec4523e ซึ่งมี #33 แล้ว)
PR: `feat(planner): add cost calculator (#34)` · ประมาณ 2 วัน
จัดทำ 7 ต.ค. 2026 · ไฟล์นี้อยู่ใน `prototype/` ไม่ commit

---

## 1. สิ่งที่ต้องส่งมอบ

`DefaultCostCalculator implements CostCalculator` ใน `lib/planner/default_cost_calculator.dart`

```dart
class DefaultCostCalculator implements CostCalculator {
  const DefaultCostCalculator(this.pricing);
  final PricingTable pricing;

  TripPlan applyCosts({request, plan, catalog});          // #34
  int minimumTripCost({request, province});               // #35 — ใน #34 ให้ throw UnimplementedError('see #35')
}
```

`applyCosts` รับแผนที่ทุก `cost` เป็น 0 (จาก `DefaultPlannerService`) แล้วคืนแผนเดิมที่เติม:
`Stop.cost` · `NightStay.cost` · `IntercityLeg.cost` · `TripPlan.cost` · `TripPlan.status`
ต้องเป็น pure function: ไม่แก้ลำดับ Stop, ไม่แตะ `overBudgetAdvice`, เรียกซ้ำได้ผลเท่าเดิม

---

## 2. สูตรแต่ละหมวด

`n` = `request.travellerCount`, `days` = `plan.days.length`

| หมวด | สูตร | ที่มาของข้อมูล |
|---|---|---|
| ที่พัก | Σ ทุก `NightStay`: `pricing.roomFor(place.priceLevel) × stay.rooms` | `catalog.place(stay.placeId)` |
| อาหาร (มื้อ) | Σ Stop ที่ `place.category == restaurant`: `pricing.mealFor(priceLevel) × n` → ใส่ `Stop.cost` | catalog |
| อาหาร (มื้อเช้า) | `pricing.breakfastPerPerson × n × มื้อเช้าที่ต้องจ่าย` (ไม่อยู่ใน Stop ใด) | ดู D5 |
| ค่าเข้าชม | Σ Stop ที่เป็น attraction: `place.entranceFee × n` → ใส่ `Stop.cost` | catalog |
| เดินทางในพื้นที่ | `(perDay × days + perTrip × เที่ยว + perKm × กม.) × rate.unitsFor(n)` | `pricing.rateFor(request.localTransportMode)` |
| ข้ามเมือง | `plan.intercity == null` → 0 · รถ/รถไฟ: `farePerPerson × n × 2` · ขับเอง: `distanceKm × selfDrivePerKm × 2 + toll × 2` | `province.intercity[request.originId][mode]` |
| เงินสำรอง | `(ผลรวม 5 หมวด × bufferRate)` ปัดเป็นจำนวนเต็ม | pricing |
| รวม / ต่อคน | `ผลรวม + เงินสำรอง` / `⌈รวม ÷ n⌉` | |
| สถานะ | `total > budget` → `overBudget` | |

สูตรเดินทางในพื้นที่ใช้สูตรเดียวได้ทั้ง 4 โหมด เพราะ `LocalTransportRate` ใน #33 ให้ช่องที่ไม่ใช้เป็น 0

**การนับเที่ยวและระยะทาง**
- ทุก Stop = 1 เที่ยว ระยะ = `Stop.travelFromPrevKm` (มี ×1.3 แล้ว ห้ามคูณซ้ำ)
- เที่ยวกลับที่พัก: ทุกวันที่มีคืนต่อ (วันที่ 1 ถึง `days − 1`) นับเพิ่ม 1 เที่ยว ระยะ = `travelBetween(Stop สุดท้าย, ที่พัก).km` จาก `geo.dart`
- ทริป 1 วัน: นับเที่ยวกลับจุดเริ่มต้น 1 เที่ยว ใช้ `province.center` (จุดเดียวกับที่ pipeline ใช้เป็นจุดเริ่มวันแรก)
- วันสุดท้ายของทริปค้างคืน: ไม่นับเที่ยวกลับ
- ไม่มี `NightStay` แต่มีคืน: ใช้ `province.center` แทนที่พัก (ตรงกับ `hotel ?? province.center` ใน pipeline)
- รถเช่า: `perDay` คิดทุกวันของทริป

**การปัดเศษ** (ตาม D2 = คง `int`)
ปัดแต่ละหมวดเป็นจำนวนเต็มก่อน → รวม → เงินสำรองปัดจากผลรวม → `total` = ผลรวม + เงินสำรอง
ทำแบบนี้ `5 หมวด + buffer == total` เป็นจริงเสมอ (test `mock trip plan costs add up` ตรวจข้อนี้)
ลำดับนี้ให้ผลตรงกับ mock ปัจจุบัน (5,724 → 572 → 6,296) แสดงว่าคนทำ mock ปัดแบบเดียวกัน

---

## 3. ตัวเลข mock ที่ต้องได้

`trip_plan_chonburi_2d.json` + `trip_request_demo.json` (2 คน, 2 วัน 1 คืน, รถทัวร์, รถสาธารณะ, งบ 7,000)

| หมวด | ที่มา | กฎตาม issue | กฎที่อนุมัติ 4 ต.ค. |
|---|---|---|---|
| ข้ามเมือง | 131 × 2 คน × 2 ขา | 524 | 524 |
| ที่พัก | Hard Rock ระดับ 3 = 3,000 × 1 ห้อง × 1 คืน | 3,000 | 3,000 |
| อาหาร | มื้อ 400 + 160 + 160 = 720; มื้อเช้าวันแรก 100 × 2 | 720 | 920 |
| ค่าเข้าชม | ปราสาทสัจธรรม 500 × 2 | 1,000 | 1,000 |
| ในพื้นที่ | 30 × 2 คน × 8 เที่ยว / 9 เที่ยว (+กลับที่พัก) | 480 | 540 |
| ผลรวม | | 5,724 | 5,984 |
| เงินสำรอง | 10% ปัด | 572 | 598 |
| **รวม** | | **6,296** | **6,582** |
| ต่อคน | ปัดขึ้น | 3,148 | 3,291 |

`Stop.cost`, `NightStay.cost`, `intercity.cost` ใน mock ไม่เปลี่ยนทั้งสองแบบ

---

## 4. เรื่องที่ต้องตัดสินใจ (ผมใส่ค่าเริ่มต้นไว้ จะใช้ตามนี้ถ้าไม่แก้)

| # | เรื่อง | ค่าเริ่มต้น | ผลถ้าเลือกอีกทาง |
|---|---|---|---|
| D1 | กฎชุดไหน | กฎที่อนุมัติ 4 ต.ค. | ใช้กฎตาม issue: mock ไม่ต้องแก้ ไม่มีเที่ยวกลับที่พัก |
| D2 | ทศนิยม | คง `int` ปัดตามข้อ 2 | ใช้ `double`: ต้องแก้ `lib/domain` + แจ้งกลุ่ม |
| D3 | provider | `costCalculatorProvider` และ `pipelinePlannerServiceProvider` เป็น `FutureProvider` | แก้ `DefaultPlannerService` ให้รับ `loadCostCalculator` (แตะ class + test ของ @Kritternai) |
| D4 | ไม่มีข้อมูลที่พักแต่มีคืน | คิด `roomFor(CandidateBuilder.priceCap(request)) × ⌈n/2⌉` ต่อคืน รวมใน `cost.accommodation` ไม่มีป้าย "ประมาณการ" | คิด 0 ตามข้อมูล (ขัดกับกฎที่อนุมัติ) |
| D5 | มื้อเช้า | มื้อที่ต้องจ่าย = `days` − จำนวนคืนที่ที่พัก `breakfastIncluded` (เช้าวันแรกจ่ายเสมอ; ทริป 1 วันจ่าย 1 มื้อ) | ตาม issue: ที่พักไม่รวม → `days` มื้อ, รวม → 0 |
| D6 | ค่าทางด่วนขับเอง | `toll × 2` (DATA.md: "ต่อคันต่อเที่ยว") คิดรถ 1 คัน | §9 เขียน "เหมาจ่าย" อาจหมายถึงครั้งเดียว |
| D7 | ค่าเข้าชมไม่ทราบ | ยังถือเป็น 0 เพราะ `Place.entranceFee` แยก "ฟรี" กับ "ไม่ทราบ" ไม่ได้ เขียนเป็นข้อจำกัดใน PR | ต้องแก้ domain + data ร่วมกับ @Nirapada-p |

**D3 ขยาย:** ตอนนี้ไม่มีโค้ดส่วนไหนอ่าน `pipelinePlannerServiceProvider` เลย (`generating_screen` ยังใช้ `plannerServiceProvider` ที่เป็น mock) การเปลี่ยนเป็น `FutureProvider` จึงไม่กระทบใครใน PR นี้ แต่คนที่สลับ `plannerServiceProvider` ไปใช้ pipeline จริงหลัง #37 จะต้องรองรับ async ควรแจ้ง @Kritternai ใน PR

---

## 5. ผลกระทบกับไฟล์ของคนอื่น

1. **`test/domain/json_round_trip_test.dart:50`** — `expect(stopCosts, cost.food + cost.entrance)`
   มื้อเช้าเป็นค่าอาหารที่ไม่อยู่ใน Stop ใด ถ้า D1/D5 ตามค่าเริ่มต้น mock จะมีมื้อเช้า 200 และบรรทัดนี้จะ fail
   ต้องแก้เป็นเทียบกับ `cost.food + cost.entrance − มื้อเช้า` หรือย้ายการตรวจนี้ไปไว้ใน test ของ calculator
   ไฟล์นี้เป็นของ #12 (@Kritternai) — ต้องบอกใน PR
2. **`assets/mock/trip_plan_chonburi_2d.json`** — แก้ 5 ช่องใน `cost` (food, localTransport, buffer, total, perPerson) หน้า Trip Plan จะแสดง ฿6,582 / ฿7,000 แทน ฿6,296
3. **`lib/app/providers/planner_providers.dart`** — ตาม D3
4. `test/planner/default_planner_service_test.dart` ใช้ `_FlatCost` ของตัวเอง ไม่กระทบ

---

## 6. ลำดับ commit

แต่ละ commit ต้อง `flutter analyze` + `flutter test` ผ่าน

1. `feat(planner): calculate accommodation and food cost (#34)`
   สร้าง class, เติม `NightStay.cost` และ `Stop.cost` ของร้านอาหาร, มื้อเช้า, D4
2. `feat(planner): calculate entrance and local transport cost (#34)`
   `Stop.cost` ของ attraction, นับเที่ยว/ระยะ, เที่ยวกลับที่พัก
3. `feat(planner): calculate intercity cost with same-province rule (#34)`
   `IntercityLeg.cost`, `plan.intercity == null` → 0
4. `feat(planner): add buffer, totals and budget status (#34)`
   ปัดเศษ, `CostEstimate`, `status`, ต่อ provider (D3)
5. `test(planner): cover cost calculator per category (#34)`
6. `fix(mock): align mock plan costs with the calculator (#34)` (เพิ่มจาก issue — เฉพาะเมื่อ D1 = กฎที่อนุมัติ)
   แก้ mock + `json_round_trip_test.dart`

---

## 7. แผน test (`test/planner/cost_calculator_test.dart`)

ใช้ catalog ที่สร้างเองใน test (จังหวัด 2 แห่ง, ที่พัก 2 ระดับ, ร้าน 2 ระดับ, attraction มี/ไม่มีค่าเข้า) เพื่อไม่ผูกกับข้อมูลจริงที่ #20–#22 จะแก้ ยกเว้น test เทียบ mock ที่ต้องใช้ `sampleCatalog()`

| กลุ่ม | กรณี | AC |
|---|---|---|
| ที่พัก | คน 1/2/3/5 → ห้อง 1/1/2/3; หลายคืน; ทริป 1 วัน = 0 | 1, 3 |
| อาหาร | ร้านแต่ละ Price Level × คน; มื้อเช้าตาม D5 (ที่พักรวม/ไม่รวม, 1 วัน, 3 วัน) | 1 |
| ค่าเข้าชม | มีค่าเข้า × คน; ไม่มี = 0 | 1 |
| ในพื้นที่ | 4 โหมด × คน 1/2/3/5 (จำนวนคัน: รถ 1/1/1/2, มอเตอร์ไซค์ 1/1/2/3, แท็กซี่ 1/1/1/2, สาธารณะ = คน) | 1 |
| ในพื้นที่ | เที่ยวกลับที่พักนับทุกคืน; ทริป 1 วันนับกลับจุดเริ่ม; วันสุดท้ายไม่นับ; รถเช่าคิดทุกวัน | กฎอนุมัติ |
| ข้ามเมือง | รถทัวร์/รถไฟ × คน × 2; ขับเอง; **กทม→กทม = 0** | 2 |
| รวม | เงินสำรอง 10%, `5 หมวด + buffer == total`, ต่อคนปัดขึ้น, `ok`/`overBudget` ที่ขอบ (`total == budget` ยัง ok) | 1 |
| ความถูกต้อง | Σ `Stop.cost` + มื้อเช้า == food + entrance; Σ `NightStay.cost` == accommodation (เมื่อมีข้อมูลที่พัก); เรียกซ้ำได้ผลเดิม | — |
| mock | `applyCosts(mock request, mock plan ที่ล้าง cost, sampleCatalog)` == `cost` ใน mock ทุกช่อง | 4 |

---

## 8. ความเสี่ยง

- **ข้อมูลสถานที่จะเปลี่ยน** (#20–#22 ยังเปิด) — ถ้า @Nirapada-p แก้ `priceLevel` ของสถานที่ใน mock test เทียบ mock จะ fail ซึ่งเป็นสิ่งที่ AC ข้อ 4 ต้องการ แต่ควรบอกเขาไว้
- **โหมดข้ามเมืองที่ไม่มีข้อมูล** — pipeline ถอยไปใช้ตัวเลือกแรกโดยคง `mode` เดิมไว้ calculator จะถอยแบบเดียวกันเพื่อไม่ให้ throw กลางทาง
- **#33 ยังไม่ได้ตรวจราคาจริง** — ถ้าแก้ `pricing.json` ทีหลัง test ที่ผูกเลขกับไฟล์จริงมีแค่ test เทียบ mock; test อื่นใช้ `PricingTable` ที่สร้างใน test

## 9. หลัง merge

- แจ้ง @Kritternai: pipeline จริงเหลือรอแค่ #37 และ provider เป็น async (D3)
- #35 ต่อบนไฟล์เดียวกัน (`minimumTripCost`)
- #37 เริ่มได้
