import 'dart:convert';
import 'dart:io';
import 'package:process_run/shell_run.dart';

void main() async {
  var shell = Shell(throwOnError: false);

  // Running the Flask server script
  var results = await shell.run('''
    # Running Flask server script
    python Flask_1.py
  ''');
  print(results);
  // Process results
  // for (var result in results) {
  //   print('Command: ${result.command}');
  //   print('Exit Code: ${result.exitCode}');
  //   print('stdout:');
  //   print(result.outText.trim());
  //   print('stderr:');
  //   print(result.errText.trim());
  //   print('-----');
  // }
}
