import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class FileUploader extends StatelessWidget {
  final AudioPlayer player;
  final Future<void> Function(String url) onFileUploaded; // Updated parameter

  const FileUploader({
    Key? key,
    required this.player,
    required this.onFileUploaded,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        // Simulating file upload URL, replace with actual file upload logic
        String url = 'https://example.com/audio_dl_fft.mp3';

        // Call the provided callback function
        await onFileUploaded(url);
      },
      child: Text('Upload Audio'),
    );
  }
}
