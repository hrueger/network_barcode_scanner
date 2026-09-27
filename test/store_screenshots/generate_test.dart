// Renders the store screenshots for every device and language.
//
//   flutter test test/store_screenshots --dart-define=STORE_SCREENSHOTS=true
//
// Without the define, a plain `flutter test` skips this file.
// Writes ios/fastlane/screenshots, macos/fastlane/screenshots and
// windows/store/screenshots, one folder per locale. The app's own screens
// render with canned data (see ScannerPreview and ListenerPreview), so this
// needs no device, camera or network, and gives the same pictures every run.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_barcode_scanner/screens/listener_screen.dart';
import 'package:network_barcode_scanner/screens/scanner_screen.dart';
import 'package:network_barcode_scanner/screens/settings_screen.dart';
import 'package:network_barcode_scanner/services/settings_service.dart';
import 'package:network_barcode_scanner/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'frames.dart';

const locales = ['en-US', 'de-DE'];
const generate = bool.fromEnvironment('STORE_SCREENSHOTS');

class Shot {
  final String name;
  final Map<String, (String, String)> captions;
  final Brightness brightness;
  final Widget Function() screen;

  const Shot(this.name, this.captions, this.brightness, this.screen);
}

final _now = DateTime.now();

ListenerScreen _listener() => ListenerScreen(
  preview: ListenerPreview(
    codes: [
      for (final (code, seconds) in const [
        ('4006381333931', 3),
        ('TKT-2026-004817', 19),
        ('40000395', 48),
        ('SN-C90-118420', 140),
        ('9783161484100', 610),
        ('TKT-2026-004816', 1260),
      ])
        ScannedCode(
          code: code,
          timestamp: _now.subtract(Duration(seconds: seconds)),
        ),
    ],
  ),
);

ScannerScreen _camera({List<String> listeners = const ['Front Desk PC']}) =>
    ScannerScreen(
      preview: ScannerPreview(
        listeners: listeners,
        cameraBackdrop: const CameraBackdrop(code: '4006381333931'),
      ),
    );

final handheldShots = [
  Shot(
    'scan',
    {
      'en-US': (
        'Scan with your phone',
        'Every code goes straight to your computer',
      ),
      'de-DE': ('Mit dem Handy scannen', 'Jeder Code landet direkt am Rechner'),
    },
    Brightness.light,
    _camera,
  ),
  Shot(
    'listeners',
    {
      'en-US': (
        'Finds your computers by itself',
        'No IP addresses, no pairing',
      ),
      'de-DE': (
        'Findet deine Rechner von selbst',
        'Keine IP-Adressen, kein Koppeln',
      ),
    },
    Brightness.dark,
    () => _camera(listeners: ['Front Desk PC', 'Warehouse Mac']),
  ),
  Shot(
    'settings',
    {
      'en-US': (
        'Made for busy counters',
        'Skips repeated scans and confirms with a sound',
      ),
      'de-DE': (
        'Gemacht für volle Theken',
        'Überspringt Doppelscans und bestätigt mit einem Ton',
      ),
    },
    Brightness.light,
    () => const SettingsScreen(desktop: false),
  ),
];

final desktopShots = [
  Shot(
    'listener',
    {
      'en-US': (
        'Scanned on the phone, typed on the computer',
        'Like a USB scanner, without the cable',
      ),
      'de-DE': (
        'Am Handy gescannt, am Rechner getippt',
        'Wie ein USB-Scanner, nur ohne Kabel',
      ),
    },
    Brightness.light,
    _listener,
  ),
  Shot(
    'dark',
    {
      'en-US': (
        'Types into any app',
        'Right where your cursor is, on any keyboard layout',
      ),
      'de-DE': (
        'Tippt in jede App',
        'Genau dort, wo der Cursor steht, mit jedem Tastaturlayout',
      ),
    },
    Brightness.dark,
    _listener,
  ),
  Shot(
    'settings',
    {
      'en-US': (
        'Enter or Tab after each code',
        'Moves on to the next field by itself',
      ),
      'de-DE': (
        'Enter oder Tab nach jedem Code',
        'Springt von selbst ins nächste Feld',
      ),
    },
    Brightness.light,
    () => const SettingsScreen(desktop: true),
  ),
];

String _outputDir(StoreDevice device, String locale) => switch (device) {
  StoreDevice.iphone || StoreDevice.ipad => 'ios/fastlane/screenshots/$locale',
  StoreDevice.mac => 'macos/fastlane/screenshots/$locale',
  StoreDevice.windows => 'windows/store/screenshots/$locale',
};

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
    );
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    if (!generate) return;
    final sdkFonts =
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
    await _loadFont('Roboto', [
      for (final weight in ['Regular', 'Medium', 'Bold'])
        '$sdkFonts/Roboto-$weight.ttf',
    ]);
    // The code list asks for 'monospace', which a device maps to its system
    // font; the test engine has none
    await _loadFont('monospace', [
      'test/store_screenshots/fonts/RobotoMono.ttf',
    ]);
    await _loadFont('MaterialIcons', ['$sdkFonts/MaterialIcons-Regular.otf']);
    await _loadFont('Inter', [
      'test/store_screenshots/fonts/Inter-SemiBold.ttf',
      'test/store_screenshots/fonts/Inter-Bold.ttf',
    ]);

    SharedPreferences.setMockInitialValues({
      'auto_type_on_receive': true,
      'auto_type_end_key': 'enter',
      'ignore_seen_codes': true,
    });
    await SettingsService().init();
  });

  for (final device in StoreDevice.values) {
    final shots = device.isDesktop ? desktopShots : handheldShots;
    for (final locale in locales) {
      for (final (index, shot) in shots.indexed) {
        testWidgets('${device.name} $locale ${shot.name}', skip: !generate, (
          tester,
        ) async {
          tester.view.physicalSize = device.pixels;
          tester.view.devicePixelRatio = device.pixelRatio;
          addTearDown(tester.view.reset);

          final key = GlobalKey();
          final (title, subtitle) = shot.captions[locale]!;
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: StoreFrame(
                  device: device,
                  title: title,
                  subtitle: subtitle,
                  brightness: shot.brightness,
                  app: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: buildTheme(Brightness.light),
                    darkTheme: buildTheme(Brightness.dark),
                    home: shot.screen(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final png = await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: device.pixelRatio);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            return bytes!.buffer.asUint8List();
          });
          final dir = Directory(_outputDir(device, locale))
            ..createSync(recursive: true);
          final number = (index + 1).toString().padLeft(2, '0');
          File(
            '${dir.path}/${number}_${shot.name}_${device.fileSuffix}.png',
          ).writeAsBytesSync(png!);
        });
      }
    }
  }
}
