// Cuts a release: store release notes from changelog.json, version bump,
// commit, tag, push. The tag starts release.yml (GitHub release) and
// store.yml (App Store, Mac App Store, Google Play, Microsoft Store).
//
//   dart run tool/release.dart 1.2.3
//
// Write the changelog.json entry for the version first. Without one, this adds
// an empty entry at the top and stops, so you can fill it in and run again.
import 'dart:convert';
import 'dart:io';

/// Store limits on release notes, per locale
const _limits = {
  'App Store': 4000,
  'Google Play': 500,
  'Microsoft Store': 1500,
};

/// changelog.json's language keys, and the store locales they fill
const _locales = {'en': 'en-US', 'de': 'de-DE'};

Never _fail(String message) {
  stderr.writeln('release: $message');
  exit(1);
}

String _run(String executable, List<String> args, {bool echo = false}) {
  if (echo) stdout.writeln('\$ $executable ${args.join(' ')}');
  final result = Process.runSync(
    executable,
    args,
    runInShell: Platform.isWindows,
  );
  if (result.exitCode != 0) {
    _fail(
      '$executable ${args.join(' ')} failed:\n${result.stdout}${result.stderr}',
    );
  }
  if (echo) stdout.write(result.stdout);
  return (result.stdout as String).trim();
}

List<int> _parse(String version) {
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(version);
  if (match == null) _fail('"$version" is not a version like 1.2.3');
  return [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
}

bool _isNewer(List<int> a, List<int> b) {
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

void main(List<String> args) {
  if (args.length != 1) _fail('usage: dart run tool/release.dart <version>');
  final version = args.single;
  final next = _parse(version);

  // The tag must point at exactly what is on origin/main, nothing local
  if (_run('git', ['status', '--porcelain']).isNotEmpty) {
    _fail('the working tree has uncommitted changes');
  }
  if (_run('git', ['rev-parse', '--abbrev-ref', 'HEAD']) != 'main') {
    _fail('releases are cut from main');
  }
  _run('git', ['fetch', '--quiet', 'origin']);
  if (_run('git', ['rev-parse', 'HEAD']) !=
      _run('git', ['rev-parse', 'origin/main'])) {
    _fail('main is not in sync with origin/main, pull or push first');
  }
  if (_run('git', ['tag', '--list', 'v$version']).isNotEmpty) {
    _fail('v$version is already tagged');
  }

  final pubspec = File('pubspec.yaml');
  final pubspecText = pubspec.readAsStringSync();
  final current = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)',
    multiLine: true,
  ).firstMatch(pubspecText);
  if (current == null) _fail('no "version: x.y.z+n" in pubspec.yaml');
  if (!_isNewer(next, _parse(current.group(1)!))) {
    _fail('$version is not newer than the current ${current.group(1)}');
  }

  // The changelog entry is the one source of every store's release notes
  final changelogFile = File('changelog.json');
  final changelog = (jsonDecode(changelogFile.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final entry = changelog.firstOrNull;
  if (entry == null || entry['version'] != version) {
    changelog.insert(0, {
      'version': version,
      'date': DateTime.now().toIso8601String().substring(0, 10),
      for (final language in _locales.keys) language: <String>[],
    });
    changelogFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(changelog)}\n',
    );
    _fail(
      'added an empty $version entry to changelog.json; fill in its lines and run again',
    );
  }
  final notes = <String, String>{};
  for (final MapEntry(key: language, value: locale) in _locales.entries) {
    final lines = (entry[language] as List? ?? [])
        .cast<String>()
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      _fail('the $version entry in changelog.json has no "$language" lines');
    }
    notes[locale] = lines.length == 1
        ? lines.single
        : lines.map((l) => '• $l').join('\n');
    for (final MapEntry(key: store, value: limit) in _limits.entries) {
      if (notes[locale]!.length > limit) {
        _fail(
          'the $language notes are ${notes[locale]!.length} characters, $store allows $limit',
        );
      }
    }
  }
  entry['date'] = DateTime.now().toIso8601String().substring(0, 10);
  changelogFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(changelog)}\n',
  );

  for (final MapEntry(key: locale, value: text) in notes.entries) {
    File(
      'ios/fastlane/metadata/$locale/release_notes.txt',
    ).writeAsStringSync('$text\n');
    File(
      'macos/fastlane/metadata/$locale/release_notes.txt',
    ).writeAsStringSync('$text\n');
    File(
      'android/fastlane/metadata/android/$locale/changelogs/default.txt',
    ).writeAsStringSync('$text\n');
    final listing = File('windows/store/listing/$locale.json');
    final json = jsonDecode(listing.readAsStringSync()) as Map<String, dynamic>;
    json['releaseNotes'] = text;
    listing.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(json)}\n',
    );
  }

  // The build number only has to grow; the stores count their own up from it
  final build = int.parse(current.group(2)!) + 1;
  pubspec.writeAsStringSync(
    pubspecText.replaceFirst(current.group(0)!, 'version: $version+$build'),
  );

  _run('flutter', ['analyze'], echo: true);
  _run('flutter', ['test'], echo: true);

  _run('git', [
    'add',
    '-A',
    'pubspec.yaml',
    'changelog.json',
    'ios/fastlane/metadata',
    'macos/fastlane/metadata',
    'android/fastlane/metadata',
    'windows/store/listing',
  ]);
  _run('git', [
    'commit',
    '--quiet',
    '-m',
    'chore: release $version',
  ], echo: true);
  _run('git', [
    'tag',
    '-a',
    'v$version',
    '-m',
    'Network Barcode Scanner $version',
  ], echo: true);
  _run('git', ['push', '--quiet', 'origin', 'main', 'v$version'], echo: true);
  stdout.writeln(
    'Released $version: https://github.com/hrueger/network_barcode_scanner/actions',
  );
}
