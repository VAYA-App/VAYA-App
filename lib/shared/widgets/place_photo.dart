import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers/data_providers.dart';
import '../../domain/domain.dart';

/// The bundled photo of a Place or Destination, cropped to fill its box
/// (docs/DESIGN.md §6). A Place without a photo of its own shows its
/// category's photo; while the catalog loads, or when there is no photo at
/// all, the box shows a quiet tint instead.
///
/// [label] is read by screen readers, normally the place's name. Give a
/// [heroTag] when the same photo also appears on the next screen.
class PlacePhoto extends ConsumerWidget {
  const PlacePhoto({
    super.key,
    required this.id,
    required this.label,
    this.category,
    this.heroTag,
  });

  /// A Place or Province id.
  final String id;
  final String label;

  /// Used as the fallback photo when [id] has none.
  final PlaceCategory? category;
  final Object? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = ref
        .watch(photoCatalogProvider)
        .whenOrNull(data: (c) => c.assetFor(id, fallback: category));
    final tint = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
    );

    Widget photo = asset == null
        ? Semantics(label: label, image: true, child: tint)
        : LayoutBuilder(
            builder: (context, constraints) => Image.asset(
              asset,
              fit: BoxFit.cover,
              semanticLabel: label,
              // Decode no larger than the box, keeping memory low in lists.
              cacheWidth: constraints.hasBoundedWidth
                  ? (constraints.maxWidth *
                            MediaQuery.devicePixelRatioOf(context))
                        .round()
                  : null,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => tint,
            ),
          );
    if (heroTag != null) photo = Hero(tag: heroTag!, child: photo);
    return SizedBox.expand(child: photo);
  }
}

/// Text laid over a photo (docs/DESIGN.md §6): a dark gradient rising from
/// the bottom and white text, the same in light and dark mode. The one place
/// in the app where photo text gets its fixed colour.
class PhotoScrim extends StatelessWidget {
  const PhotoScrim({super.key, required this.child});

  /// Drawn over the gradient; lay it out at the bottom of the photo and
  /// read text styles from `Theme.of` inside it.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scrim = theme.colorScheme.scrim;
    const onPhoto = Colors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scrim.withValues(alpha: 0.15),
            scrim.withValues(alpha: 0),
            scrim.withValues(alpha: 0.72),
          ],
          stops: const [0, 0.35, 1],
        ),
      ),
      // Text styles from the theme carry their own colour, so the child
      // gets a theme whose text and icons are white.
      child: Theme(
        data: theme.copyWith(
          textTheme: theme.textTheme.apply(
            bodyColor: onPhoto,
            displayColor: onPhoto,
          ),
          iconTheme: theme.iconTheme.copyWith(color: onPhoto),
        ),
        child: child,
      ),
    );
  }
}
