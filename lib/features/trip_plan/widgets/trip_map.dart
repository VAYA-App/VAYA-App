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
    this.interactive = true,
  });

  final DayPlan day;
  final PlaceCatalog catalog;
  final NightStay? nightStay;
  final int? selectedIndex;
  final ValueChanged<int>? onSelect;

  /// `false` for small previews: no gestures and no controls.
  final bool interactive;

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

  /// Keeps the camera on what the timeline shows: the whole day after a
  /// day change, the Stop the user picked after a selection.
  @override
  void didUpdateWidget(TripMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day) {
      _controller.fitCamera(_fitAll);
    } else if (widget.selectedIndex case final i?
        when i != oldWidget.selectedIndex) {
      final zoom = _controller.camera.zoom;
      _controller.move(_at(widget.day.stops[i].placeId), zoom < 14 ? 14 : zoom);
    }
  }

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
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'app.vaya.vaya_app',
          tileProvider: ref.watch(mapTileProviderProvider),
          tileBuilder: dark ? darkModeTileBuilder : null,
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: _points,
              color: colors.primary,
              strokeWidth: 4,
              borderColor: colors.surface,
              borderStrokeWidth: 2,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            if (widget.nightStay case final stay?)
              Marker(
                point: _at(stay.placeId),
                width: 40,
                height: 40,
                child: _StayMarker(
                  name: widget.catalog.place(stay.placeId).name,
                ),
              ),
            for (final (i, stop) in widget.day.stops.indexed)
              Marker(
                point: _at(stop.placeId),
                width: 40,
                height: 40,
                child: _StopMarker(
                  number: i + 1,
                  name: widget.catalog.place(stop.placeId).name,
                  selected: widget.selectedIndex == i,
                  onTap: widget.onSelect == null
                      ? null
                      : () => widget.onSelect!(i),
                ),
              ),
          ],
        ),
        if (widget.interactive)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: FloatingActionButton.small(
                // Several maps can live in one TabBarView.
                heroTag: null,
                tooltip: 'ดูทุกจุดของวันนี้',
                onPressed: () => _controller.fitCamera(_fitAll),
                child: const Icon(Icons.fit_screen_outlined),
              ),
            ),
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

class _StopMarker extends StatelessWidget {
  const _StopMarker({
    required this.number,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final int number;
  final String name;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final background = selected ? colors.tertiary : colors.primary;
    final foreground = selected ? colors.onTertiary : colors.onPrimary;

    return Semantics(
      label: 'จุดที่ $number $name',
      button: onTap != null,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1.2 : 1,
          duration: const Duration(milliseconds: 150),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: Border.all(color: colors.surface, width: 2),
            ),
            child: Center(
              child: Text(
                '$number',
                style: theme.textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StayMarker extends StatelessWidget {
  const _StayMarker({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'ที่พัก $name',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.tertiaryContainer,
          shape: BoxShape.circle,
          border: Border.all(color: colors.surface, width: 2),
        ),
        child: Icon(
          Icons.bed_outlined,
          size: 20,
          color: colors.onTertiaryContainer,
        ),
      ),
    );
  }
}
