# การทดสอบ

| ชนิด | อยู่ที่ | ทดสอบอะไร | รันอย่างไร | CI |
|---|---|---|---|---|
| Unit | `test/domain/`, `test/planner/`, `test/data/`, `test/ai/`, `test/assets/` | กติกาโดเมน, pipeline (ตัวกรองจังหวัด, จัดอันดับ, เลือกสถานที่, จัดเส้นทาง, คำนวณค่าใช้จ่าย, เกินงบ), ข้อมูลจังหวัดและสถานที่, Hive, OSRM, Open-Meteo, Gemini REST | `flutter test` | ✅ |
| Widget | `test/features/`, `test/shared/`, `test/app/`, `test/_preview/` | ทุกหน้าจอ: สถานะ loading/error/empty, การกด, ขนาดจอ compact/expanded, ตัวอักษร 200%, light/dark, การปิดแอนิเมชัน | `flutter test` | ✅ |
| Demo scenarios | `test/planner/demo_scenarios_test.dart` | 3 สถานการณ์ demo ผ่าน pipeline จริงกับข้อมูลจริง | `flutter test test/planner/demo_scenarios_test.dart` | ✅ |
| Integration | `integration_test/trip_flow_test.dart` | แอปจริงบนเครื่อง: เข้าสู่ระบบ → ฟอร์ม → แนะนำจังหวัด → สร้างแผน → บันทึก → เปิดซ้ำ → ลบ | `flutter test integration_test -d <device>` | ✅ (Android emulator) |
| Security | `firestore/trips.rules.test.js` | Firestore rules: เจ้าของเท่านั้นที่อ่าน/แก้/ลบได้, ตรวจรูปแบบข้อมูล, ห้ามยึดทริปคนอื่น, คอลเลกชันอื่นปิด | `cd firestore && npm ci && npm run test:emulator` | ✅ |
| Security (แอป) | `test/app/auth_guard_test.dart`, `test/ai/rest_gemini_service_test.dart` | ยังไม่เข้าสู่ระบบถูกพาไปหน้า login, API key ส่งใน header ไม่อยู่ใน URL | `flutter test` | ✅ |
| Usability | `docs/USABILITY-TEST.md` | ผู้ใช้จริง 5 คน 6 งาน + SUS | ทดสอบกับผู้ใช้ | – |

## Code coverage

```bash
flutter test --coverage
dart run tool/check_coverage.dart 70
```

CI รวม coverage ของ unit และ widget test แล้วล้มถ้า line coverage ของ `lib/` ต่ำกว่า 70% ตัวเลขนับเฉพาะไฟล์ที่ test โหลด ไฟล์อย่าง `lib/main.dart` ที่ test ไม่ได้ import จึงไม่ถูกนับ

## GitHub Actions

`.github/workflows/ci.yml` รันทุก PR เข้า `main` และทุก commit บน `main` เป็นขั้น ๆ ขั้นถัดไปเริ่มเมื่อขั้นก่อนผ่าน ดูเป็นแผนภาพได้ในหน้า run ของแท็บ Actions

```
1 Lint ─┬─ 2 Unit ────────┬─ 3 Coverage ≥ 70% ─┬─ 4 Build web
        ├─ 2 Widget ──────┘                    └─ 4 Build android
        ├─ 2 Integration (Android emulator) ───┘
        └─ 2 Security (Firestore rules) ───────┘
```

1. **Lint**: `dart format` (ตรวจอย่างเดียว) และ `flutter analyze`
2. **Test** 4 ชนิดรันพร้อมกัน: unit, widget, integration บน Android emulator และ Firestore security rules บน emulator
3. **Coverage**: รวม lcov ของ unit และ widget แล้วตรวจว่าไม่ต่ำกว่า 70%
4. **Build**: `flutter build web` และ `flutter build apk --debug` (โหลด APK ได้จาก artifact `vaya-debug-apk`)

ทุก job ใช้ขั้นเตรียม Flutter ร่วมกันที่ `.github/actions/setup-flutter`
