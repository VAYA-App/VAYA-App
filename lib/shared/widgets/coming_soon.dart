import 'package:material_ui/material_ui.dart';

/// Tells the user a button's feature is not built yet. [issue] points
/// teammates at the GitHub issue that will build it.
void showComingSoon(BuildContext context, String feature, {int? issue}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          '$feature · เร็ว ๆ นี้${issue == null ? '' : ' (#$issue)'}',
        ),
      ),
    );
}
