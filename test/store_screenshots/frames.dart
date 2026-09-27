import 'dart:math';

import 'package:flutter/material.dart';
import 'package:network_barcode_scanner/theme.dart';

/// The devices the stores want screenshots for, at the exact pixel sizes
/// App Store Connect, Google Play and Partner Center accept.
enum StoreDevice {
  iphone(Size(1320, 2868), 3, 'iphone', Size(440, 956)),
  // Play allows at most 2:1, which rules out reusing the iPhone shots
  android(Size(1080, 1920), 2.625, 'android', Size(412, 892)),
  ipad(Size(2064, 2752), 2, 'ipad', Size(1032, 1376)),
  mac(Size(2880, 1800), 2, 'mac', Size(1040, 600)),
  windows(Size(1920, 1080), 1.5, 'windows', Size(1000, 600));

  const StoreDevice(
    this.pixels,
    this.pixelRatio,
    this.fileSuffix,
    this.appSize,
  );

  /// Size of the finished PNG
  final Size pixels;
  final double pixelRatio;
  final String fileSuffix;

  /// Logical size the app itself is laid out at, before being scaled into
  /// the frame: a real device screen, or a desktop window.
  final Size appSize;

  Size get logical => pixels / pixelRatio;
  bool get isDesktop => this == mac || this == windows;
}

/// Brand background with a caption, and the app inside a device or window.
class StoreFrame extends StatelessWidget {
  final StoreDevice device;
  final String title;
  final String subtitle;
  final Brightness brightness;
  final Widget app;

  const StoreFrame({
    super.key,
    required this.device,
    required this.title,
    required this.subtitle,
    required this.brightness,
    required this.app,
  });

  @override
  Widget build(BuildContext context) {
    final size = device.logical;
    final captionScale = device.isDesktop
        ? size.height / 560
        : size.width / 440;
    return SizedBox.fromSize(
      size: size,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF14B8A6), Color(0xFF0F5F63)],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            size.width * 0.06,
            size.height * (device.isDesktop ? 0.06 : 0.05),
            size.width * 0.06,
            0,
          ),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 34 * captionScale,
                  height: 1.15,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10 * captionScale),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 18 * captionScale,
                  height: 1.3,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              SizedBox(height: size.height * 0.04),
              Expanded(
                child: device.isDesktop
                    ? Padding(
                        padding: EdgeInsets.only(bottom: size.height * 0.06),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: FittedBox(child: _window()),
                        ),
                      )
                    // Phones and tablets bleed off the bottom edge
                    : OverflowBox(
                        alignment: Alignment.topCenter,
                        maxHeight: double.infinity,
                        child: FractionallySizedBox(
                          widthFactor: 0.86,
                          child: FittedBox(child: _handheld()),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _screen({required EdgeInsets padding}) {
    return SizedBox.fromSize(
      size: device.appSize,
      child: MediaQuery(
        data: MediaQueryData(
          size: device.appSize,
          padding: padding,
          viewPadding: padding,
          platformBrightness: brightness,
        ),
        child: app,
      ),
    );
  }

  Widget _handheld() {
    final isPhone = device == StoreDevice.iphone;
    final isAndroid = device == StoreDevice.android;
    final radius = isPhone ? 56.0 : (isAndroid ? 36.0 : 32.0);
    final bezel = isPhone ? 12.0 : (isAndroid ? 10.0 : 18.0);
    final statusBar = isPhone ? 54.0 : (isAndroid ? 36.0 : 28.0);
    return Container(
      padding: EdgeInsets.all(bezel),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(radius + bezel),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            _screen(padding: EdgeInsets.only(top: statusBar)),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: statusBar,
              child: _StatusBar(device: device),
            ),
            if (isAndroid)
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            if (isPhone)
              Positioned(
                top: 11,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 124,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _window() {
    final dark = brightness == Brightness.dark;
    final isMac = device == StoreDevice.mac;
    final titleBar = isMac ? 30.0 : 34.0;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isMac ? 12 : 8),
        border: Border.all(
          color: dark ? const Color(0xFF4A4A4A) : const Color(0xFFBDBDBD),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 50,
            offset: Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: device.appSize.width,
            height: titleBar,
            child: isMac
                ? _MacTitleBar(dark: dark)
                : _WindowsTitleBar(dark: dark),
          ),
          _screen(padding: EdgeInsets.zero),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final StoreDevice device;

  const _StatusBar({required this.device});

  @override
  Widget build(BuildContext context) {
    final isPhone = device == StoreDevice.iphone;
    final isAndroid = device == StoreDevice.android;
    final style = TextStyle(
      fontFamily: isAndroid ? 'Roboto' : 'Inter',
      fontWeight: isAndroid ? FontWeight.w500 : FontWeight.w600,
      fontSize: isAndroid ? 14 : 17,
      color: Colors.white,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isPhone ? 44 : 24,
        isPhone ? 18 : (isAndroid ? 9 : 6),
        isPhone ? 34 : 24,
        0,
      ),
      child: Row(
        children: [
          Text(isAndroid ? '12:30' : '9:41', style: style),
          const Spacer(),
          for (final icon in [
            Icons.wifi,
            Icons.signal_cellular_alt,
            isAndroid ? Icons.battery_5_bar : Icons.battery_full,
          ])
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Icon(icon, size: isAndroid ? 16 : 19, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

class _MacTitleBar extends StatelessWidget {
  final bool dark;

  const _MacTitleBar({required this.dark});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFECECEC),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 12,
            child: Row(
              children: [
                for (final color in const [
                  Color(0xFFFF5F57),
                  Color(0xFFFEBC2E),
                  Color(0xFF28C840),
                ])
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            'Network Barcode Scanner',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: dark ? const Color(0xFFDDDDDD) : const Color(0xFF4D4D4D),
            ),
          ),
        ],
      ),
    );
  }
}

class _WindowsTitleBar extends StatelessWidget {
  final bool dark;

  const _WindowsTitleBar({required this.dark});

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? const Color(0xFFEEEEEE) : const Color(0xFF1B1B1B);
    return ColoredBox(
      color: dark ? const Color(0xFF202020) : const Color(0xFFF3F3F3),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.qr_code_scanner, size: 16, color: brandColor),
          const SizedBox(width: 10),
          Text(
            'Network Barcode Scanner',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              color: foreground,
            ),
          ),
          const Spacer(),
          for (final icon in [Icons.remove, Icons.crop_square, Icons.close])
            SizedBox(width: 46, child: Icon(icon, size: 16, color: foreground)),
        ],
      ),
    );
  }
}

/// A shipping label with a barcode on a warm, out-of-focus backdrop, in place
/// of a camera image. The label sits in the scanner's scan window.
class CameraBackdrop extends StatelessWidget {
  final String code;

  const CameraBackdrop({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    final window = Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(const Offset(0, -100)),
      width: 300,
      height: 200,
    );
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.1,
                colors: [
                  Color(0xFF8D6E52),
                  Color(0xFF4E3B2C),
                  Color(0xFF231A13),
                ],
              ),
            ),
          ),
        ),
        Positioned.fromRect(
          rect: window.deflate(22),
          child: Transform.rotate(
            angle: -0.04,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F0),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x88000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _BarcodePainter(code),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    code,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      letterSpacing: 2,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BarcodePainter extends CustomPainter {
  final String code;

  const _BarcodePainter(this.code);

  @override
  void paint(Canvas canvas, Size size) {
    // Bars from the digits, so the same code always draws the same barcode
    final random = Random(code.hashCode);
    final widths = [for (var i = 0; i < 60; i++) 1 + random.nextInt(3)];
    final unit = size.width / widths.fold(0, (a, b) => a + b);
    final paint = Paint()..color = Colors.black;
    var x = 0.0;
    for (var i = 0; i < widths.length; i++) {
      final w = widths[i] * unit;
      if (i.isEven) canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      x += w;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => old.code != code;
}

/// Google Play's feature graphic: icon, name and tagline on the brand
/// background, 1024 x 500.
class FeatureGraphic extends StatelessWidget {
  final ImageProvider icon;
  final String tagline;

  const FeatureGraphic({super.key, required this.icon, required this.tagline});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1024,
      height: 500,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF14B8A6), Color(0xFF0F5F63)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 72),
          child: Row(
            children: [
              // Shadow and a light rim, or the icon's gradient melts into the
              // background, which is the same gradient
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(52),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 30,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(49),
                  child: Image(image: icon, width: 230, height: 230),
                ),
              ),
              const SizedBox(width: 56),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Network Barcode Scanner',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 54,
                        height: 1.1,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      tagline,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 28,
                        height: 1.3,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
