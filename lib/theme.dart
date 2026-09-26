import 'package:flutter/material.dart';

/// Petrol, the background of the app icon
const Color brandColor = Color(0xFF0F766E);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: brandColor,
    brightness: brightness,
  );
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? scheme.surfaceContainerHigh : scheme.primary,
      foregroundColor: isDark ? scheme.onSurface : scheme.onPrimary,
    ),
    extensions: [isDark ? StatusColors.dark : StatusColors.light],
  );
}

enum Status { success, warning, danger }

/// Green / amber / red for status bars and snack bars. The Material scheme
/// only has an error role, and these must stay readable in both modes.
class StatusColors extends ThemeExtension<StatusColors> {
  final Map<Status, Color> solid;
  final Map<Status, Color> container;
  final Map<Status, Color> onContainer;

  const StatusColors({
    required this.solid,
    required this.container,
    required this.onContainer,
  });

  static const light = StatusColors(
    solid: {
      Status.success: Color(0xFF15803D),
      Status.warning: Color(0xFFB45309),
      Status.danger: Color(0xFFB91C1C),
    },
    container: {
      Status.success: Color(0xFFDCFCE7),
      Status.warning: Color(0xFFFEF3C7),
      Status.danger: Color(0xFFFEE2E2),
    },
    onContainer: {
      Status.success: Color(0xFF14532D),
      Status.warning: Color(0xFF78350F),
      Status.danger: Color(0xFF7F1D1D),
    },
  );

  static const dark = StatusColors(
    solid: {
      Status.success: Color(0xFF15803D),
      Status.warning: Color(0xFFB45309),
      Status.danger: Color(0xFFB91C1C),
    },
    container: {
      Status.success: Color(0xFF14352A),
      Status.warning: Color(0xFF3D2A0E),
      Status.danger: Color(0xFF3F1616),
    },
    onContainer: {
      Status.success: Color(0xFF86EFAC),
      Status.warning: Color(0xFFFCD34D),
      Status.danger: Color(0xFFFCA5A5),
    },
  );

  static StatusColors of(BuildContext context) =>
      Theme.of(context).extension<StatusColors>()!;

  @override
  StatusColors copyWith({
    Map<Status, Color>? solid,
    Map<Status, Color>? container,
    Map<Status, Color>? onContainer,
  }) => StatusColors(
    solid: solid ?? this.solid,
    container: container ?? this.container,
    onContainer: onContainer ?? this.onContainer,
  );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    Map<Status, Color> mix(Map<Status, Color> a, Map<Status, Color> b) => {
      for (final s in Status.values) s: Color.lerp(a[s], b[s], t)!,
    };
    return StatusColors(
      solid: mix(solid, other.solid),
      container: mix(container, other.container),
      onContainer: mix(onContainer, other.onContainer),
    );
  }
}

/// A snack bar in a status colour, with text that stays readable on it in
/// light and dark mode alike.
SnackBar statusSnackBar(
  BuildContext context,
  String message,
  Status status, {
  Duration duration = const Duration(seconds: 4),
}) {
  return SnackBar(
    content: Text(message, style: const TextStyle(color: Colors.white)),
    backgroundColor: StatusColors.of(context).solid[status],
    duration: duration,
  );
}

/// A coloured bar across the top of a screen, like "Listening for codes..."
class StatusBanner extends StatelessWidget {
  final Status status;
  final IconData icon;
  final String text;

  const StatusBanner({
    super.key,
    required this.status,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    final foreground = colors.onContainer[status];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: colors.container[status],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontWeight: FontWeight.bold, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
