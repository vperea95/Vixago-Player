import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ajustes predefinidos, en decibeles, para 5 bandas (graves -> agudos).
/// Si el celular tiene otra cantidad de bandas, se interpolan.
enum EqPreset {
  normal([0, 0, 0, 0, 0]),
  bass([6, 4, 0, 0, 0]),
  pop([-1, 2, 4, 2, -1]),
  rock([4, 2, -2, 2, 4]),
  jazz([3, 1, -1, 1, 3]),
  classical([4, 2, -1, 2, 4]),
  electronic([5, 3, 0, 2, 5]),
  vocal([-2, 0, 3, 3, 1]),
  custom([0, 0, 0, 0, 0]);

  const EqPreset(this.gains);
  final List<double> gains;
}

/// Ecualizador de Android (a través de just_audio). Recuerda el ajuste elegido.
/// Sus parámetros (bandas) solo existen cuando ya se cargó una canción.
class EqualizerService extends ChangeNotifier {
  static const _enabledKey = 'eq_enabled';
  static const _presetKey = 'eq_preset';
  static const _gainsKey = 'eq_gains';

  final AndroidEqualizer effect = AndroidEqualizer();
  SharedPreferences? _prefs;

  bool enabled = false;
  EqPreset preset = EqPreset.normal;
  List<double> _savedGains = const [];

  AndroidEqualizerParameters? parameters;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    enabled = _prefs!.getBool(_enabledKey) ?? false;
    preset = EqPreset.values.firstWhere(
      (p) => p.name == _prefs!.getString(_presetKey),
      orElse: () => EqPreset.normal,
    );
    _savedGains = (_prefs!.getStringList(_gainsKey) ?? const []).map(double.tryParse).whereType<double>().toList();
  }

  /// Se llama cuando el reproductor carga música: aplica el ajuste guardado.
  Future<void> attach() async {
    if (parameters != null) return;
    try {
      final params = await effect.parameters.timeout(const Duration(seconds: 5));
      parameters = params;
      final gains = _savedGains.length == params.bands.length ? _savedGains : _gainsFor(preset, params);
      for (var i = 0; i < params.bands.length; i++) {
        await params.bands[i].setGain(_clamp(gains[i], params));
      }
      await effect.setEnabled(enabled);
      notifyListeners();
    } catch (e) {
      debugPrint('Ecualizador no disponible: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    notifyListeners();
    await effect.setEnabled(value);
    await _prefs?.setBool(_enabledKey, value);
  }

  Future<void> applyPreset(EqPreset value) async {
    preset = value;
    final params = parameters;
    if (params != null && value != EqPreset.custom) {
      final gains = _gainsFor(value, params);
      for (var i = 0; i < params.bands.length; i++) {
        await params.bands[i].setGain(gains[i]);
      }
      await _saveGains();
    }
    notifyListeners();
    await _prefs?.setString(_presetKey, value.name);
  }

  /// El usuario movió una banda a mano: pasa a "Personalizado".
  Future<void> setBandGain(int index, double gain) async {
    final params = parameters;
    if (params == null) return;
    await params.bands[index].setGain(_clamp(gain, params));
    if (preset != EqPreset.custom) {
      preset = EqPreset.custom;
      await _prefs?.setString(_presetKey, preset.name);
    }
    notifyListeners();
    await _saveGains();
  }

  Future<void> _saveGains() async {
    final params = parameters;
    if (params == null) return;
    _savedGains = params.bands.map((b) => b.gain).toList();
    await _prefs?.setStringList(_gainsKey, _savedGains.map((g) => g.toStringAsFixed(2)).toList());
  }

  static double _clamp(double gain, AndroidEqualizerParameters p) =>
      gain.clamp(p.minDecibels, p.maxDecibels).toDouble();

  static List<double> _gainsFor(EqPreset preset, AndroidEqualizerParameters p) {
    final n = p.bands.length;
    final src = preset.gains;
    return List.generate(n, (i) {
      if (n == 1) return _clamp(src[src.length ~/ 2], p);
      final pos = i * (src.length - 1) / (n - 1);
      final lo = pos.floor();
      final hi = pos.ceil();
      final value = src[lo] + (src[hi] - src[lo]) * (pos - lo);
      return _clamp(value, p);
    });
  }
}
