import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [uri] in another app (the map app, the browser), or says
/// [failure] in a snack bar when nothing could open it, so a tap is never
/// silently lost (#196).
Future<void> openExternally(
  BuildContext context,
  Uri uri, {
  required String failure,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  bool opened;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Exception {
    // PlatformException, or MissingPluginException where no plugin exists.
    opened = false;
  }
  if (!opened) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failure)));
  }
}
