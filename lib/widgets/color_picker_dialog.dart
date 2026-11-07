import 'package:flutter/material.dart';
import 'package:timelyr/theme/app_theme.dart';

/// HSV color picker with a hex field. Returns the chosen color, or null if
/// cancelled.
Future<Color?> showColorPickerDialog(
  BuildContext context, {
  required Color initial,
  String title = 'Pick a color',
}) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _ColorPickerDialog(initial: initial, title: title),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initial;
  final String title;

  const _ColorPickerDialog({required this.initial, required this.title});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv;
  late final TextEditingController _hex;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
    _hex = TextEditingController(text: _hexOf(_hsv.toColor()));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  static String _hexOf(Color c) {
    final rgb = c.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  void _setHsv(HSVColor value) {
    setState(() {
      _hsv = value;
      _hex.text = _hexOf(value.toColor());
    });
  }

  void _onHexChanged(String text) {
    var t = text.trim().replaceAll('#', '');
    if (t.length != 6) return;
    final parsed = int.tryParse(t, radix: 16);
    if (parsed == null) return;
    setState(() => _hsv = HSVColor.fromColor(Color(0xFF000000 | parsed)));
  }

  Widget _gradientSlider({
    required String label,
    required double value,
    required double max,
    required List<Color> colors,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        SizedBox(
          height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(colors: colors),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 12,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white24,
                ),
                child: Slider(
                  value: value.clamp(0.0, max),
                  min: 0,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return AlertDialog(
      backgroundColor: AppTheme.background,
      title: Text(widget.title, style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
            ),
            const SizedBox(height: 12),
            _gradientSlider(
              label: 'Hue',
              value: _hsv.hue,
              max: 360,
              colors: [
                for (var h = 0; h <= 360; h += 60)
                  HSVColor.fromAHSV(1, h.toDouble() % 360, 1, 1).toColor(),
              ],
              onChanged: (v) => _setHsv(_hsv.withHue(v)),
            ),
            _gradientSlider(
              label: 'Saturation',
              value: _hsv.saturation,
              max: 1,
              colors: [
                HSVColor.fromAHSV(1, _hsv.hue, 0, _hsv.value).toColor(),
                HSVColor.fromAHSV(1, _hsv.hue, 1, _hsv.value).toColor(),
              ],
              onChanged: (v) => _setHsv(_hsv.withSaturation(v)),
            ),
            _gradientSlider(
              label: 'Brightness',
              value: _hsv.value,
              max: 1,
              colors: [
                Colors.black,
                HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 1).toColor(),
              ],
              onChanged: (v) => _setHsv(_hsv.withValue(v)),
            ),
            TextField(
              controller: _hex,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Hex',
                labelStyle: TextStyle(color: Colors.white70),
              ),
              onChanged: _onHexChanged,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(color),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
          child: const Text('Select', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
