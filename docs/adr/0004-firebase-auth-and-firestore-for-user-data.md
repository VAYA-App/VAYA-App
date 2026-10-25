# ใช้ Firebase Auth และ Firestore เก็บข้อมูลของผู้ใช้แทน Hive

ผู้ใช้เข้าสู่ระบบด้วย Google ผ่าน Firebase Auth และ Saved Trip ของแต่ละคนเก็บใน Firestore ที่ `users/{uid}/trips` โดยเปิด offline persistence ไว้ ส่วนข้อมูล Province และ Place ยังอยู่ในแอปตาม ADR 0002 ที่เราเลิกใช้ Hive ก็เพราะ Hive เก็บได้แค่ในเครื่อง ข้อมูลไม่แยกตามผู้ใช้ ย้ายเครื่องแล้วทริปหาย และ login แบบ mock ทำให้แอปยังเป็น demo อยู่ ส่วน Firestore ใช้ได้ทั้งตอนออฟไลน์และหลายเครื่อง และ `firestore.rules` ก็มีอยู่แล้ว

## Considered Options

- คงใช้ Hive แต่แยก box ตาม uid: ตัดทิ้งเพราะข้อมูลยังอยู่แค่เครื่องเดียว
- เก็บทุกอย่างในเครื่อง ไม่มีบัญชี: ตัดทิ้งเพราะต้องมี login และบันทึกทริปข้ามเครื่องได้

## Consequences

- ต้องมี Firebase project และไฟล์ config ของแต่ละ platform จาก `flutterfire configure`
- ถ้าจะส่ง App Store ต้องเพิ่ม Sign in with Apple ด้วย (App Store Review Guideline 4.8)
