---
status: accepted (แทนส่วนเส้นทางและ tile ของ ADR 0003)
---

# ใช้ OpenRouteService หาเส้นทาง และ MapTiler เป็น tile ของแผนที่

แผนที่ยังวาดด้วย `flutter_map` ตาม ADR 0003 แต่เปลี่ยน tile เป็น MapTiler และขอรูปทรงถนนจาก OpenRouteService แทนเซิร์ฟเวอร์สาธิตของ OSRM key ของทั้งสองเจ้าอ่านจาก `env.json` ผ่าน `--dart-define-from-file` แบบเดียวกับ Gemini ที่เปลี่ยนเพราะเซิร์ฟเวอร์สาธิตของ OSRM ห้ามใช้งานจริงและจำกัดไว้ราว 1 ครั้งต่อวินาที ส่วน tile ของ openstreetmap.org มี usage policy ที่ไม่ให้แอปใช้ในปริมาณมาก ขณะที่ ORS กับ MapTiler มี free tier ที่ไม่ต้องผูกบัตร ถ้าไม่ได้ใส่ key แอปจะกลับไปใช้ OSM/OSRM เดิม เพื่อให้ build สำหรับพัฒนาได้โดยไม่ต้องมี key

## Considered Options

- ตั้งเซิร์ฟเวอร์ OSRM และ tile server เอง: ตัดทิ้งเพราะต้องมีเครื่องและต้องดูแลเอง
- Google Maps Platform: ตัดทิ้งด้วยเหตุผลเดิมใน ADR 0003 (ต้องผูกบัตรเครดิต)

## หมายเหตุ (#182)

ระหว่างที่ยังไม่มี key ของ MapTiler แผนที่ใช้ tile ของ CARTO (Voyager สำหรับโหมดสว่าง, Dark Matter สำหรับโหมดมืด) ซึ่งไม่ต้องใช้ key แต่ต้องแสดงเครดิต "© OpenStreetMap © CARTO" ไว้บนแผนที่ พอได้ key ของ MapTiler แล้ว ให้เปลี่ยน `urlTemplate` ใน `lib/features/trip_plan/widgets/trip_map.dart` ไปใช้ MapTiler ตาม ADR นี้
