import 'dart:io';

import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();
  late bool _playSoundOnScan;
  late bool _playSoundOnReceive;
  late int _duplicateWaitTime;
  late bool _ignoreSeenCodes;
  late bool _autoTypeOnReceive;
  late String _autoTypeEndKey;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _playSoundOnScan = _settings.playSoundOnScan;
      _playSoundOnReceive = _settings.playSoundOnReceive;
      _duplicateWaitTime = _settings.duplicateWaitTime;
      _ignoreSeenCodes = _settings.ignoreSeenCodes;
      _autoTypeOnReceive = _settings.autoTypeOnReceive;
      _autoTypeEndKey = _settings.autoTypeEndKey;
    });
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'Are you sure you want to reset all settings to their default values?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _settings.resetToDefaults();
      _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings reset to defaults'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _resetToDefaults,
            tooltip: 'Reset to defaults',
          ),
        ],
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Sound Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Play Sound on Scan'),
            subtitle: const Text('Play a sound when a QR code is scanned'),
            value: _playSoundOnScan,
            onChanged: (value) async {
              await _settings.setPlaySoundOnScan(value);
              setState(() {
                _playSoundOnScan = value;
              });
            },
            secondary: const Icon(Icons.volume_up),
          ),
          SwitchListTile(
            title: const Text('Play Sound on Receive'),
            subtitle: const Text('Play a sound when a code is received'),
            value: _playSoundOnReceive,
            onChanged: (value) async {
              await _settings.setPlaySoundOnReceive(value);
              setState(() {
                _playSoundOnReceive = value;
              });
            },
            secondary: const Icon(Icons.notifications_active),
          ),
          if (Platform.isAndroid || Platform.isIOS) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Scanner Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            ListTile(
              title: const Text('Duplicate Wait Time'),
              subtitle: Text(
                'How long to wait before scanning the same code again: $_duplicateWaitTime seconds',
              ),
              leading: const Icon(Icons.timer),
              trailing: SizedBox(
                width: 200,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('$_duplicateWaitTime s'),
                    Expanded(
                      child: Slider(
                        value: _duplicateWaitTime.toDouble(),
                        min: 0,
                        max: 10,
                        divisions: 10,
                        label: '$_duplicateWaitTime s',
                        onChanged: (value) {
                          setState(() {
                            _duplicateWaitTime = value.toInt();
                          });
                        },
                        onChangeEnd: (value) async {
                          await _settings.setDuplicateWaitTime(value.toInt());
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SwitchListTile(
              title: const Text('Ignore Seen Codes Until Restart'),
              subtitle: const Text(
                'Once a code is scanned, it cannot be scanned again until the app is restarted',
              ),
              value: _ignoreSeenCodes,
              onChanged: (value) async {
                await _settings.setIgnoreSeenCodes(value);
                setState(() {
                  _ignoreSeenCodes = value;
                });
              },
              secondary: const Icon(Icons.block),
            ),
            const Divider(),
          ],
          if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) ...[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Listener Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            SwitchListTile(
              title: const Text('Auto-Type on Receive'),
              value: _autoTypeOnReceive,
              onChanged: (value) async {
                await _settings.setAutoTypeOnReceive(value);
                setState(() {
                  _autoTypeOnReceive = value;
                });
              },
              secondary: Icon(Icons.keyboard),
            ),
            ListTile(
              title: const Text('Auto-Type End Key'),
              subtitle: const Text('Key pressed after typing the code'),
              leading: const Icon(Icons.keyboard_return),
              trailing: DropdownButton<String>(
                value: _autoTypeEndKey,
                onChanged: _autoTypeOnReceive
                    ? (value) async {
                        if (value != null) {
                          await _settings.setAutoTypeEndKey(value);
                          setState(() {
                            _autoTypeEndKey = value;
                          });
                        }
                      }
                    : null,
                items: const [
                  DropdownMenuItem(value: 'enter', child: Text('Enter')),
                  DropdownMenuItem(value: 'tab', child: Text('Tab')),
                  DropdownMenuItem(value: 'none', child: Text('None')),
                ],
              ),
            ),
            const Divider(),
          ],
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Network QR Scanner v1.0.0',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan and share QR codes over your local network',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
