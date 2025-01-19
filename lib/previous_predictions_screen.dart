import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:just_audio/just_audio.dart';

class PreviousPredictionsScreen extends StatefulWidget {
  @override
  _PreviousPredictionsScreenState createState() =>
      _PreviousPredictionsScreenState();
}

class _PreviousPredictionsScreenState extends State<PreviousPredictionsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseStorage storage = FirebaseStorage.instance;

  String? _playingAudioUrl; // To track which audio is currently playing

  @override
  void initState() {
    super.initState();
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed ||
          !state.playing) {
        setState(() {
          _playingAudioUrl = null; // Reset when audio is finished or paused
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Previous Predictions'),
      ),
      drawer: _buildDrawer(context),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('predictions')
            .doc(_auth.currentUser!.uid)
            .collection('userPredictions')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No predictions found.'));
          }

          List<Map<String, dynamic>> dataList = snapshot.data!.docs
              .map((DocumentSnapshot document) =>
          document.data() as Map<String, dynamic>)
              .toList();

          return ListView.builder(
            itemCount: dataList.length,
            itemBuilder: (context, index) {
              return _buildPatientPredictionItem(dataList[index], context);
            },
          );
        },
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
          _buildDrawerItem(context, Icons.home, 'Home', '/dashboard'),
          _buildDrawerItem(context, Icons.analytics, 'Predict', '/dl_fft'),
          _buildDrawerItem(context, Icons.info, 'About FFT Spectrograms',
              '/about_fft_spectrograms'),
          _buildDrawerItem(context, Icons.info, 'About Mel Spectrograms',
              '/about_mel_spectrograms'),
          _buildDrawerItem(context, Icons.history, 'Previous Predictions',
              '/previous_predictions'),
          _buildDrawerItem(context, Icons.edit, 'Edit Profile', '/edit_profile'),
          _buildDrawerItem(
              context, Icons.lock, 'Change Password', '/change_password'),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Logout'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }

  ListTile _buildDrawerItem(BuildContext context, IconData icon, String title,
      String route) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pushNamed(context, route);
      },
    );
  }

  Widget _buildPatientPredictionItem(
      Map<String, dynamic> data, BuildContext context) {
    String patientId = data['patientId'] ?? 'Unknown Patient';
    List<dynamic> predictions = data['predictions'] ?? [];
    String audioUrl = data['audioUrl'] ?? '';
    Timestamp timestamp = data['timestamp'] ?? Timestamp.now();

    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        title: Text('Patient ID: $patientId'),
        subtitle: Text('Timestamp: ${timestamp.toDate()}'),
        trailing: IconButton(
          icon: Icon(
            _playingAudioUrl == audioUrl
                ? Icons.pause_circle_filled
                : Icons.play_circle_fill,
          ),
          onPressed: () {
            if (_playingAudioUrl == audioUrl) {
              _pauseAudio();
            } else {
              _playAudio(audioUrl);
            }
          },
        ),
        children: predictions.map<Widget>((prediction) {
          String model = prediction['endpoint'] ?? 'Unknown Model';
          String pred = prediction['prediction'] ?? 'No Prediction';

          return ListTile(
            title: Text('Model: $model'),
            subtitle: Text('Prediction: $pred'),
            onTap: () {
              // Implement detailed view or additional actions
            },
          );
        }).toList(),
      ),
    );
  }

  Future<void> _playAudio(String audioUrl) async {
    try {
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();
      setState(() {
        _playingAudioUrl = audioUrl;
      });
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  void _pauseAudio() {
    _audioPlayer.pause();
    setState(() {
      _playingAudioUrl = null;
    });
  }
}
