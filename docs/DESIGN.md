# กติกาการออกแบบ: Material 3 เท่านั้น

> แหล่งอ้างอิงเดียวที่ใช้คือ **https://m3.material.io/** ทุกหน้าจอต้องใช้ component, token และ layout ของ Material 3 ทั้งบน Android และ iOS **ห้ามใช้ Cupertino widget** และห้ามสร้าง component เองถ้า M3 มีให้ใช้อยู่แล้ว
>
> **Import:** ใช้ `import 'package:material_ui/material_ui.dart';` เท่านั้น ห้ามใช้ `package:flutter/material.dart` และ `package:flutter/cupertino.dart` เพราะตั้งแต่ Flutter 3.44 Material แยกออกมาเป็นแพ็กเกจ [`material_ui`](https://pub.dev/packages/material_ui) แล้ว และแพ็กเกจที่เราใช้ (`go_router`, `dynamic_color`) ก็ใช้ตัวนี้ ถ้าปนกันจะได้ `ThemeData`/`ColorScheme` คนละ type ส่วน widget พื้นฐานที่ไม่ใช่ Material ให้ import `package:flutter/widgets.dart`
>
> ถ้าแพ็กเกจภายนอกตัวไหนยังใช้ `flutter/material.dart` อยู่ ให้ครอบเฉพาะ widget นั้นด้วย `MaterialUiCompatibilityBridge` แล้วแจ้งทีม
>
> โค้ดที่ตั้งค่าไว้แล้ว:
> - theme: `lib/app/theme/`
> - window size class: `lib/app/layout/window_size_class.dart`
> - navigation ที่ปรับตามขนาดจอ: `lib/app/layout/adaptive_shell.dart`

---

## 1. สี (Color)

- ใช้สีจาก `Theme.of(context).colorScheme` เท่านั้น เช่น `primary`, `onPrimary`, `primaryContainer`, `surfaceContainerHigh`, `error` และ `outlineVariant`
- **ห้ามใช้ `Colors.xxx` หรือ `Color(0x...)` ในหน้าจอ** สีแบรนด์มีที่เดียวคือ seed color ใน `lib/app/theme/app_theme.dart`
- **Dynamic color:** Android 12 ขึ้นไปใช้สีจาก wallpaper ผ่าน `dynamic_color` ส่วน Android รุ่นเก่าและ iOS ใช้สีจาก seed
- **Light + Dark:** ทุกหน้าต้องดูในทั้งสองโหมดก่อนเปิด PR ถ้ามีข้อความวางบนพื้นสี ต้องใช้คู่ `on*` เช่น `onPrimaryContainer` บน `primaryContainer`
- สีสถานะ:
  - **Over Budget:** `errorContainer` / `onErrorContainer`
  - **อยู่ในงบ:** `tertiaryContainer` / `onTertiaryContainer`

## 2. ตัวอักษร (Typography)

- ใช้ `Theme.of(context).textTheme` เท่านั้น ตาม [M3 type scale](https://m3.material.io/styles/typography/type-scale-tokens): `displaySmall`, `headlineMedium`, `titleLarge`, `titleMedium`, `bodyLarge`, `bodyMedium`, `labelLarge` และอื่น ๆ
- **ห้ามกำหนด `fontSize` เอง** ถ้าต้องการเปลี่ยนน้ำหนักตัวอักษร ให้ใช้ `.copyWith(fontWeight: ...)` เท่านั้น
- ฟอนต์ภาษาไทยคือ **Noto Sans Thai** ซึ่ง bundle ไว้ใน `assets/fonts/` แล้ว (ตั้งเป็น fallback ของฟอนต์ระบบ)
- ตัวเลขเงินให้ใช้ `NumberFormat` ของ `intl` จัดรูปแบบเป็น "฿12,000"

## 3. Layout และขนาดจอ (Window size classes)

| Class | ความกว้าง | Navigation | Layout ที่ต้องรองรับ |
|---|---|---|---|
| **Compact** | < 600dp | `NavigationBar` ด้านล่าง | 1 คอลัมน์ |
| **Medium** | 600–839dp | `NavigationRail` | 1 คอลัมน์ที่จำกัดความกว้าง หรือ 2 pane ถ้าเนื้อหาเหมาะ |
| **Expanded** | 840–1199dp | `NavigationRail` | **2 pane** เช่น หน้า Trip Plan แสดงไทม์ไลน์ + แผนที่คู่กัน |
| **Large / Extra-large** | ≥ 1200dp | `NavigationRail` แบบ extended | 2 pane ที่จำกัดความกว้างสูงสุด |

- อ่าน class ได้จาก `context.windowSizeClass` แต่ห้ามเขียนเงื่อนไข `MediaQuery.of(context).size.width > ...` เอง
- ระยะห่างใช้ grid 4dp ได้แก่ 4, 8, 12, 16, 24, 32 และ margin ของหน้าจอเป็น 16dp บน compact, 24dp บน medium ขึ้นไป
- ฟอร์มและรายการบนจอใหญ่ต้องจำกัดความกว้างไม่เกิน 840dp (`ConstrainedBox`) ไม่ให้ยืดเต็มจอ
- ทดสอบทั้งแนวตั้งและแนวนอน รวมทั้งเครื่องพับได้ (medium)

## 4. Component ที่ใช้ในโปรเจกต์ (ใช้ตามนี้ก่อนคิดสร้างเอง)

| สิ่งที่ต้องการ | M3 component (Flutter) |
|---|---|
| ปุ่มหลักของหน้า | `FilledButton` · ปุ่มรอง `FilledButton.tonal` / `OutlinedButton` · ปุ่มเล็ก `TextButton` |
| ปุ่มลอยหลัก | `FloatingActionButton.extended` |
| เลือก 1 จากไม่กี่ตัวเลือก (Pace, วิธีเดินทาง) | `SegmentedButton` |
| เลือกหลายแท็ก (Preference Tags) | `FilterChip` ใน `Wrap` |
| ช่วงวันที่ | `showDateRangePicker` |
| จำนวนตัวเลข / งบ | `TextField` + `InputDecoration` (outlined) และ `keyboardType: number` |
| Dropdown (Origin / จังหวัด) | `DropdownMenu` |
| ฟอร์มหลายขั้น | `Stepper` ไม่ได้อยู่ใน M3 ให้ใช้ `LinearProgressIndicator` + หน้าแยกตามขั้น และปุ่ม "ถัดไป" / "ย้อนกลับ" |
| การ์ดข้อมูล | `Card.filled` / `Card.outlined` / `Card` (elevated) |
| แท็บเลือกวัน | `TabBar` (primary tabs) หรือ `SegmentedButton` ถ้าน้อยกว่า 4 วัน |
| รายการ | `ListTile` ใน `ListView` |
| รายละเอียดเพิ่มเติม | `showModalBottomSheet` (ใช้ `showDragHandle: true`) |
| ยืนยัน / แจ้งเตือนสำคัญ | `AlertDialog` · แจ้งสั้น ๆ ใช้ `SnackBar` (มี action "เลิกทำ" ได้) |
| สถานะกำลังโหลด | `CircularProgressIndicator` / `LinearProgressIndicator` |
| หัวหน้า | `SliverAppBar.medium` / `SliverAppBar.large` หรือ `AppBar` |
| Badge / ตัวเลข | `Badge` |
| ไอคอน | `Icons.*` ใช้ชุดเดียวกันทั้งแอป (แนะนำแบบ outlined สำหรับสถานะปกติ) |

## 5. Accessibility (ต้องผ่านก่อน merge)

- พื้นที่กดไม่น้อยกว่า **48×48dp**
- ตัวอักษรขยายถึง **200%** แล้วต้องไม่ล้นหรือถูกตัด (ทดสอบด้วย Settings → Font size หรือ `MediaQuery.textScalerOf`)
- ปุ่มที่มีแต่ไอคอนต้องมี `tooltip` หรือ `Semantics(label: ...)`
- ห้ามสื่อความหมายด้วยสีอย่างเดียว เช่น สถานะ Over Budget ต้องมีไอคอนและข้อความด้วย
- หมุดบนแผนที่ต้องมี label ลำดับเลขให้ screen reader อ่านได้

## 6. ภาษาและข้อความ

- ข้อความในแอปเป็น**ภาษาไทยทั้งหมด** และใช้คำตาม [CONTEXT.md](../CONTEXT.md) เช่น "แผนการเดินทาง" ไม่ใช้ "Itinerary"
- ราคาทุกจุดต้องมีป้าย "ราคาโดยประมาณ"
- ทุกหน้าต้องมี **empty state** และ **error state** ที่บอกว่าเกิดอะไรขึ้นและผู้ใช้ทำอะไรต่อได้

## 7. Checklist ก่อนเปิด PR ที่มี UI

- [ ] import `package:material_ui/material_ui.dart` เท่านั้น (`grep -rn "flutter/material.dart\|flutter/cupertino.dart" lib` ต้องไม่เจอ)
- [ ] ใช้สีและตัวอักษรจาก theme ทั้งหมด (`grep -n "Colors\.\|fontSize" <ไฟล์ที่แก้>` ต้องไม่เจอ)
- [ ] ตรวจครบทั้ง Light และ Dark
- [ ] ตรวจครบทั้ง Compact (มือถือ) และ Expanded (แท็บเล็ตแนวนอน / หน้าต่างกว้าง)
- [ ] ขยายตัวอักษร 200% แล้วไม่ล้น
- [ ] แนบภาพหน้าจออย่างน้อย 2 ภาพใน PR: compact light และ expanded dark
