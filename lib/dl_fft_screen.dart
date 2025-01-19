import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:http_parser/http_parser.dart';

class DLWithFFTScreen extends StatefulWidget {
  @override
  _DLWithFFTScreenState createState() => _DLWithFFTScreenState();
}

class _DLWithFFTScreenState extends State<DLWithFFTScreen> {
  String prediction = '';
  String groundTruth = ''; // Ground truth value received from server
  bool _showGroundTruth = false;
  bool _userFileSelected = false;
  File? _userAudioFile;
  bool _isLoading = false;
  String flaskServerUrl = '';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_storage.FirebaseStorage _storage =
      firebase_storage.FirebaseStorage.instance;
  Set<String> selectedEndpoints = Set<String>();

  final List<AudioFile> audioFiles = [
    AudioFile(name: 'Audio 1', groundTruth: 'URTI'),
    AudioFile(name: 'Audio 2', groundTruth: 'Healthy'),
    AudioFile(name: 'Audio 3', groundTruth: 'Pneumonia'),
  ];
 final Map<String,String> gt= {
   'Audio 1' : 'URTI',
   'Audio 2' : "Healthy",
   'Audio 3' : "Penumonia"
 };
  final Map<String, String> endpointMapping = {
    'FFT_Spectrogram': 'FFT Spectrogram',
    'Mel_Spectrogram': 'Mel Spectrogram',
    'LLM_Mel': 'LLM Mel',
    'LLM_FFT': 'LLM FFT',
  };

  final List<String> endpoints = [
    'FFT_Spectrogram',
    'Mel_Spectrogram',
    'LLM_Mel',
    'LLM_FFT',
  ];

  String? selectedEndpoint;
  TextEditingController patientIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startFlaskServer();
  }

  void _startFlaskServer() async {
    var result = await Process.run('python', ['Flask_1.py']);
    if (result.exitCode == 0) {
      print('Flask server started successfully');
    } else {
      print('Failed to start Flask server: ${result.stderr}');
    }
  }

  Future<File> _getAssetFile(String assetName) async {
    final byteData =
    await rootBundle.load('assets/$assetName.wav');
    final file = File(
        '${(await getTemporaryDirectory()).path}/$assetName.wav');
    await file.writeAsBytes(
        byteData.buffer.asUint8List(byteData.offsetInBytes,
            byteData.lengthInBytes));
    return file;
  }

  Future<void> _processAudio(File audioFile, String patientId) async {
    if (selectedEndpoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one endpoint'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    List<Map<String, dynamic>> predictions = [];

    try {
      final bytes = await audioFile.readAsBytes();
      List<String> selectedEndpointsList = selectedEndpoints.toList();

      for (String endpoint in selectedEndpointsList) {
        var request = http.MultipartRequest(
          'POST',
         // Uri.parse('http://192.168.0.195:1000/$endpoint'),
            Uri.parse('http://192.168.59.92:1000/$endpoint'),
        );

        if (endpoint == 'LLM_Mel' || endpoint == 'LLM_FFT') {
          request.files.add(
            http.MultipartFile.fromBytes(
              'file', // Change the key to 'file' for LLM_Mel and LLM_FFT endpoints
              bytes,
              filename: '${DateTime.now().millisecondsSinceEpoch}.wav',
              contentType: MediaType('audio', 'wav'),
            ),
          );
        } else {
          request.files.add(
            http.MultipartFile.fromBytes(
              'audio', // Keep the key as 'audio' for other endpoints
              bytes,
              filename: '${DateTime.now().millisecondsSinceEpoch}.wav',
              contentType: MediaType('audio', 'wav'),
            ),
          );
        }

        var response = await request.send();

        if (response.statusCode == 200) {
          var jsonResponse = await response.stream.bytesToString();
          var data = jsonDecode(jsonResponse);

          predictions.add({
            'endpoint': endpoint,
            'prediction': data['predicted_class'] ?? '',
            'groundTruth': data['ground_truth'] ?? '',
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to process audio: ${response.reasonPhrase}'),
            ),
          );
        }
      }

      await _uploadAudioAndStorePrediction(
          audioFile, predictions, patientId);

      setState(() {
        _isLoading = false;
      });

      // Show predictions in a dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("All Predictions Completed"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var prediction in predictions)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Endpoint: ${endpointMapping[prediction['endpoint']]}"),
                      Text("Prediction: ${prediction['prediction']}"),
                      if (_showGroundTruth)
                        Text("Ground Truth: ${gt['Audio 1']}"),
                      SizedBox(
                        height: 12,
                      ),
                    ],
                  ),
              ],
            ),
            actions: [
              TextButton(
                child: Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _uploadAudioAndStorePrediction(
      File audioFile,
      List<Map<String, dynamic>> predictionData,
      String patientId) async {
    try {
      // Upload audio file to Firebase Storage
      String fileName =
          '${patientId}_${DateTime.now().millisecondsSinceEpoch}.wav';
      firebase_storage.Reference ref = _storage
          .ref()
          .child('audioFiles')
          .child(fileName);
      await ref.putFile(audioFile);
      String audioUrl = await ref.getDownloadURL();

      // Store prediction details in Firestore
      await _firestore
          .collection('predictions')
          .doc(_auth.currentUser!.uid)
          .collection('userPredictions')
          .add({
        'patientId': patientId,
        'audioUrl': audioUrl,
        'predictions': predictionData,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error uploading audio and storing prediction: $e');
    }
  }

  Future<void> _pickUserFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _userAudioFile = File(result.files.single.path!);
        _userFileSelected = true;
        _showGroundTruth = false; // Disable ground truth when user file is uploaded
      });
      patientIdController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Predictions')),
      drawer: _buildDrawer(context),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Endpoint selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Endpoint(s)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Wrap(
                    spacing: 8.0,
                    children: endpoints.map(
                          (endpoint) {
                        String displayEndpoint =
                            endpointMapping[endpoint] ?? endpoint;
                        return FilterChip(
                          label: Text(displayEndpoint),
                          selected:
                          selectedEndpoints.contains(endpoint),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                selectedEndpoints.add(endpoint);
                              } else {
                                selectedEndpoints.remove(endpoint);
                              }
                            });
                          },
                        );
                      },
                    ).toList(),
                  ),
                ],
              ),
              SizedBox(height: 16.0),
              // Predefined audio selection
              _buildPredefinedAudioSelection(),
              SizedBox(height: 16.0),
              // Upload user audio file
              _buildUserAudioUpload(),
              SizedBox(height: 16.0),
              // Patient ID input
              _buildPatientIdInput(),
              SizedBox(height: 16.0),
              // Ground Truth toggle
              if (!_userFileSelected) _buildGroundTruthToggle(),
              SizedBox(height: 16.0),
              // Process audio button
              _buildProcessAudioButton(),
              SizedBox(height: 16.0),
              // Prediction and Ground Truth display
              _buildPredictionDisplay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPredefinedAudioSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Predefined Audio',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        DropdownButton<String>(
          isExpanded: true,
          value: selectedEndpoint,
          hint: Text('Select an audio file'),
          onChanged: (String? newValue) async {
            setState(() {
              selectedEndpoint = newValue;
              _userFileSelected = false;
              _showGroundTruth = true; // Enable ground truth for predefined audio
            });
            _userAudioFile = await _getAssetFile(newValue!);
            patientIdController.clear();
          },
          items: audioFiles.map((AudioFile audio) {
            return DropdownMenuItem<String>(
              value: audio.name,
              child: Text(audio.name),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildUserAudioUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload Your Audio',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        SizedBox(height: 8.0),
        ElevatedButton(
          onPressed: () => _pickUserFile(),
          child: Text('Select Audio File'),
        ),
        // if (_userAudioFile != null)
        //   Padding(
        //     padding: const EdgeInsets.symmetric(vertical: 8.0),
        //     child: Text('Selected File: ${_userAudioFile!.path}'),
        //   ),
      ],
    );
  }

  Widget _buildPatientIdInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter Patient ID',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        SizedBox(height: 8.0),
        TextFormField(
          controller: patientIdController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            hintText: 'Patient ID',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildGroundTruthToggle() {
    return Row(
      children: [
        Text(
          'Show Ground Truth',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        SizedBox(width: 8.0),
        Switch(
          value: _showGroundTruth,
          onChanged: (_userFileSelected || selectedEndpoint == null)
              ? null
              : (value) {
            setState(() {
              _showGroundTruth = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildProcessAudioButton() {
    return _isLoading
        ? Center(child: CircularProgressIndicator())
        : ElevatedButton(
      onPressed: () {
        if (patientIdController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please enter Patient ID'),
            ),
          );
        } else if (_userAudioFile == null && selectedEndpoint == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please select an audio file'),
            ),
          );
        } else {
          _processAudio(
              _userAudioFile ?? File(''), patientIdController.text);
        }
      },
      child: Text('Process Audio'),
    );
  }

  Widget _buildPredictionDisplay() {
    return prediction.isNotEmpty
        ? Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16.0),
        Text(
          'Prediction:',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SizedBox(height: 8.0),
        Text(prediction),
        SizedBox(height: 16.0),
        if (_showGroundTruth && groundTruth.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ground Truth:',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 8.0),
              Text(groundTruth),
            ],
          ),
      ],
    )
        : SizedBox.shrink();
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

class AudioFile {
  final String name;
  final String groundTruth;

  AudioFile({
    required this.name,
    required this.groundTruth,
  });
}
