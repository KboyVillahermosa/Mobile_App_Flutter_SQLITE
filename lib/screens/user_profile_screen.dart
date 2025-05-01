import 'dart:io';
import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../models/user.dart';
import '../services/image_picker_service.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String phoneNumber;
  final bool viewOnly; // Use this parameter name consistently
  
  const UserProfileScreen({
    Key? key,
    required this.phoneNumber,
    this.viewOnly = false, // Default to false
  }) : super(key: key);
  
  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  User? _user;
  bool _isLoading = true;
  bool _isUpdatingImage = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = await _dbHelper.getUserByPhone(widget.phoneNumber);
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _updateProfileImage() async {
    if (_user == null) return;
    
    try {
      setState(() {
        _isUpdatingImage = true;
      });
      
      // Pick image from gallery or camera
      final File? image = await ImagePickerService.showImageSourceDialog(context);
      if (image == null) {
        setState(() {
          _isUpdatingImage = false;
        });
        return;
      }
      
      // Save image to permanent storage
      final String imagePath = await ImagePickerService.saveImagePermanently(image);
      
      // Update database with new image path
      await _dbHelper.updateProfileImage(_user!.id!, imagePath);
      
      // Refresh user profile
      await _loadUserProfile();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile picture: $e')),
      );
    } finally {
      setState(() {
        _isUpdatingImage = false;
      });
    }
  }
  
  Future<void> _navigateToEditProfile() async {
    if (_user != null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditProfileScreen(user: _user!),
        ),
      );
      
      if (result == true) {
        _loadUserProfile(); // Refresh data after edit
      }
    }
  }
  
  Future<void> _navigateToChangePassword() async {
    if (_user != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChangePasswordScreen(user: _user!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? const Center(child: Text('User not found'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildProfileImage(),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _isUpdatingImage ? null : _updateProfileImage,
                          child: Text(
                            _isUpdatingImage ? 'Uploading...' : 'Change Profile Picture',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildProfileCard(),
                        const SizedBox(height: 24),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
    );
  }
  
  Widget _buildProfileImage() {
    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: _updateProfileImage,
          child: CircleAvatar(
            radius: 60,
            backgroundColor: Colors.blue.shade100,
            backgroundImage: _user?.profileImage != null
                ? FileImage(File(_user!.profileImage!))
                : null,
            child: _user?.profileImage == null
                ? const Icon(Icons.person, size: 60, color: Colors.blue)
                : null,
          ),
        ),
        if (_isUpdatingImage)
          const CircularProgressIndicator(),
      ],
    );
  }

  Widget _buildProfileCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileItem('Full Name', _user!.fullName),
            const Divider(),
            _buildProfileItem('Phone Number', '+${_user!.phoneNumber}'),
            const Divider(),
            _buildProfileItem('Account ID', '#${_user!.id}'),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _navigateToEditProfile,
          icon: const Icon(Icons.edit),
          label: const Text('Edit Profile'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _navigateToChangePassword,
          icon: const Icon(Icons.lock_outline),
          label: const Text('Change Password'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}