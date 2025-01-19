import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'EditProfileScreen.dart';
import 'ChangePasswordScreen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  late User? _user;
  late Map<String, dynamic> _userData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      if (_user != null) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(_user!.uid).get();

        setState(() {
          _userData = userDoc.data() as Map<String, dynamic>;
          _isLoading = false; // Data loaded, set loading to false
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _isLoading = false; // Error occurred, set loading to false
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard')),
      drawer: _buildDrawer(context), // Use the custom drawer function
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator()
            : _buildDashboardContent(),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 50,
          child: _userData['photoUrl'] != null
              ? ClipOval(
            child: Image.network(
              _userData['photoUrl'],
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          )
              : Icon(Icons.person, size: 50), // Fallback icon
        ),
        SizedBox(height: 20),
        Text(
          'Welcome, ${_userData['username'] ?? 'User'}',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        _buildUserDetail('Email', _userData['email']),
        _buildUserDetail('Phone Number', _userData['phoneNumber']),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildUserDetail(String label, dynamic value) {
    return value != null
        ? Column(
      children: [
        Text(
          '$label:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 5),
        Text(
          '$value',
          style: TextStyle(fontSize: 16),
        ),
        SizedBox(height: 10),
      ],
    )
        : SizedBox();
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
