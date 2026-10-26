# #38 Over-budget banner and advice UI — แผนพัฒนา

Branch: `feat/38-over-budget-ui` (แตกจาก `main` ที่ 8469d4d ซึ่งมี #36 และ #37 แล้ว)
PR: `feat(trip-plan): show over-budget banner and advice (#38)` · ประมาณ 1.5 วัน
จัดทำ 9 ต.ค. 2026 · ไฟล์นี้ไม่ commit

---

## 1. สถานะจริงของหน้าจอ

- หน้า Trip Plan มีป้าย `_BudgetBadge` ("อยู่ในงบ" / "เกินงบ ฿x") ในการ์ดสรุปอยู่แล้ว (#70) และ `CostSummaryCard` ที่ยอดรวมกับแถบเป็นสีแดงเมื่อเกินงบ (#36)
- ยังไม่มี banner, ไม่มีที่แสดง `TripPlan.overBudgetAdvice`, ไม่มีที่แสดง `BudgetRescue`
- แอปยังใช้ `MockPlannerService` และ mock plan อยู่ในงบเสมอ **ตอนนี้จึงไม่มีทางเห็นหน้าเกินงบในแอปเลย** จนกว่า #31 จะสลับ pipeline
- หน้า Trip Plan ยังไม่มีมาสคอต จึงใส่ได้ 1 ตัวตามกติกา "หน้าละ 1 ตัว"

## 2. สิ่งที่จะสร้าง

### `OverBudgetBanner` — `widgets/over_budget_banner.dart`
รับ `CostEstimate`

| | เกินงบจริง | เกินเพราะเงินสำรอง (ค่าใช้จ่ายจริง ≤ งบ < ยอดรวม) |
|---|---|---|
| พื้น / ตัวอักษร | `errorContainer` / `onErrorContainer` | `tertiaryContainer` / `onTertiaryContainer` |
| ไอคอน | `Icons.warning_amber_outlined` | `Icons.info_outline` |
| หัวข้อ | เกินงบ ฿2,916 | เกินงบ ฿382 เพราะเงินสำรอง |
| เนื้อหา | ยังแสดงแผนให้ครบ ดูวิธีลดค่าใช้จ่ายด้านล่าง | ค่าใช้จ่ายจริง ฿5,984 ไม่เกินงบ ส่วนที่เกินมาจากเงินสำรอง ฿598 |

- `Card.filled` + ไอคอน + ข้อความ จึงไม่สื่อด้วยสีอย่างเดียว และ screen reader อ่าน "เกินงบ ฿x" จากหัวข้อ
- มาสคอต `MascotView(pose: MascotPose.budget, size: 76)` ชิดขวา ซ่อนเมื่อขยายตัวอักษรถึง 150% (เกณฑ์เดียวกับหน้า Home และฟอร์ม) ใช้ท่า `budget` ไปก่อนจนกว่า #86 จะมีท่า `worried`

### `BudgetAdviceList` — `widgets/budget_advice_list.dart`
รับ `List<BudgetAdvice>` · หัวข้อ "วิธีลดค่าใช้จ่าย" แล้ว `Card.outlined` + `ListTile` ต่อข้อ

| Kind | ไอคอนนำ |
|---|---|
| `downgradeAccommodation` | `bed_outlined` |
| `changeLocalTransport` | `commute_outlined` |
| `removeDay` | `event_busy_outlined` |
| `changeDestination` | `map_outlined` |

ข้อความใช้ `advice.description` ตรง ๆ (มียอดประหยัดอยู่แล้ว) ท้ายรายการเขียน "แต่ละวิธีคิดแยกกัน ยอดประหยัดนำมารวมกันไม่ได้ · ราคาโดยประมาณ"

### `BudgetRescueCard` — ในไฟล์เดียวกับรายการคำแนะนำ
รับ `BudgetRescue` + จำนวนวันของทริป พื้น `tertiaryContainer`
- "ทำทุกวิธีแล้วยังเกินงบอีก ฿7,789"
- "ควรมีงบอย่างน้อย ฿6,100 สำหรับทริป 3 วัน"
- "หรือลดเหลือ 1 วัน ซึ่งเริ่มต้น ~฿1,197 อยู่ในงบ" / ถ้าไม่มี: "งบนี้ยังไม่พอแม้เป็นทริป 1 วัน"

### การต่อข้อมูล
- `budgetRescueProvider(tripId)` ใน `trip_plan_view_provider.dart`: อ่านแผนจาก `tripPlanViewProvider` แล้วเรียก `DefaultOverBudgetAdvisor.rescue` คืน `null` เมื่อแผนไม่เกินงบ
- `planner_providers.dart`: เพิ่ม provider ที่คืน `DefaultOverBudgetAdvisor` ตรง ๆ ให้ `overBudgetAdvisorProvider` กับ `budgetRescueProvider` ใช้ร่วมกัน (interface `OverBudgetAdvisor` ไม่มี `rescue`)

### `trip_plan_screen.dart`
เมื่อ `plan.cost.isOverBudget` ทั้ง layout compact และ expanded:
1. banner **เหนือ** การ์ดสรุป
2. การ์ดสรุป (เดิม)
3. รายการคำแนะนำ (ถ้ามี) → การ์ด rescue (ถ้ามี)
4. ส่วนที่เหลือเหมือนเดิม

## 3. เรื่องที่ต้องตัดสินใจ (ใส่ค่าเริ่มต้นไว้)

| # | เรื่อง | ค่าเริ่มต้น | อีกทาง |
|---|---|---|---|
| D1 | จะเห็นหน้าเกินงบในแอปอย่างไร | เพิ่ม trip id `mock-over-budget`: เอา mock plan มาคิดราคาใหม่ด้วยเครื่องคิดเลขและ advisor จริง โดยตั้งงบ 1,500 และโหมดแท็กซี่ จะได้ banner + คำแนะนำ 2 ข้อ + การ์ด rescue เปิดที่ `/#/trips/mock-over-budget` | ไม่เพิ่ม: ตรวจได้แค่ใน widget test และจับภาพหน้าจอสำหรับ PR ไม่ได้จนกว่า #31 จะสลับ pipeline |
| D2 | ป้าย "เกินงบ ฿x" เดิมในการ์ดสรุป | คงไว้ (ของ #70) แม้ซ้ำกับ banner | เอาออกเมื่อมี banner: ต้องแก้โค้ดของ @Kritternai เพิ่ม |
| D3 | ตำแหน่ง | banner บนสุด, คำแนะนำใต้การ์ดสรุป (ตาม prototype) | รวมทั้งหมดไว้ในการ์ดสรุป |
| D4 | คำแนะนำกดได้ไหม | แสดงอย่างเดียว | ปุ่ม "ลองใช้" ที่คิดราคาใหม่บนจอแบบ prototype: ต้องมี state และเป็นงานขนาด S1/S2 |
| D5 | มาสคอต | ใส่ใน banner ตามที่ #83 ค้างไว้ | ไม่ใส่ รอ @Kritternai |
| D6 | avatar บนปุ่ม "ให้ AI ปรับแผน" (ค้างจาก #83) | ไม่ทำใน PR นี้: จะเป็นมาสคอตตัวที่สองของหน้า และ issue เขียนว่า "ถ้าเข้ากับ theme" | ทำด้วย |

**D1 ขยาย:** ต้องแก้ `trip_plan_view_provider.dart` ของ @Kritternai ราว 15 บรรทัด ตัวเลขที่จะเห็นมาจากข้อมูลตัวอย่างและเปลี่ยนตาม #20–#22 ผมยังไม่ได้รันกรณีนี้จริง ตัวเลขที่คาด (แผน ~8,900, ลดเหลือ 1 วัน, เปลี่ยนเป็นรถสาธารณะ, ควรมีงบ ~2,000) อนุมานจากการวัด demo 1 ก่อนหน้า

## 4. ผลกระทบกับงานคนอื่น

- **@Kritternai:** `trip_plan_screen.dart` (เพิ่ม ~25 บรรทัด ไม่ลบของเดิม), `trip_plan_view_provider.dart` (D1), มาสคอตใน banner (#83), `planner_providers.dart`
- **PR #107 (login, @gunruethaiz) ยังเปิดและ conflict:** test ที่เปิดหน้า Trip Plan ผ่าน `VayaApp` จะพังเมื่อ merge (#101) test ใหม่ของ #38 จะเปิดหน้าด้วยวิธีเดียวกันจึงโดนด้วย
- **#31:** เมื่อสลับ pipeline แผนที่เกินงบจริงจะแสดง banner และคำแนะนำทันทีโดยไม่ต้องแก้อะไรเพิ่ม

## 5. ลำดับ commit

1. `feat(trip-plan): add over-budget banner (#38)` — widget + มาสคอต
2. `feat(trip-plan): show budget advice cards (#38)` — รายการคำแนะนำ, การ์ด rescue, provider, เสียบเข้าหน้า, id `mock-over-budget`
3. `test(trip-plan): cover over-budget banner and advice (#38)` (เพิ่มจาก issue)

## 6. แผน test (`test/features/trip_plan/over_budget_banner_test.dart`)

| กรณี | ตรวจอะไร | AC |
|---|---|---|
| เกินงบจริง | หัวข้อ "เกินงบ ฿x", ไอคอน warning, เนื้อหา | 1 |
| เกินเพราะเงินสำรอง | ข้อความแบบเบา, ไอคอน info, ตัวเลขค่าใช้จ่ายจริงและเงินสำรอง | — |
| Screen reader | `find.bySemanticsLabel` เจอ "เกินงบ ฿x" และมาสคอตไม่อยู่ใน semantics | 2 |
| มาสคอต | แสดงที่ตัวอักษรปกติ ซ่อนที่ 200% | 4 |
| รายการคำแนะนำ | ครบทุกข้อ ไอคอนตรงชนิด ข้อความตรง `description` มีหมายเหตุห้ามรวมยอด | 1 |
| การ์ด rescue | มี/ไม่มีจำนวนวันที่งบพอ | — |
| 360 ที่ 200% | light และ dark ไม่ล้น | 4 |
| หน้าจริง: `mock-over-budget` | เห็น banner + คำแนะนำ + rescue; `mock` ปกติไม่เห็นทั้งสามอย่าง | 1 |
| `budgetRescueProvider` | คืน null กับ `mock`, คืนค่ากับ `mock-over-budget` | — |

ตรวจด้วยตา: Compact 412 และ Expanded 1280 × Light และ Dark ที่ `/#/trips/mock-over-budget` แล้วเก็บภาพ compact light กับ expanded dark

## 7. ไม่อยู่ใน #38

- ปุ่ม "ลองใช้" คำแนะนำและการคิดราคาใหม่บนจอ
- avatar บนปุ่ม "ให้ AI ปรับแผน"
- สลับแอปไปใช้ pipeline จริง (#31)
- ท่ามาสคอต `worried` (#86)
- บั๊กและงานค้าง #98–#103

## 8. หลัง merge

- M6 ครบ (#37, #38) ปิด Epic #8 ได้เมื่อ DoD ผ่าน: demo 3 แสดง Over Budget พร้อมคำแนะนำที่ตัวเลขถูก ซึ่งต้องรอ #31 สลับ pipeline จึงจะเห็นในแอปจริง
- เหลือของคุณ: #98–#103, ตรวจราคาจริงของ #33, และ #44 (bug bash พฤ. 15 ต.ค.)
