import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/data/asset_pricing_table.dart';
import 'package:vaya_app/domain/domain.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the bundled pricing table', () async {
    final table = await loadPricingTable(rootBundle);

    expect(table.roomFor(1), 700);
    expect(table.rateFor(LocalTransportMode.publicTransport).perTrip, 30);
  });
}
