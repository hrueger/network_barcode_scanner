import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;

  // Keys for settings
  static const String _playSoundOnScanKey = 'play_sound_on_scan';
  static const String _playSoundOnReceiveKey = 'play_sound_on_receive';
  static const String _duplicateWaitTimeKey = 'duplicate_wait_time';
  static const String _ignoreSeenCodesKey = 'ignore_seen_codes';
  static const String _autoTypeOnReceiveKey = 'auto_type_on_receive';
  static const String _autoTypeEndKeyKey = 'auto_type_end_key';
  static const String _scanInputModeKey = 'scan_input_mode';
  static const String _scanBroadcastActionKey = 'scan_broadcast_action';
  static const String _scanBroadcastExtraKey = 'scan_broadcast_extra';
  static const String _hardwareScanSeenKey = 'hardware_scan_seen';

  // Default values
  static const bool _defaultPlaySoundOnScan = true;
  static const bool _defaultPlaySoundOnReceive = true;
  static const int _defaultDuplicateWaitTime = 2; // seconds
  static const bool _defaultIgnoreSeenCodes = false;
  static const bool _defaultAutoTypeOnReceive = false;
  static const String _defaultAutoTypeEndKey =
      'enter'; // 'enter', 'tab', 'none'
  static const String _defaultScanInputMode =
      'auto'; // 'auto', 'hardware', 'camera'
  // Chainway (rscja) scanner service defaults; other PDA firmwares differ.
  static const String _defaultScanBroadcastAction = 'com.scanner.broadcast';
  static const String _defaultScanBroadcastExtra = 'data';

  // Initialize shared preferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Getters
  bool get playSoundOnScan =>
      _prefs?.getBool(_playSoundOnScanKey) ?? _defaultPlaySoundOnScan;

  bool get playSoundOnReceive =>
      _prefs?.getBool(_playSoundOnReceiveKey) ?? _defaultPlaySoundOnReceive;

  int get duplicateWaitTime =>
      _prefs?.getInt(_duplicateWaitTimeKey) ?? _defaultDuplicateWaitTime;

  bool get ignoreSeenCodes =>
      _prefs?.getBool(_ignoreSeenCodesKey) ?? _defaultIgnoreSeenCodes;

  bool get autoTypeOnReceive =>
      _prefs?.getBool(_autoTypeOnReceiveKey) ?? _defaultAutoTypeOnReceive;

  String get autoTypeEndKey =>
      _prefs?.getString(_autoTypeEndKeyKey) ?? _defaultAutoTypeEndKey;

  String get scanInputMode =>
      _prefs?.getString(_scanInputModeKey) ?? _defaultScanInputMode;

  String get scanBroadcastAction =>
      _prefs?.getString(_scanBroadcastActionKey) ?? _defaultScanBroadcastAction;

  String get scanBroadcastExtra =>
      _prefs?.getString(_scanBroadcastExtraKey) ?? _defaultScanBroadcastExtra;

  /// Whether this device has ever delivered a hardware scan. Proof that it
  /// has a scan engine, independent of the known-model list.
  bool get hardwareScanSeen => _prefs?.getBool(_hardwareScanSeenKey) ?? false;

  // Setters
  Future<void> setPlaySoundOnScan(bool value) async {
    await _prefs?.setBool(_playSoundOnScanKey, value);
  }

  Future<void> setPlaySoundOnReceive(bool value) async {
    await _prefs?.setBool(_playSoundOnReceiveKey, value);
  }

  Future<void> setDuplicateWaitTime(int seconds) async {
    await _prefs?.setInt(_duplicateWaitTimeKey, seconds);
  }

  Future<void> setIgnoreSeenCodes(bool value) async {
    await _prefs?.setBool(_ignoreSeenCodesKey, value);
  }

  Future<void> setAutoTypeOnReceive(bool value) async {
    await _prefs?.setBool(_autoTypeOnReceiveKey, value);
  }

  Future<void> setAutoTypeEndKey(String value) async {
    await _prefs?.setString(_autoTypeEndKeyKey, value);
  }

  Future<void> setScanInputMode(String value) async {
    await _prefs?.setString(_scanInputModeKey, value);
  }

  Future<void> setScanBroadcastAction(String value) async {
    await _prefs?.setString(_scanBroadcastActionKey, value);
  }

  Future<void> setScanBroadcastExtra(String value) async {
    await _prefs?.setString(_scanBroadcastExtraKey, value);
  }

  Future<void> setHardwareScanSeen(bool value) async {
    await _prefs?.setBool(_hardwareScanSeenKey, value);
  }

  // Reset to defaults
  Future<void> resetToDefaults() async {
    await setPlaySoundOnScan(_defaultPlaySoundOnScan);
    await setPlaySoundOnReceive(_defaultPlaySoundOnReceive);
    await setDuplicateWaitTime(_defaultDuplicateWaitTime);
    await setIgnoreSeenCodes(_defaultIgnoreSeenCodes);
    await setAutoTypeOnReceive(_defaultAutoTypeOnReceive);
    await setAutoTypeEndKey(_defaultAutoTypeEndKey);
    await setScanInputMode(_defaultScanInputMode);
    await setScanBroadcastAction(_defaultScanBroadcastAction);
    await setScanBroadcastExtra(_defaultScanBroadcastExtra);
    await setHardwareScanSeen(false);
  }
}
