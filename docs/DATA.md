# ข้อมูลจังหวัดและสถานที่ (`assets/data/`)

ข้อมูลทั้งหมดเป็นไฟล์ JSON ที่รวมไปกับแอปตอน build ([ADR-0002](./adr/0002-bundle-place-data-as-assets.md)) โหลดครั้งเดียวผ่าน `loadPlaceCatalog()` ใน `lib/data/asset_place_catalog.dart` แล้วใช้งานผ่าน `PlaceCatalog` (`placeCatalogProvider`) เจ้าของข้อมูลคือ @Nirapada-p (#20 #21 #22) ส่วนราคากลางอยู่ที่ `pricing.json` ซึ่งเป็นของ @tp-job (#33)

```
assets/data/
  provinces.json          # รายชื่อจังหวัดที่รองรับ
  places/<provinceId>.json  # สถานที่ของแต่ละจังหวัด (1 ไฟล์ต่อจังหวัด)
  pricing.json            # ตารางราคา (#33)
assets/mock/               # ข้อมูลจำลองให้ทำ UI ก่อน pipeline เสร็จ
```

## เพิ่มจังหวัดใหม่ (ไม่ต้องแก้โค้ด)
1. เพิ่ม object ใน `provinces.json` และเพิ่มค่าเดินทางใน `intercity` ของจังหวัดต้นทางทุกจังหวัดที่เกี่ยวข้องทั้งสองทิศ
2. สร้าง `places/<id>.json`
3. รัน `flutter test` (เทสต์ตรวจความถูกต้องของข้อมูล)

## `provinces.json`

```jsonc
{
  "provinces": [
    {
      "id": "chonburi",                 // kebab-case ภาษาอังกฤษ ใช้เป็นชื่อไฟล์ places ด้วย
      "name": "ชลบุรี",
      "center": { "lat": 13.0827, "lng": 100.9192 },
      "regionTag": "east",
      "tags": ["beach", "seafood"],     // PreferenceTag เด่นของจังหวัด ใช้ตอนจัดอันดับ (#25)
      "seasonality": ["good", "good", "good", "good", "ok", "ok", "ok", "ok", "ok", "ok", "good", "good"], // ม.ค.–ธ.ค.: good | ok | avoid
      "seasonNote": "ข้อความภาษาไทย",
      "intercity": {                    // key = id ของจังหวัดต้นทาง (Origin) ถ้าต้นทาง = ปลายทาง ไม่ต้องใส่
        "bangkok": {
          "bus":   { "durationMin": 150, "farePerPerson": 131 },
          "train": { "durationMin": 240, "farePerPerson": 31 },
          "car":   { "durationMin": 120, "distanceKm": 150, "toll": 120 } // toll = ค่าทางด่วนต่อคันต่อเที่ยว
        }
      }
    }
  ]
}
```

## `places/<provinceId>.json`

```jsonc
{
  "places": [
    {
      "id": "chonburi-attraction-sanctuary-of-truth", // <provinceId>-<category>-<slug> ห้ามซ้ำ และห้ามเปลี่ยนหลังใช้งานแล้ว
      "category": "attraction",        // attraction | restaurant | accommodation
      "name": "ปราสาทสัจธรรม",
      "area": "นาเกลือ",                // ย่าน (ไม่บังคับ)
      "location": { "lat": 12.9727, "lng": 100.889 }, // คัดลอกจาก Google Maps (คลิกขวาที่หมุด)
      "tags": ["artCulture", "viewpoint"],
      "priceLevel": 2,                 // 1–4 = ฿ ถึง ฿฿฿฿
      "rating": 4.6,                   // ไม่บังคับ
      "openingHours": {                // ไม่บังคับ ถ้าไม่ใส่ ระบบใช้ 09:00–17:00 แล้วแสดงคำเตือน
        "mon": ["08:00", "18:00"],     // วันที่ไม่มีใน object = ปิดวันนั้น
        "sat": ["08:00", "18:00"]
      },
      "dwellMinutes": 120,             // attraction/restaurant: เวลาที่อยู่โดยเฉลี่ย
      "entranceFee": 500,              // attraction: บาทต่อคน (ถ้าเข้าฟรีไม่ต้องใส่)
      "shortDescription": "ภาษาไทยไม่เกิน 120 ตัวอักษร ใช้ทั้งในแอปและใน prompt",
      "breakfastIncluded": true        // accommodation เท่านั้น (ไม่ใส่ = false)
    }
  ]
}
```

`provinceId` ไม่ต้องใส่ในแต่ละ place เพราะตัวโหลดเติมให้จากชื่อไฟล์

### PreferenceTag ที่ใช้ได้

| ค่า | ป้ายในแอป | ค่า | ป้ายในแอป |
|---|---|---|---|
| `nature` | ธรรมชาติ | `seafood` | ซีฟู้ด |
| `beach` | ทะเล | `shopping` | ช้อปปิ้ง |
| `cafe` | คาเฟ่ | `nightlife` | ไนท์ไลฟ์ |
| `templeHistory` | วัด/ประวัติศาสตร์ | `viewpoint` | จุดชมวิว |
| `artCulture` | ศิลปะ/วัฒนธรรม | `family` | ครอบครัว |
| `localFood` | อาหารท้องถิ่น | `wellness` | สปา/ผ่อนคลาย |
| | | `adventure` | กิจกรรมผจญภัย |

ถ้าจะเพิ่มแท็ก ต้องแก้ `PreferenceTag` ใน `lib/domain/enums.dart` (ขอรีวิวจาก @Kritternai)

## ข้อมูลจำลอง (`assets/mock/`)

| ไฟล์ | ใช้ทำอะไร |
|---|---|
| `trip_request_demo.json` | TripRequest ตัวอย่าง: กทม→ชลบุรี 2 วัน 2 คน |
| `trip_plan_chonburi_2d.json` | TripPlan ที่ครบทุกฟิลด์ ใช้ทำหน้า Trip Plan (#36 #38 #39 #40) ก่อน pipeline (#31) เสร็จ |

อ่านใน UI ผ่าน `mockTripPlanProvider` / `mockTripRequestProvider` และเมื่อของจริงเสร็จให้เปลี่ยนไปใช้ provider จริง
