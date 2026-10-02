// Enumerations shared across the app. JSON uses each value's `name`;
// `label` is the Thai text shown in the UI. Terms follow CONTEXT.md.

enum PlaceCategory {
  attraction('สถานที่ท่องเที่ยว'),
  restaurant('ร้านอาหาร'),
  accommodation('ที่พัก');

  const PlaceCategory(this.label);
  final String label;
}

/// Preference Tags the user picks and that every Place is tagged with.
enum PreferenceTag {
  nature('ธรรมชาติ'),
  beach('ทะเล'),
  cafe('คาเฟ่'),
  templeHistory('วัด/ประวัติศาสตร์'),
  artCulture('ศิลปะ/วัฒนธรรม'),
  localFood('อาหารท้องถิ่น'),
  seafood('ซีฟู้ด'),
  shopping('ช้อปปิ้ง'),
  nightlife('ไนท์ไลฟ์'),
  viewpoint('จุดชมวิว'),
  family('ครอบครัว'),
  wellness('สปา/ผ่อนคลาย'),
  adventure('กิจกรรมผจญภัย');

  const PreferenceTag(this.label);
  final String label;
}

enum Pace {
  chill('ชิล'),
  normal('ปกติ'),
  packed('อัดแน่น');

  const Pace(this.label);
  final String label;
}

/// A part of a day that one Stop fills (PROJECT-PLAN §8).
enum Slot {
  morning('เช้า'),
  lunch('กลางวัน'),
  afternoon('บ่าย'),
  dinner('เย็น'),
  evening('กลางคืน');

  const Slot(this.label);
  final String label;

  bool get isMeal => this == lunch || this == dinner;
}

/// Intercity Transport modes supported between Bangkok and Chonburi.
enum IntercityMode {
  bus('รถทัวร์/รถตู้'),
  train('รถไฟ'),
  car('ขับรถเอง');

  const IntercityMode(this.label);
  final String label;
}

enum LocalTransportMode {
  rentalCar('เช่ารถยนต์'),
  rentalMotorbike('เช่ามอเตอร์ไซค์'),
  taxi('Grab/แท็กซี่'),
  publicTransport('รถสาธารณะ');

  const LocalTransportMode(this.label);
  final String label;
}

enum SeasonRating {
  good('ช่วงที่ดี'),
  ok('เที่ยวได้'),
  avoid('ควรเลี่ยง');

  const SeasonRating(this.label);
  final String label;
}

enum PlanStatus { ok, overBudget }

/// Ways to bring an Over Budget Trip Plan back under budget (M6).
enum BudgetAdviceKind {
  downgradeAccommodation,
  changeLocalTransport,
  removeDay,
  changeDestination,
}
