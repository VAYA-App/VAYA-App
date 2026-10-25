import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/domain.dart';

const photoCreditsAsset = 'assets/photos/credits.json';

/// The bundled photo for a Place, Destination or category id (ADR-0006).
String photoAsset(String id) => 'assets/photos/$id.webp';

/// Where a bundled photo came from, shown on the photo credits page.
final class PhotoCredit {
  const PhotoCredit({
    required this.id,
    required this.title,
    required this.author,
    required this.licence,
    required this.source,
    this.licenceUrl,
  });

  factory PhotoCredit.fromJson(Map<String, Object?> json) => PhotoCredit(
    id: json['id'] as String,
    title: json['title'] as String,
    author: json['author'] as String,
    licence: json['licence'] as String,
    licenceUrl: json['licenceUrl'] as String?,
    source: json['source'] as String,
  );

  /// The Place, Destination or `category-<name>` id the photo belongs to.
  final String id;
  final String title;
  final String author;
  final String licence;
  final String? licenceUrl;

  /// The file's page on Wikimedia Commons.
  final String source;
}

/// Every bundled photo, keyed by the id it belongs to.
final class PhotoCatalog {
  const PhotoCatalog(this.credits);

  final Map<String, PhotoCredit> credits;

  static String categoryId(PlaceCategory category) =>
      'category-${category.name}';

  /// The asset for [id], or the [fallback] category's photo when [id] has
  /// none of its own.
  String? assetFor(String id, {PlaceCategory? fallback}) {
    if (credits.containsKey(id)) return photoAsset(id);
    final category = fallback == null ? null : categoryId(fallback);
    return credits.containsKey(category) ? photoAsset(category!) : null;
  }

  /// Whether [id] has a photo of the place itself, not a category stand-in.
  bool hasOwnPhoto(String id) => credits.containsKey(id);
}

Future<PhotoCatalog> loadPhotoCatalog(AssetBundle bundle) async {
  final json =
      jsonDecode(await bundle.loadString(photoCreditsAsset))
          as Map<String, Object?>;
  return PhotoCatalog({
    for (final p in json['photos'] as List)
      (p as Map<String, Object?>)['id'] as String: PhotoCredit.fromJson(p),
  });
}
