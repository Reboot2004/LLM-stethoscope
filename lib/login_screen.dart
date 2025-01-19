import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _emailOrPhoneController = TextEditingController();
  final _passwordController = TextEditingController();

  void _login() async {
    try {
      final input = _emailOrPhoneController.text.trim();
      final password = _passwordController.text.trim();
      UserCredential? userCredential;

      // Check if input is email, phone, or username
      if (input.contains('@')) {
        // Attempt login with email
        userCredential = await _auth.signInWithEmailAndPassword(
          email: input,
          password: password,
        );
      } else {
        // Attempt login with phone number or username
        QuerySnapshot userSnapshot;

        if (input.contains('+')) {
          // Input is phone number
          userSnapshot = await _firestore
              .collection('users')
              .where('phone', isEqualTo: input)
              .limit(1)
              .get();
        } else {
          // Input is username
          userSnapshot = await _firestore
              .collection('users')
              .where('username', isEqualTo: input)
              .limit(1)
              .get();
        }

        if (userSnapshot.docs.isNotEmpty) {
          // User found, retrieve email and authenticate
          String email = userSnapshot.docs.first.get('email');
          userCredential = await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        }
      }

      if (userCredential != null) {
        // User authenticated successfully
        if (userCredential.user?.emailVerified ?? false) {
          Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
        } else {
          // If the user attempted to login with email but authenticated via phone
          if (input.contains('@')) {
            bool confirm = await _showVerificationPrompt();
            if (confirm) {
              await userCredential.user?.sendEmailVerification();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Verification email sent!')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Please verify your email first.')),
            );
          }
        }
      } else {
        // User not found or login failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed. Please check your credentials.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  Future<bool> _showVerificationPrompt() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Verify Email'),
        content: Text('You are attempting to login with email credentials, but you are authenticated via phone. Would you like to verify your email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome Back!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _emailOrPhoneController,
                decoration: InputDecoration(
                  labelText: 'Email, Phone, or Username',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                obscureText: true,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _login,
                child: Text('Login'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
