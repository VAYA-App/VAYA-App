import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/domain.dart';
import '../open_externally.dart';

/// Where [place] is in the phone's map app: Apple Maps on iOS, Google Maps
/// everywhere else. The pin goes on the coordinates, since a name search can
/// land on another branch with the same name, and carries the name as its
/// label. Google Maps gets a web link rather than `geo:`, which Android
/// answers with an app chooser when the phone has several map apps.
Uri placeMapUri(Place place, {TargetPlatform? platform}) {
  final at = '${place.location.lat},${place.location.lng}';
  if ((platform ?? defaultTargetPlatform) == TargetPlatform.iOS) {
    return Uri.https('maps.apple.com', '/', {'ll': at, 'q': place.name});
  }
  return Uri.https('maps.google.com', '/maps', {'q': '$at(${place.name})'});
}

/// Opens [place] in the map app so the user can see where it is or get
/// there.
class OpenInMapsButton extends StatelessWidget {
  const OpenInMapsButton({super.key, required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => openExternally(
        context,
        placeMapUri(place),
        failure: 'เปิดแผนที่ไม่ได้',
      ),
      icon: const Icon(Icons.map_outlined),
      label: const Text('ดูบนแผนที่'),
    );
  }
}
