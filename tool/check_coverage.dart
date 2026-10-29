// Fails when line coverage of lib/ is below the minimum (#147):
//   flutter test --coverage && dart run tool/check_coverage.dart [70]
// CI runs unit and widget tests apart and passes both lcov files:
//   dart run tool/check_coverage.dart 70 unit/lcov.info widget/lcov.info
import 'dart:io';

void main(List<String> args) {
  final minimum = args.isEmpty ? 70.0 : double.parse(args.first);
  final paths = args.length > 1 ? args.sublist(1) : ['coverage/lcov.info'];

  // A line counts as hit when any of the runs hit it, so a file that both
  // runs load is counted once.
  final hitsByFile = <String, Map<int, bool>>{};
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('$path not found; run flutter test --coverage');
      exit(2);
    }
    Map<int, bool>? lines;
    for (final line in file.readAsLinesSync()) {
      if (line.startsWith('SF:')) {
        lines = hitsByFile.putIfAbsent(line.substring(3), () => {});
      } else if (line.startsWith('DA:') && lines != null) {
        final parts = line.substring(3).split(',');
        final number = int.parse(parts[0]);
        final hit = int.parse(parts[1]) > 0;
        lines[number] = (lines[number] ?? false) || hit;
      }
    }
  }

  var found = 0;
  var hit = 0;
  for (final lines in hitsByFile.values) {
    found += lines.length;
    hit += lines.values.where((h) => h).length;
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
