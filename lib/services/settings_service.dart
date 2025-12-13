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

  // Default values
  static const bool _defaultPlaySoundOnScan = true;
  static const bool _defaultPlaySoundOnReceive = true;
  static const int _defaultDuplicateWaitTime = 2; // seconds
  static const bool _defaultIgnoreSeenCodes = false;
  static const bool _defaultAutoTypeOnReceive = false;

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

  // Reset to defaults
  Future<void> resetToDefaults() async {
    await setPlaySoundOnScan(_defaultPlaySoundOnScan);
    await setPlaySoundOnReceive(_defaultPlaySoundOnReceive);
    await setDuplicateWaitTime(_defaultDuplicateWaitTime);
    await setIgnoreSeenCodes(_defaultIgnoreSeenCodes);
    await setAutoTypeOnReceive(_defaultAutoTypeOnReceive);
  }
}
