import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

class PhoneVerificationScreen extends StatefulWidget {
  @override
  _PhoneVerificationScreenState createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();
  String? _verificationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Phone Verification'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextFormField(
              controller: _phoneNumberController,
              decoration: InputDecoration(labelText: 'Phone number'),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () async {
                await _verifyPhoneNumber();
              },
              child: Text('Send OTP'),
            ),
            SizedBox(height: 16.0),
            TextFormField(
              controller: _smsCodeController,
              decoration: InputDecoration(labelText: 'Enter OTP'),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () async {
                await _signInWithPhoneNumber();
              },
              child: Text('Verify OTP'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyPhoneNumber() async {
    try {
      final FirebaseAuth _auth = FirebaseAuth.instance;

      final PhoneVerificationCompleted verificationCompleted =
          (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        print('Phone number automatically verified: ${_auth.currentUser?.uid}');
      };

      final PhoneVerificationFailed verificationFailed =
          (FirebaseAuthException e) {
        print('Phone number verification failed. Code: ${e.code}. Message: ${e.message}');
      };

      final PhoneCodeSent codeSent =
          (String verificationId, int? resendToken) async {
        print('Verification code sent to number: $_verificationId');
        setState(() {
          _verificationId = verificationId;
        });
      };

      final PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout =
          (String verificationId) {
        print('Auto retrieval timeout. Verification code: $verificationId');
      };

      await _auth.verifyPhoneNumber(
        phoneNumber: _phoneNumberController.text,
        timeout: Duration(seconds: 60),
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      );
    } catch (e) {
      print('Failed to verify phone number: $e');
    }
  }

  Future<void> _signInWithPhoneNumber() async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _smsCodeController.text,
      );
      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;
      if (user != null) {
        print('Successfully signed in with phone number: ${user.uid}');
      } else {
        print('Failed to sign in.');
      }
    } catch (e) {
      print('Failed to sign in with phone number: $e');
    }
  }
}
