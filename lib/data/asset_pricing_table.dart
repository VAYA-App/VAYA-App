import 'dart:convert';

import 'package:flutter/services.dart';

import '../planner/pricing_table.dart';

const pricingAsset = 'assets/data/pricing.json';

/// Loads the bundled price table described in docs/DATA.md.
Future<PricingTable> loadPricingTable(AssetBundle bundle) async =>
    PricingTable.fromJson(
      jsonDecode(await bundle.loadString(pricingAsset)) as Map<String, Object?>,
    );
