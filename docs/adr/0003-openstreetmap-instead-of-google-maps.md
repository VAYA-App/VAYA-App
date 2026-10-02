# ใช้ OpenStreetMap ผ่าน flutter_map แทน Google Maps

แผนที่ในหน้า Trip Plan ใช้แพ็กเกจ `flutter_map` กับ tile ของ OpenStreetMap หมุดลำดับเลขและเส้นทางเป็น widget ที่วาดเองด้วยสีจาก Material 3 theme และในรอบนี้เส้นทางเป็นเส้นตรงเชื่อมหมุดตามลำดับ Stop ต้องแสดง attribution "© OpenStreetMap contributors" บนแผนที่เสมอตามเงื่อนไขของ OSM

เราเลือกแบบนี้เพราะ Google Maps SDK กับ Routes API ต้องผูกบัตรเครดิตกับ Google Cloud และต้องจัดการ API key ทั้ง Android และ iOS ส่วน `flutter_map` ไม่ต้องใช้ key ไม่มีค่าใช้จ่าย และปรับหน้าตาหมุดให้เข้ากับ M3 ได้ง่ายกว่า ถ้าจะเพิ่มเส้นทางตามถนนจริงภายหลัง ให้เรียก routing service เช่น OSRM แล้ววาด polyline บนแผนที่เดิมได้เลย

## Considered Options

- Google Maps SDK + Routes API ตามแผนเดิม: ตัดทิ้งเพราะต้องผูกบัตรและมีความเสี่ยงเรื่องบิล
- ไม่มีแผนที่ แสดงแค่ไทม์ไลน์: ตัดทิ้งเพราะ M7 กำหนดให้มีแผนที่
