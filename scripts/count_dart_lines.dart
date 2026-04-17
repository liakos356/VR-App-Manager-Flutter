import 'dart:io';

/// Counts the number of Dart source files in lib/ that exceed the
/// 200-line project limit. The output is used by refactor-auto.prompt.md
/// to determine how many files to refactor in one session.
void main() {
  final dir = Directory('lib');
  final violations =
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f.readAsLinesSync().length > 200)
          .toList()
        ..sort(
          (a, b) =>
              b.readAsLinesSync().length.compareTo(a.readAsLinesSync().length),
        );

  for (final f in violations) {
    stderr.writeln(
      '  ${f.readAsLinesSync().length.toString().padLeft(5)}  ${f.path}',
    );
  }
  stdout.writeln(violations.length);
}
