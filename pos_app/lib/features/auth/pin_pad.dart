import 'package:flutter/material.dart';

/// Keypad angka custom untuk PIN: grid 3x4, tanpa TextField/keyboard sistem.
/// `onChanged` dipanggil setiap digit berubah. Indikator 6 titik + tombol
/// hapus. Tombol konfirmasi tetap milik layar pemanggil (Key lama dijaga).
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onChanged, this.length = 6});

  final ValueChanged<String> onChanged;
  final int length;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  var _pin = '';

  void _input(String digit) {
    if (_pin.length >= widget.length) return;
    setState(() => _pin += digit);
    widget.onChanged(_pin);
  }

  void _delete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
    widget.onChanged(_pin);
  }

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  i < _pin.length
                      ? Icons.circle
                      : Icons.circle_outlined,
                  key: Key('pinIndicator-$i'),
                  size: 16,
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.2,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final k = keys[index];
              if (k.isEmpty) return const SizedBox.shrink();
              if (k == 'del') {
                return IconButton(
                  key: const Key('pinKey-delete'),
                  icon: const Icon(Icons.backspace_outlined),
                  onPressed: _delete,
                );
              }
              return TextButton(
                key: Key('pinKey-$k'),
                onPressed: () => _input(k),
                child: Text(
                  k,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              );
            },
          ),
      ],
    );
  }
}
