import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../l10n/strings.dart';
import '../services/app_services.dart';
import '../services/equalizer_service.dart';

/// Ecualizador: encender/apagar, ajustes predefinidos y bandas a mano.
class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  @override
  void initState() {
    super.initState();
    // Las bandas solo existen si ya se cargó música.
    if (widget.services.player.current != null) widget.services.equalizer.attach();
  }

  String _presetName(S s, EqPreset p) => switch (p) {
        EqPreset.normal => s.eqNormal,
        EqPreset.bass => s.eqBass,
        EqPreset.pop => 'Pop',
        EqPreset.rock => 'Rock',
        EqPreset.jazz => 'Jazz',
        EqPreset.classical => s.eqClassical,
        EqPreset.electronic => s.eqElectronic,
        EqPreset.vocal => s.eqVocal,
        EqPreset.custom => s.eqCustom,
      };

  static String _frequency(double hz) =>
      hz >= 1000 ? '${(hz / 1000).toStringAsFixed(hz >= 10000 ? 0 : 1)} kHz' : '${hz.round()} Hz';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final eq = widget.services.equalizer;
    return Scaffold(
      appBar: AppBar(title: Text(s.equalizer)),
      body: ListenableBuilder(
        listenable: eq,
        builder: (context, _) {
          final params = eq.parameters;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              SwitchListTile(
                title: Text(s.equalizerOn),
                subtitle: Text(s.equalizerHint),
                value: eq.enabled,
                onChanged: eq.setEnabled,
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in EqPreset.values)
                      if (p != EqPreset.custom || eq.preset == EqPreset.custom)
                        ChoiceChip(
                          label: Text(_presetName(s, p)),
                          selected: eq.preset == p,
                          onSelected: eq.enabled ? (_) => eq.applyPreset(p) : null,
                        ),
                  ],
                ),
              ),
              if (params == null)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(s.equalizerNeedsMusic, textAlign: TextAlign.center),
                )
              else
                _bands(params, eq),
            ],
          );
        },
      ),
    );
  }

  Widget _bands(AndroidEqualizerParameters params, EqualizerService eq) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 300,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < params.bands.length; i++)
            StreamBuilder<double>(
              stream: params.bands[i].gainStream,
              initialData: params.bands[i].gain,
              builder: (context, snap) {
                final gain = snap.data ?? 0;
                return Column(
                  children: [
                    Text('${gain > 0 ? '+' : ''}${gain.toStringAsFixed(1)} dB',
                        style: Theme.of(context).textTheme.labelSmall),
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Slider(
                          min: params.minDecibels,
                          max: params.maxDecibels,
                          value: gain.clamp(params.minDecibels, params.maxDecibels),
                          activeColor: eq.enabled ? scheme.primary : scheme.outline,
                          onChanged: eq.enabled ? (v) => eq.setBandGain(i, v) : null,
                        ),
                      ),
                    ),
                    Text(_frequency(params.bands[i].centerFrequency), style: Theme.of(context).textTheme.labelSmall),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
