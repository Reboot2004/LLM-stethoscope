import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:stehot/previous_predictions_screen.dart';
import 'ChangePasswordScreen.dart';
import 'EditProfileScreen.dart';
import 'about_fft_spectrograms_screen.dart';
import 'about_mel_spectrograms_screen.dart';
import 'home.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'dashboard_screen.dart';
import 'dl_fft_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter App',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => HomeScreen(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/dashboard': (context) => DashboardScreen(),
        '/dl_fft': (context) => DLWithFFTScreen(),
        '/about_fft_spectrograms': (context) => FFTSpectrogramsScreen(),
        '/about_mel_spectrograms': (context) => MelSpectrogramsScreen(),
        '/previous_predictions': (context) => PreviousPredictionsScreen(),
        '/edit_profile': (context) => EditProfileScreen(),
        '/change_password': (context) => ChangePasswordScreen(),
      },
    );
  }
}
