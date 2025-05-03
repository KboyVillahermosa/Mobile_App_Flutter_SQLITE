import 'dart:io';
import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../models/user.dart';
import '../services/image_picker_service.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'application_history_screen.dart';

// Color palette definition - consistent with other screens
class AppColors {
  static const textColor = Color(0xFF050315);
  static const backgroundColor = Color(0xFFFBFBFE);
  static const primaryColor = Color(0xFF06D6A0);
  static const secondaryColor = Color(0xFF64DFDF);
  static const accentColor = Color(0xFF80FFDB);
}

class UserProfileScreen extends StatefulWidget {
  final String phoneNumber;
  final bool viewOnly;
  
  const UserProfileScreen({
    Key? key,
    required this.phoneNumber,
    this.viewOnly = false,
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
          SnackBar(
            content: Text('Failed to load profile: $e'),
            backgroundColor: Colors.red,
          ),
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
      
      final File? image = await ImagePickerService.showImageSourceDialog(context);
      if (image == null) {
        setState(() {
          _isUpdatingImage = false;
        });
        return;
      }
      
      final String imagePath = await ImagePickerService.saveImagePermanently(image);
      await _dbHelper.updateProfileImage(_user!.id!, imagePath);
      await _loadUserProfile();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated successfully'),
          backgroundColor: AppColors.primaryColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile picture: $e'),
          backgroundColor: Colors.red,
        ),
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
        _loadUserProfile();
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
    // Get screen size for responsive layout
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryColor,
              ),
            )
          : _user == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 80,
                        color: AppColors.secondaryColor.withOpacity(0.7),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'User not found',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loadUserProfile,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    // Background design elements
                    Positioned(
                      top: -100,
                      right: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppColors.accentColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -80,
                      left: -30,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: AppColors.secondaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    
                    // Main content
                    SafeArea(
                      child: RefreshIndicator(
                        onRefresh: _loadUserProfile,
                        color: AppColors.primaryColor,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 12 : 20,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Profile header section
                              _buildProfileHeader(),
                              SizedBox(height: isSmallScreen ? 16 : 24),
                              
                              // Profile details card
                              _buildProfileCard(),
                              SizedBox(height: isSmallScreen ? 16 : 24),
                              
                              // Action buttons
                              if (!widget.viewOnly) _buildActionButtons(),
                              
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
  
  Widget _buildProfileHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            // Avatar
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 70,
                backgroundColor: Colors.white,
                backgroundImage: _user?.profileImage != null
                    ? FileImage(File(_user!.profileImage!))
                    : null,
                child: _user?.profileImage == null
                    ? Icon(
                        Icons.person,
                        size: 70,
                        color: AppColors.secondaryColor.withOpacity(0.7),
                      )
                    : null,
              ),
            ),
            
            // Edit button for image
            if (!widget.viewOnly)
              GestureDetector(
                onTap: _isUpdatingImage ? null : _updateProfileImage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: _isUpdatingImage
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        
        // User name with verification badge
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _user!.fullName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.verified,
              size: 20,
              color: AppColors.primaryColor,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '+${_user!.phoneNumber}',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textColor.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: AppColors.secondaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor,
                  ),
                ),
              ],
            ),
          ),
          
          // Profile information items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileItem('Full Name', _user!.fullName, Icons.badge),
                const SizedBox(height: 16),
                _buildProfileItem('Phone Number', '+${_user!.phoneNumber}', Icons.phone),
                const SizedBox(height: 16),
                _buildProfileItem('Account ID', '#${_user!.id}', Icons.credit_card),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textColor.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _navigateToEditProfile,
          icon: const Icon(Icons.edit),
          label: const Text(
            'Edit Profile',
            style: TextStyle(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _navigateToChangePassword,
          icon: const Icon(Icons.lock_outline),
          label: const Text(
            'Change Password',
            style: TextStyle(fontSize: 16),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.secondaryColor,
            side: BorderSide(color: AppColors.secondaryColor),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ApplicationHistoryScreen(
                  phoneNumber: widget.phoneNumber,
                ),
              ),
            );
          },
          icon: const Icon(Icons.history),
          label: const Text('Application History'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ],
    );
  }
}