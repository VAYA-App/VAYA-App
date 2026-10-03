import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current time; override in tests.
final greetingClockProvider = Provider<DateTime>((ref) => DateTime.now());

/// Home greeting and nudge for the time of day (#80).
({String title, String subtitle}) greetingFor(DateTime time) =>
    switch (time.hour) {
      >= 5 && < 11 => (
        title: 'สวัสดีตอนเช้า',
        subtitle: 'เช้านี้เริ่มวางแผนทริปถัดไปกันไหม?',
      ),
      >= 11 && < 16 => (
        title: 'สวัสดีตอนกลางวัน',
        subtitle: 'พักสายตาแป๊บ แล้วมาหาที่เที่ยวกัน',
      ),
      >= 16 && < 19 => (
        title: 'สวัสดีตอนเย็น',
        subtitle: 'เย็นนี้วางแผนทริปวันหยุดกันไหม?',
      ),
      >= 19 => (
        title: 'สวัสดีตอนค่ำ',
        subtitle: 'ก่อนนอนลองวางแผนทริปถัดไปดูไหม?',
      ),
      _ => (title: 'ดึกแล้วนะ', subtitle: 'วางแผนนิดเดียว แล้วไปพักผ่อนนะ'),
    };
