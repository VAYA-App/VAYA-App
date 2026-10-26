# กติกาการออกแบบ: Material 3 เท่านั้น

> **แนวภาพ "Emerald Field Guide":** เขียวทั้งแอป รูปถ่ายสถานที่จริงเป็นจุดเด่น การ์ดสีขาวขอบบางบนพื้นขาวอมเขียว ฟอนต์ Prompt พื้นที่ว่างเยอะ และมีช้างน้อยเป็นเพื่อนร่วมทาง ดู mockup ที่อนุมัติแล้วได้ที่ [VAYA Redesign Mockup](https://claude.ai/artifact/B1aPsqgXEx4tLHbvbZKREz)

> ฐานของทุกหน้าคือ **https://m3.material.io/** ทุกหน้าจอใช้ component, token และ layout ของ Material 3 ทั้งบน Android และ iOS **ห้ามใช้ Cupertino widget** ถ้า M3 มี component ที่ใช้ได้อยู่แล้วให้ใช้ตัวนั้น ส่วนสิ่งที่ M3 ไม่มี เช่น hero ที่มีรูปถ่าย การ์ดที่มีรูป หรือ empty state ที่มีภาพประกอบ ให้ประกอบขึ้นจาก widget ของ M3 (`Card`, `Stack`, `Image`, `InkWell`) โดยยังใช้สีและตัวอักษรจาก theme เท่านั้น ถ้าส่วนไหนใช้ซ้ำหลายหน้า ให้แยกเป็น widget ไว้ใน `lib/shared/widgets/`
>
> **Import:** ใช้ `import 'package:material_ui/material_ui.dart';` เท่านั้น ห้ามใช้ `package:flutter/material.dart` และ `package:flutter/cupertino.dart` เพราะตั้งแต่ Flutter 3.44 Material แยกออกมาเป็นแพ็กเกจ [`material_ui`](https://pub.dev/packages/material_ui) แล้ว และแพ็กเกจที่เราใช้ (เช่น `go_router`) ก็ใช้ตัวนี้ ถ้าปนกันจะได้ `ThemeData`/`ColorScheme` คนละ type ส่วน widget พื้นฐานที่ไม่ใช่ Material ให้ import `package:flutter/widgets.dart`
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
- **สีแบรนด์คงที่ (ไม่ใช้ dynamic color):** ถ้าใช้สีจาก wallpaper จะแทนที่สีมรกตของแบรนด์
- **เขียวอย่างเดียว:** สีเน้นทุก role อยู่ในตระกูลเขียว (`test/app/app_theme_test.dart` ตรวจไว้) มีชุดสีเดียว ไม่มีตัวเลือกชุดสี ยกเว้นสี `error` ที่ยังเป็นแดงเพื่อให้ Over Budget เห็นชัด

| Role | ใช้ทำอะไร | Light | Dark |
|---|---|---|---|
| `primary` | ปุ่มหลัก, เลขลำดับบนไทม์ไลน์/หมุด, ไอคอนเด่น | `#006948` มรกต | `#6FDBA8` |
| `primaryContainer` | พื้นวงกลมตกแต่ง, พื้นของภาพประกอบ | `#9CF2C6` | `#005236` |
| `secondaryContainer` / `onSecondaryContainer` | สถานะที่เลือก (ชิป, segmented, navigation), การ์ดเด่น | `#D5F0E3` / `#0E3B28` | `#2A4A3A` / `#C2EED7` |
| `tertiary` / `tertiaryContainer` | สีเน้นเขียวมะนาว: ยอดต่อคน, อยู่ในงบ, นับถอยหลัง, เกร็ดความรู้ | `#3D6A00` / `#C6F08E` | `#A9D475` / `#2C5000` |
| `surface` | พื้นหลังทั้งแอป | `#F6FBF7` ขาวอมเขียว | `#0E1511` |
| `surfaceContainerLowest` | การ์ด, ช่องกรอก, แถบด้านล่าง | `#FFFFFF` | `#09100C` |
| `surfaceContainerLow` | กล่องรอง เช่น AI note, Draft Plan | `#EEF5F0` | `#161D19` |
| `outlineVariant` | ขอบบาง | `#BFC9C2` | `#3F4944` |
- **Light + Dark:** ทุกหน้าต้องดูในทั้งสองโหมดก่อนเปิด PR ถ้ามีข้อความวางบนพื้นสี ต้องใช้คู่ `on*` เช่น `onPrimaryContainer` บน `primaryContainer`
- สีสถานะ:
  - **Over Budget:** `errorContainer` / `onErrorContainer`
  - **อยู่ในงบ:** `tertiaryContainer` / `onTertiaryContainer`

## 2. ตัวอักษร (Typography)

- ใช้ `Theme.of(context).textTheme` เท่านั้น ตาม [M3 type scale](https://m3.material.io/styles/typography/type-scale-tokens): `displaySmall`, `headlineMedium`, `titleLarge`, `titleMedium`, `bodyLarge`, `bodyMedium`, `labelLarge` และอื่น ๆ
- **ห้ามกำหนด `fontSize` เอง** ถ้าต้องการเปลี่ยนน้ำหนักตัวอักษร ให้ใช้ `.copyWith(fontWeight: ...)` เท่านั้น
- ฟอนต์คือ **Prompt** (มีทั้งไทยและอังกฤษ) bundle ไว้ใน `assets/fonts/` · หัวข้อเป็น SemiBold, เนื้อหาเป็น Light และตั้ง line height สูง เพื่อไม่ให้วรรณยุกต์ชนกัน
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

## 4. รูปทรงที่ตั้งใน theme แล้ว (ไม่ต้องกำหนดเองในหน้าจอ)

| Component | รูปทรง |
|---|---|
| `Card` | มุมโค้ง 20dp, ไม่มีเงา, ขอบบาง `outlineVariant` |
| `FilledButton` / `OutlinedButton` | สูง 52dp, มุมโค้ง 16dp |
| Chip | ทรงแคปซูล ถ้าเลือกแล้วพื้นเป็น `secondaryContainer` |
| `TextField` | พื้นขาว มุมโค้ง 12dp และขอบเป็น primary เมื่อโฟกัส |
| `NavigationBar` | พื้นขาว ปุ่มตรงกลางเป็น "สร้างทริป" (วงกลม primary) |
| Hero ที่มีรูปถ่าย / bottom sheet | มุมโค้ง 28dp (ประกอบเองตามข้อ 6) |

## 5. Component ที่ใช้ในโปรเจกต์ (ใช้ตามนี้ก่อนคิดสร้างเอง)

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

## 6. รูปถ่าย

- รูปของ Place และ Destination อยู่ใน `assets/` เท่านั้น ห้ามใช้รูปจาก URL ภายนอก ([ADR 0006](adr/0006-bundle-place-photos-with-license-manifest.md))
- ครอปเป็นสัดส่วนคงที่ก่อนนำเข้า: การ์ด 4:3 และ hero 16:9 **ไม่รีทัชและไม่ย้อมสี** รูป ความเป็นโทนเขียวมาจาก UI รอบรูป
- ถ้ามีข้อความวางบนรูป ให้ใส่ gradient มืดจากล่างขึ้นบนในโค้ด และใช้ตัวอักษรสีขาว อย่าวางข้อความบนรูปโดยไม่มี gradient
- รูปเดียวกันที่อยู่ทั้งในการ์ดและในหน้าถัดไปให้ห่อด้วย `Hero` เพื่อให้รูปลอยตามไป
- ทุกรูปต้องมี `semanticLabel` เป็นชื่อสถานที่ และต้องมีเครดิตตาม manifest ในหน้า "เครดิตภาพ"

## 7. Motion และ haptics

ใช้ helper ใน `lib/shared/widgets/motion.dart` ซึ่งแสดงผลลัพธ์สุดท้ายทันทีเมื่อผู้ใช้ปิดอนิเมชันในเครื่อง (`MediaQuery.disableAnimationsOf`) ห้ามเขียน `AnimationController` เองในหน้าจอถ้ามี helper ที่ใช้ได้

| สิ่งที่ต้องการ | ใช้ | ระยะเวลา |
|---|---|---|
| สลับแท็บหลัก | `FadeThrough` | 300ms |
| ขั้นของฟอร์ม | `SharedAxisSwitcher` | 300ms |
| รายการที่โหลดเสร็จ | `StaggeredEntrance` | 300ms + 60ms ต่อแถว (สูงสุด 8 แถว) |
| ยอดเงินและตัวเลขสำคัญ | `CountUp` | 600ms |
| กำลังโหลด | `Skeleton` ในรูปทรงของเนื้อหาจริง (ใช้แทนวงกลมหมุนเมื่อรู้รูปทรงของเนื้อหา) | กระพริบ 900ms ไม่เกิน 4 รอบแล้วหยุด |
| รูปจากการ์ดไปหน้าถัดไป | `Hero` | ตาม route |
| ช้างน้อย | `MascotView` ลอยขึ้นลงไม่เกิน 5 วินาทีแล้วหยุด (WCAG 2.2.2) | 1.2 วินาทีต่อรอบ |

Haptics ใช้ผ่าน `Haptics` เท่านั้น และมีแค่ 2 แบบ: `Haptics.select()` ตอนเลือกชิป วัน หรือจำนวน และ `Haptics.confirm()` ตอนบันทึกทริปหรือแผนเสร็จ ห้ามสั่นทุกครั้งที่กด

## 8. Accessibility (ต้องผ่านก่อน merge)

- พื้นที่กดไม่น้อยกว่า **48×48dp**
- ตัวอักษรขยายถึง **200%** แล้วต้องไม่ล้นหรือถูกตัด (ทดสอบด้วย Settings → Font size หรือ `MediaQuery.textScalerOf`)
- ปุ่มที่มีแต่ไอคอนต้องมี `tooltip` หรือ `Semantics(label: ...)`
- ห้ามสื่อความหมายด้วยสีอย่างเดียว เช่น สถานะ Over Budget ต้องมีไอคอนและข้อความด้วย
- หมุดบนแผนที่ต้องมี label ลำดับเลขให้ screen reader อ่านได้

## 9. ภาษาและข้อความ

- ข้อความในแอปเป็น**ภาษาไทยทั้งหมด** และใช้คำตาม [CONTEXT.md](../CONTEXT.md) เช่น "แผนการเดินทาง" ไม่ใช้ "Itinerary"
- ราคาทุกจุดต้องมีป้าย "ราคาโดยประมาณ"
- ทุกหน้าต้องมี **empty state** และ **error state** ที่บอกว่าเกิดอะไรขึ้นและผู้ใช้ทำอะไรต่อได้

## 10. Checklist ก่อนเปิด PR ที่มี UI

- [ ] import `package:material_ui/material_ui.dart` เท่านั้น (`grep -rn "flutter/material.dart\|flutter/cupertino.dart" lib` ต้องไม่เจอ)
- [ ] ใช้สีและตัวอักษรจาก theme ทั้งหมด (`grep -n "Colors\.\|fontSize" <ไฟล์ที่แก้>` ต้องไม่เจอ)
- [ ] ตรวจครบทั้ง Light และ Dark
- [ ] ตรวจครบทั้ง Compact (มือถือ) และ Expanded (แท็บเล็ตแนวนอน / หน้าต่างกว้าง)
- [ ] ขยายตัวอักษร 200% แล้วไม่ล้น
- [ ] แนบภาพหน้าจออย่างน้อย 2 ภาพใน PR: compact light และ expanded dark
