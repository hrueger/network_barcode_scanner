import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:network_barcode_scanner/screens/listener_screen.dart';
import 'package:network_barcode_scanner/screens/scanner_screen.dart';
import 'package:network_barcode_scanner/screens/settings_screen.dart';
import 'package:network_barcode_scanner/services/settings_service.dart';
import 'package:network_barcode_scanner/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().init();
  });

  Widget app(Brightness brightness, Widget home) =>
      MaterialApp(theme: buildTheme(brightness), home: home);

  for (final brightness in Brightness.values) {
    testWidgets('listener shows received codes ($brightness)', (tester) async {
      await tester.pumpWidget(
        app(
          brightness,
          ListenerScreen(
            preview: ListenerPreview(
              codes: [ScannedCode(code: '40000395', timestamp: DateTime.now())],
            ),
          ),
        ),
      );
      expect(find.text('Listening for codes...'), findsOneWidget);
      expect(find.text('40000395'), findsOneWidget);
    });

    testWidgets('scanner names the listeners it sends to ($brightness)', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          brightness,
          const ScannerScreen(
            preview: ScannerPreview(
              listeners: ['Front Desk PC'],
              handheld: 'C90',
            ),
          ),
        ),
      );
      expect(find.text('Sending to: Front Desk PC'), findsOneWidget);
      expect(find.text('Ready to scan'), findsOneWidget);
    });

    testWidgets('scanner warns when no listener was found ($brightness)', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          brightness,
          const ScannerScreen(preview: ScannerPreview(handheld: 'C90')),
        ),
      );
      expect(find.text('No listeners found – broadcast only'), findsOneWidget);
    });

    testWidgets('settings show the listener section on desktop ($brightness)', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(brightness, const SettingsScreen(desktop: true)),
      );
      expect(find.text('Auto-Type on Receive'), findsOneWidget);
    });

    testWidgets('camera error asks for access when denied ($brightness)', (
      tester,
    ) async {
      var retried = false;
      await tester.pumpWidget(
        app(
          brightness,
          CameraErrorView(
            error: const MobileScannerException(
              errorCode: MobileScannerErrorCode.permissionDenied,
            ),
            onRetry: () => retried = true,
          ),
        ),
      );
      expect(find.text('Camera access needed'), findsOneWidget);
      await tester.tap(find.text('Allow camera'));
      expect(retried, isTrue);
    });

    testWidgets('camera error names a missing camera ($brightness)', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          brightness,
          CameraErrorView(
            error: const MobileScannerException(
              errorCode: MobileScannerErrorCode.unsupported,
            ),
            onRetry: () {},
          ),
        ),
      );
      expect(find.text('No camera found'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });
  }
}
