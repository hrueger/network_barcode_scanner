import 'package:flutter/material.dart';

import '../services/mac_keyboard_service.dart';

/// Takes over the listener on macOS while auto-type is on but the app may not
/// post keystrokes yet, so received codes never get silently dropped.
class AutoTypePermissionView extends StatelessWidget {
  final MacKeyboardService keyboard;
  final VoidCallback onDisableAutoType;

  const AutoTypePermissionView({
    super.key,
    required this.keyboard,
    required this.onDisableAutoType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.keyboard, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Allow auto-type',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Auto-type is on. To type received codes into other apps, '
                'macOS has to let this app send keystrokes.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _Step(
                number: 1,
                text: 'Allow the app to send keystrokes.',
                action: FilledButton(
                  onPressed: keyboard.requestPostEvents,
                  child: const Text('Allow'),
                ),
              ),
              const SizedBox(height: 8),
              _Step(
                number: 2,
                text: 'macOS applies the permission after a restart.',
                action: FilledButton(
                  onPressed: keyboard.relaunch,
                  child: const Text('Restart app'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No prompt appeared? Turn the app on in System Settings, then '
                'restart it.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              TextButton(
                onPressed: keyboard.openSettings,
                child: const Text('Open System Settings'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onDisableAutoType,
                child: const Text('Turn off auto-type instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;
  final Widget action;

  const _Step({required this.number, required this.text, required this.action});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(radius: 14, child: Text('$number')),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
            const SizedBox(width: 8),
            action,
          ],
        ),
      ),
    );
  }
}
