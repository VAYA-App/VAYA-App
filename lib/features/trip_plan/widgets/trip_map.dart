import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/road_router.dart';
import '../../../domain/domain.dart';
import '../../../planner/geo.dart';
import '../../../shared/widgets/motion.dart';

/// Where map tiles come from. `null` uses CARTO over the network; tests
/// override it so they never hit the network.
final mapTileProviderProvider = Provider<TileProvider?>((ref) => null);

/// Road paths for the route line; tests override it so they never hit the
/// network.
final roadRouterProvider = Provider<RoadRouter>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return RoadRouter(client);
});

/// The road path through a day's points, kept for the session so switching
/// days does not ask again. `null` means draw straight lines (#140).
final roadRouteProvider = FutureProvider.family<List<GeoPoint>?, RoutePoints>(
  (ref, points) => ref.watch(roadRouterProvider).route(points.points),
);

/// The map of one Day Plan (ADR-0003, #182): a light CARTO base map, the
/// route split into legs between Stops that can be tapped for directions,
/// numbered pins, and a camera that glides to whatever is picked.
///
/// The route draws itself in when the day changes, unless the user turned
/// animations off. Until the road shape arrives, or offline, legs are
/// straight lines between the pins.
class TripMap extends ConsumerStatefulWidget {
  const TripMap({
    super.key,
    required this.day,
    required this.catalog,
    this.nightStay,
    this.selectedIndex,
    this.onSelect,
    this.transport = LocalTransportMode.taxi,
    this.interactive = true,
    this.padding = EdgeInsets.zero,
  });

  final DayPlan day;
  final PlaceCatalog catalog;
  final NightStay? nightStay;
  final int? selectedIndex;
  final ValueChanged<int>? onSelect;

  /// How the traveller gets around, for the directions a leg opens.
  final LocalTransportMode transport;

  /// `false` for small previews: no gestures and no controls.
  final bool interactive;

  /// Space covered by things drawn over the map, such as a bottom sheet;
  /// the camera keeps the route clear of it.
  final EdgeInsets padding;

  @override
  ConsumerState<TripMap> createState() => _TripMapState();
}

class _TripMapState extends ConsumerState<TripMap>
    with TickerProviderStateMixin {
  final _controller = MapController();
  final _hits = ValueNotifier<LayerHitResult<int>?>(null);

  /// Reveals the route from the first pin to the last.
  late final _draw = AnimationController(
    vsync: this,
    duration: Motion.long * 2,
    value: 1,
  );

  /// Glides the camera between two views.
  late final _fly = AnimationController(vsync: this, duration: Motion.long);

  int? _selectedLeg;

  static LatLng _latLng(GeoPoint p) => LatLng(p.lat, p.lng);

  /// The day's Stops in order, then the Night Stay.
  List<Place> get _places => [
    for (final stop in widget.day.stops) widget.catalog.place(stop.placeId),
    if (widget.nightStay case final stay?) widget.catalog.place(stay.placeId),
  ];

  List<GeoPoint> get _waypoints => [for (final p in _places) p.location];

  CameraFit _fit(List<GeoPoint> points) => CameraFit.coordinates(
    coordinates: [for (final p in points) _latLng(p)],
    padding: widget.padding + const EdgeInsets.all(56),
    maxZoom: 15,
  );

  @override
  void initState() {
    super.initState();
    _drawRoute();
  }

  void _drawRoute() {
    if (!widget.interactive) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _draw.value = 1;
      } else {
        _draw.forward(from: 0);
      }
    });
  }

  /// Keeps the camera on what the timeline shows: the whole day after a
  /// day change, the Stop the user picked after a selection.
  @override
  void didUpdateWidget(TripMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day) {
      _selectedLeg = null;
      _flyTo(_fit(_waypoints));
      _drawRoute();
    } else if (widget.selectedIndex case final i?
        when i != oldWidget.selectedIndex) {
      final place = widget.catalog.place(widget.day.stops[i].placeId);
      final zoom = _controller.camera.zoom;
      _flyToPoint(_latLng(place.location), zoom < 14 ? 14 : zoom);
    }
  }

  void _flyTo(CameraFit fit) => _animateCamera(fit.fit(_controller.camera));

  void _flyToPoint(LatLng center, double zoom) => _animateCamera(
    _controller.camera.withPosition(center: center, zoom: zoom),
  );

  void _animateCamera(MapCamera target) {
    final from = _controller.camera;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.move(target.center, target.zoom);
      return;
    }
    final lat = Tween(begin: from.center.latitude, end: target.center.latitude);
    final lng = Tween(
      begin: from.center.longitude,
      end: target.center.longitude,
    );
    final zoom = Tween(begin: from.zoom, end: target.zoom);
    final curve = CurvedAnimation(parent: _fly, curve: Curves.easeInOutCubic);
    void step() => _controller.move(
      LatLng(lat.evaluate(curve), lng.evaluate(curve)),
      zoom.evaluate(curve),
    );
    _fly
      ..stop()
      ..reset();
    _fly.addListener(step);
    _fly.forward().whenCompleteOrCancel(() {
      _fly.removeListener(step);
      curve.dispose();
    });
  }

  void _tapRoute() {
    final leg = _hits.value?.hitValues.firstOrNull;
    if (leg == null) return;
    setState(() => _selectedLeg = leg == _selectedLeg ? null : leg);
    if (_selectedLeg != null) {
      final places = _places;
      _flyTo(_fit([places[leg].location, places[leg + 1].location]));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _hits.dispose();
    _draw.dispose();
    _fly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final waypoints = _waypoints;
    final road = ref.watch(roadRouteProvider(RoutePoints(waypoints))).value;
    final legs = splitIntoLegs(road, waypoints);
    final places = _places;

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCameraFit: _fit(waypoints),
            backgroundColor: colors.surfaceContainer,
            interactionOptions: InteractionOptions(
              flags: widget.interactive
                  ? InteractiveFlag.all & ~InteractiveFlag.rotate
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: dark
                  ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                  : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              retinaMode: RetinaMode.isHighDensity(context),
              userAgentPackageName: 'app.vaya.vaya_app',
              tileProvider: ref.watch(mapTileProviderProvider),
            ),
            AnimatedBuilder(
              animation: _draw,
              builder: (context, _) => GestureDetector(
                onTap: widget.interactive ? _tapRoute : null,
                child: PolylineLayer<int>(
                  hitNotifier: _hits,
                  polylines: _polylines(legs, colors),
                ),
              ),
            ),
            MarkerLayer(
              markers: [
                if (widget.nightStay case final stay?)
                  Marker(
                    point: _latLng(widget.catalog.place(stay.placeId).location),
                    width: 40,
                    height: 40,
                    child: _StayMarker(
                      name: widget.catalog.place(stay.placeId).name,
                    ),
                  ),
                for (final (i, stop) in widget.day.stops.indexed)
                  Marker(
                    point: _latLng(widget.catalog.place(stop.placeId).location),
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
            Padding(
              padding: EdgeInsets.only(bottom: widget.padding.bottom),
              child: SimpleAttributionWidget(
                source: Text(
                  '© OpenStreetMap © CARTO',
                  style: TextStyle(color: colors.onSurface),
                ),
                backgroundColor: colors.surface.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        if (widget.interactive)
          Positioned(
            right: 16,
            bottom: widget.padding.bottom + 32,
            child: FloatingActionButton.small(
              // Several maps can live in one route.
              heroTag: null,
              tooltip: 'ดูทั้งวัน',
              onPressed: () {
                setState(() => _selectedLeg = null);
                _flyTo(_fit(waypoints));
              },
              child: const Icon(Icons.fit_screen_outlined),
            ),
          ),
        if (_selectedLeg case final leg? when leg + 1 < places.length)
          Positioned(
            left: 12,
            right: 12,
            top: widget.padding.top + 12,
            child: _LegCard(
              from: places[leg],
              to: places[leg + 1],
              travel: leg + 1 < widget.day.stops.length
                  ? (
                      km: widget.day.stops[leg + 1].travelFromPrevKm,
                      minutes: widget.day.stops[leg + 1].travelFromPrevMin,
                    )
                  : travelBetween(
                      places[leg].location,
                      places[leg + 1].location,
                    ),
              transport: widget.transport,
              onClose: () => setState(() => _selectedLeg = null),
            ),
          ),
      ],
    );
  }

  /// The legs revealed so far by [_draw], the picked one on top and the
  /// rest faded while one is picked.
  List<Polyline<int>> _polylines(
    List<List<GeoPoint>> legs,
    ColorScheme colors,
  ) {
    final total = legs.fold(0, (n, l) => n + l.length);
    var budget = (total * _draw.value).ceil();
    final lines = <Polyline<int>>[];
    for (final (i, leg) in legs.indexed) {
      if (budget < 2) break;
      final shown = leg.take(budget).toList();
      budget -= leg.length;
      final picked = _selectedLeg == i;
      final faded = _selectedLeg != null && !picked;
      lines.add(
        Polyline(
          points: [for (final p in shown) _latLng(p)],
          hitValue: i,
          strokeWidth: picked ? 7 : 5,
          color: picked
              ? colors.tertiary
              : colors.primary.withValues(alpha: faded ? 0.35 : 1),
          borderColor: colors.surface,
          borderStrokeWidth: 2,
        ),
      );
    }
    // Draw the picked leg last so it sits above the others.
    if (_selectedLeg case final i? when i < lines.length) {
      lines.add(lines.removeAt(i));
    }
    return lines;
  }
}

/// One leg of the route: from where to where, how far and how long, and a
/// button that opens turn-by-turn directions in the phone's map app.
class _LegCard extends StatelessWidget {
  const _LegCard({
    required this.from,
    required this.to,
    required this.travel,
    required this.transport,
    required this.onClose,
  });

  final Place from;
  final Place to;
  final ({double km, int minutes}) travel;
  final LocalTransportMode transport;
  final VoidCallback onClose;

  Uri get _directions {
    final transit = transport == LocalTransportMode.publicTransport;
    final a = '${from.location.lat},${from.location.lng}';
    final b = '${to.location.lat},${to.location.lng}';
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return Uri.https('maps.apple.com', '/', {
        'saddr': a,
        'daddr': b,
        'dirflg': transit ? 'r' : 'd',
      });
    }
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': a,
      'destination': b,
      'travelmode': transit ? 'transit' : 'driving',
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${from.name} → ${to.name}',
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${travel.km.toStringAsFixed(1)} กม. · '
                    'ราว ${travel.minutes} นาที · ${transport.label}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: () =>
                  launchUrl(_directions, mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.navigation_outlined),
              label: const Text('นำทาง'),
            ),
            IconButton(
              tooltip: 'ปิด',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
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
          duration: Motion.of(context, Motion.short),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: Border.all(color: colors.surface, width: 2),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
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
