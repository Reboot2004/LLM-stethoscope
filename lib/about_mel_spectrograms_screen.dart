import 'package:flutter/material.dart';

class MelSpectrogramsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('About Mel Spectrograms'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mel Spectrograms',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Mel (Mel-frequency cepstral coefficients) spectrograms are derived from FFT spectrograms and are mapped to the Mel scale, which approximates the human auditory system\'s response to different frequencies. They are commonly used in speech and audio processing for feature extraction and analysis.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              'Applications:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              '- Speech recognition',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              '- Speaker identification',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              '- Emotion detection in speech',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
