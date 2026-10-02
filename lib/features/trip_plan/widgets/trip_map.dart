import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/domain.dart';

/// Where map tiles come from. `null` uses OpenStreetMap over the network;
/// tests override it so they never hit the network.
final mapTileProviderProvider = Provider<TileProvider?>((ref) => null);

/// OpenStreetMap of one Day Plan (ADR-0003).
class TripMap extends ConsumerStatefulWidget {
  const TripMap({
    super.key,
    required this.day,
    required this.catalog,
    this.nightStay,
    this.selectedIndex,
    this.onSelect,
  });

  final DayPlan day;
  final PlaceCatalog catalog;
  final NightStay? nightStay;
  final int? selectedIndex;
  final ValueChanged<int>? onSelect;

  @override
  ConsumerState<TripMap> createState() => _TripMapState();
}

class _TripMapState extends ConsumerState<TripMap> {
  final _controller = MapController();

  LatLng _at(String placeId) {
    final location = widget.catalog.place(placeId).location;
    return LatLng(location.lat, location.lng);
  }

  List<LatLng> get _points => [
    for (final stop in widget.day.stops) _at(stop.placeId),
    if (widget.nightStay case final stay?) _at(stay.placeId),
  ];

  CameraFit get _fitAll => CameraFit.coordinates(
    coordinates: _points,
    padding: const EdgeInsets.all(56),
    maxZoom: 15,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCameraFit: _fitAll,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'app.vaya.vaya_app',
          tileProvider: ref.watch(mapTileProviderProvider),
          tileBuilder: dark ? darkModeTileBuilder : null,
        ),
        SimpleAttributionWidget(
          source: Text(
            'OpenStreetMap contributors',
            style: TextStyle(color: colors.onSurface),
          ),
          backgroundColor: colors.surface.withValues(alpha: 0.85),
        ),
      ],
    );
  }
}
