// Fails when line coverage of lib/ is below the minimum (#147):
//   flutter test --coverage && dart run tool/check_coverage.dart [70]
import 'dart:io';

void main(List<String> args) {
  final minimum = args.isEmpty ? 70.0 : double.parse(args.first);
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    stderr.writeln('coverage/lcov.info not found; run flutter test --coverage');
    exit(2);
  }

  var found = 0;
  var hit = 0;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('LF:')) found += int.parse(line.substring(3));
    if (line.startsWith('LH:')) hit += int.parse(line.substring(3));
  }
  final percent = found == 0 ? 0.0 : hit * 100 / found;
  final summary =
      'Line coverage of lib/: ${percent.toStringAsFixed(1)}% '
      '($hit of $found lines), minimum $minimum%';
  stdout.writeln(summary);

  // Shown on the run's summary page in GitHub Actions.
  if (Platform.environment['GITHUB_STEP_SUMMARY'] case final path?) {
    File(path).writeAsStringSync('$summary\n', mode: FileMode.append);
  }
  if (percent < minimum) exit(1);
}
