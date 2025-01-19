import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FFTSpectrogramsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('About FFT Spectrograms'),
      ),
      drawer: _buildDrawer(context), // Drawer implementation
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FFT Spectrograms',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'FFT (Fast Fourier Transform) spectrograms are visual representations of audio signals transformed from the time domain to the frequency domain. They provide detailed insights into the frequency components present in the audio signal over time.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              'How Audio is Transformed with FFT:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              '- **Digital Audio**: Audio files (e.g., MP3, WAV) are loaded and represented as waveforms in the time domain.',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              '- **Windowing**: The signal is segmented into frames using windowing functions (e.g., Hamming window) to reduce spectral leakage.',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              '- **FFT Calculation**: Fast Fourier Transform (FFT) algorithms compute the frequency components of each frame, converting it into the frequency domain.',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              '- **Frequency Representation**: FFT produces a spectrum showing the amplitude of different frequency components. These are typically displayed in frequency bins.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              'Applications of FFT Spectrograms:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              '- **Audio Classification**: Identifying and categorizing audio based on its frequency characteristics.',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              '- **Speech Recognition**: Analyzing spoken words by their frequency patterns.',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              '- **Music Analysis**: Extracting musical features such as pitch, timbre, and rhythm.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),

          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: Center(
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text('Home'),
            onTap: () {
              Navigator.pushNamed(context, '/dashboard');
            },
          ),
          ListTile(
            leading: Icon(Icons.analytics),
            title: Text('Predict'),
            onTap: () {
              Navigator.pushNamed(context, '/dl_fft');
            },
          ),
          ListTile(
            leading: Icon(Icons.info),
            title: Text('About FFT Spectrograms'),
            onTap: () {
              Navigator.pushNamed(context, '/about_fft_spectrograms');
            },
          ),
          ListTile(
            leading: Icon(Icons.info),
            title: Text('About Mel Spectrograms'),
            onTap: () {
              Navigator.pushNamed(context, '/about_mel_spectrograms');
            },
          ),
          ListTile(
            leading: Icon(Icons.history),
            title: Text('Previous Predictions'),
            onTap: () {
              Navigator.pushNamed(context, '/previous_predictions');
            },
          ),

          ListTile(
            leading: Icon(Icons.edit),
            title: Text('Edit Profile'),
            onTap: () {
              Navigator.pushNamed(context, '/edit_profile');
            },
          ),
          ListTile(
            leading: Icon(Icons.lock),
            title: Text('Change Password'),
            onTap: () {
              Navigator.pushNamed(context, '/change_password');
            },
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Logout'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}
