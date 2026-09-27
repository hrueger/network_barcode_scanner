import 'dart:io';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../services/hardware_scanner_service.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, @visibleForTesting this.desktop});

  /// Store screenshots render on one machine for every platform; this picks
  /// the scanner (false) or listener (true) sections instead of the host OS.
  final bool? desktop;

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
  late ScanInputMode _scanInputMode;
  late String _scanBroadcastAction;
  late String _scanBroadcastExtra;
  DeviceIdentity? _device;

  bool get _isDesktop =>
      widget.desktop ??
      (Platform.isMacOS || Platform.isLinux || Platform.isWindows);

  @override
  void initState() {
    super.initState();
    _loadSettings();
    if (widget.desktop != null) return;
    HardwareScannerService().deviceInfo().then((device) {
      if (mounted) setState(() => _device = device);
    });
  }

  void _loadSettings() {
    setState(() {
      _playSoundOnScan = _settings.playSoundOnScan;
      _playSoundOnReceive = _settings.playSoundOnReceive;
      _duplicateWaitTime = _settings.duplicateWaitTime;
      _ignoreSeenCodes = _settings.ignoreSeenCodes;
      _autoTypeOnReceive = _settings.autoTypeOnReceive;
      _autoTypeEndKey = _settings.autoTypeEndKey;
      _scanInputMode = ScanInputMode.parse(_settings.scanInputMode);
      _scanBroadcastAction = _settings.scanBroadcastAction;
      _scanBroadcastExtra = _settings.scanBroadcastExtra;
    });
  }

  /// What auto mode resolves to on this device, for the picker's subtitle.
  String get _scanInputDescription {
    if (!HardwareScannerService.isSupported) return 'Camera';
    final device = _device;
    final name = device == null ? 'this device' : device.label;
    if (_settings.hardwareScanSeen) {
      return '$name has delivered hardware scans';
    }
    if (device?.isKnownPda ?? false) return '$name is a known scanner model';
    return '$name: no scan engine known, using camera';
  }

  Future<void> _editText({
    required String title,
    required String value,
    required Future<void> Function(String) onSaved,
  }) async {
    final controller = TextEditingController(text: value);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;
    await onSaved(result);
    _loadSettings();
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
          statusSnackBar(context, 'Settings reset to defaults', Status.success),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
          _SectionHeader('Sound Settings'),
          SwitchListTile(
            title: const Text('Play Sound on Scan'),
            subtitle: const Text('Play a sound when a code is scanned'),
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
          if (!_isDesktop) ...[
            const Divider(),
            _SectionHeader('Scanner Settings'),
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
            if (HardwareScannerService.isSupported) ...[
              ListTile(
                title: const Text('Scan Input'),
                subtitle: Text(_scanInputDescription),
                leading: const Icon(Icons.input),
                trailing: DropdownButton<ScanInputMode>(
                  value: _scanInputMode,
                  onChanged: (value) async {
                    if (value == null) return;
                    await _settings.setScanInputMode(value.name);
                    setState(() {
                      _scanInputMode = value;
                    });
                  },
                  items: const [
                    DropdownMenuItem(
                      value: ScanInputMode.auto,
                      child: Text('Automatic'),
                    ),
                    DropdownMenuItem(
                      value: ScanInputMode.hardware,
                      child: Text('Hardware trigger'),
                    ),
                    DropdownMenuItem(
                      value: ScanInputMode.camera,
                      child: Text('Camera'),
                    ),
                  ],
                ),
              ),
              if (_scanInputMode != ScanInputMode.camera) ...[
                ListTile(
                  title: const Text('Broadcast Action'),
                  subtitle: Text(
                    '$_scanBroadcastAction\nThe Intent action the scanner service sends',
                  ),
                  leading: const Icon(Icons.settings_input_antenna),
                  onTap: () => _editText(
                    title: 'Broadcast Action',
                    value: _scanBroadcastAction,
                    onSaved: _settings.setScanBroadcastAction,
                  ),
                ),
                ListTile(
                  title: const Text('Broadcast Extra Key'),
                  subtitle: Text(
                    '$_scanBroadcastExtra\nThe Intent extra holding the decoded text',
                  ),
                  leading: const Icon(Icons.key),
                  onTap: () => _editText(
                    title: 'Broadcast Extra Key',
                    value: _scanBroadcastExtra,
                    onSaved: _settings.setScanBroadcastExtra,
                  ),
                ),
              ],
            ],
            const Divider(),
          ],
          if (_isDesktop) ...[
            _SectionHeader('Listener Settings'),
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
                Text(
                  'About',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Network Barcode Scanner v1.0.0',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan barcodes and type them on a computer over your local network',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
