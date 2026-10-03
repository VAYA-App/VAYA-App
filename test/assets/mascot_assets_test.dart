import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Poses documented in docs/MASCOT.md.
const _poses = ['wave', 'calendar', 'budget', 'map', 'celebrate', 'avatar'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AssetManifest manifest;

  setUpAll(() async {
    manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  });

  for (final pose in _poses) {
    test('$pose ships as WebP at 1x, 2x and 3x', () async {
      final path = 'assets/mascot/$pose.webp';
      final ratios = manifest
          .getAssetVariants(path)
          ?.map((v) => v.targetDevicePixelRatio ?? 1.0);
      expect(ratios, containsAll([1.0, 2.0, 3.0]));

      final bytes = (await rootBundle.load(path)).buffer.asUint8List();
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP');
    });
  }
}
