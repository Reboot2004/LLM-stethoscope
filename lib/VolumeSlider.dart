import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class VolumeSlider extends StatefulWidget {
  final AudioPlayer player;

  const VolumeSlider({Key? key, required this.player}) : super(key: key);

  @override
  _VolumeSliderState createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider> {
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    widget.player.setVolume(_volume);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Volume'),
        Slider(
          value: _volume,
          onChanged: (value) {
            setState(() {
              _volume = value;
            });
            widget.player.setVolume(_volume);
          },
          min: 0.0,
          max: 1.0,
          divisions: 10,
          label: '$_volume',
        ),
      ],
    );
  }
}
