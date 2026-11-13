import 'package:flutter_test/flutter_test.dart';

// The vendored build tool is outside rhttp's public package library.
// ignore: avoid_relative_lib_imports
import '../../packages/rhttp/cargokit/build_tool/lib/src/rustup.dart';
// ignore: avoid_relative_lib_imports
import '../../packages/rhttp/cargokit/build_tool/lib/src/util.dart';

void main() {
  tearDown(() => testRunCommandOverride = null);

  for (final newline in ['\n', '\r\n']) {
    test(
      'Cargokit reuses pinned Rust targets with ${newline.length}-byte newlines',
      () {
        final queried = <String>[];
        testRunCommandOverride = (args) {
          expect(args.executable, 'rustup');
          if (args.arguments.join(' ') == 'toolchain list') {
            return TestRunCommandResult(
              stdout:
                  '1.92.0-x86_64-unknown-linux-gnu (active, default)$newline',
            );
          }
          expect(args.arguments.take(3), ['target', 'list', '--toolchain']);
          expect(args.arguments.last, '--installed');
          queried.add(args.arguments[3]);
          return TestRunCommandResult(
            stdout:
                'x86_64-unknown-linux-gnu${newline}aarch64-apple-ios$newline',
          );
        };

        final rustup = Rustup();
        expect(rustup.installedTargets('1.92.0'), [
          'x86_64-unknown-linux-gnu',
          'aarch64-apple-ios',
        ]);
        expect(rustup.installedTargets('1.92.0'), isNotNull);
        expect(queried, ['1.92.0-x86_64-unknown-linux-gnu']);
      },
    );
  }

  test(
    'Cargokit retains channel support and excludes linked custom toolchains',
    () {
      final queried = <String>[];
      testRunCommandOverride = (args) {
        if (args.arguments.join(' ') == 'toolchain list') {
          return TestRunCommandResult(
            stdout: '''
stable-x86_64-unknown-linux-gnu (default)
beta-x86_64-unknown-linux-gnu
nightly-2026-10-01-x86_64-unknown-linux-gnu
1.92.0-aarch64-apple-darwin
local-linked-toolchain
''',
          );
        }
        expect(args.arguments.take(3), ['target', 'list', '--toolchain']);
        queried.add(args.arguments[3]);
        return TestRunCommandResult(stdout: 'aarch64-apple-darwin\n');
      };

      final rustup = Rustup();
      for (final name in ['stable', 'beta', 'nightly-2026-10-01', '1.92.0']) {
        expect(rustup.installedTargets(name), ['aarch64-apple-darwin']);
      }
      expect(rustup.installedTargets('local-linked-toolchain'), isNull);
      expect(rustup.installedTargets('1.91.0'), isNull);
      expect(queried, hasLength(4));
      expect(queried, isNot(contains('local-linked-toolchain')));
    },
  );
}
