import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../models/user.dart';
import '../services/image_picker_service.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'application_history_screen.dart';
import 'achievements_editor_screen.dart';
import 'skills_assessment_screen.dart'; // Add this import

// Color palette definition - consistent with other screens
class AppColors {
  static const textColor = Color(0xFF050315);
  static const backgroundColor = Color(0xFFFBFBFE);
  static const primaryColor = Color(0xFF06D6A0);
  static const secondaryColor = Color(0xFF64DFDF);
  static const accentColor = Color(0xFF80FFDB);
  static const errorColor = Color(0xFFFF5C5C); // Added error color
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

class _UserProfileScreenState extends State<UserProfileScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  User? _user;
  bool _isLoading = true;
  bool _isUpdatingImage = false;
  
  // Initialize controller and animation without using late
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeInOut,
      ),
    );
    
    _animationController!.forward();
  }
  
  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
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
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: !widget.viewOnly ? null : IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!widget.viewOnly && _user != null)
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: _showSettingsSidebar,
              tooltip: 'Settings',
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading profile...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _user == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
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
                      TextButton.icon(
                        onPressed: _loadUserProfile,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    // Background design elements with enhanced gradients
                    Positioned(
                      top: -100,
                      right: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              AppColors.accentColor.withOpacity(0.3),
                              AppColors.accentColor.withOpacity(0.0),
                            ],
                          ),
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
                          gradient: RadialGradient(
                            colors: [
                              AppColors.secondaryColor.withOpacity(0.2),
                              AppColors.secondaryColor.withOpacity(0.0),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    
                    // Main content with fade animation
                    if (_fadeAnimation != null)
                      FadeTransition(
                        opacity: _fadeAnimation!,
                        child: SafeArea(
                          child: RefreshIndicator(
                            onRefresh: _loadUserProfile,
                            color: AppColors.primaryColor,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 16 : 24,
                                vertical: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Profile header section
                                  _buildProfileHeader(),
                                  SizedBox(height: isSmallScreen ? 20 : 30),
                                  
                                  // Bio section - enhanced
                                  _buildBioSection(),
                                  
                                  // Profile details card - improved visuals
                                  _buildProfileCard(),
                                  SizedBox(height: isSmallScreen ? 20 : 30),
                                  
                                  // Achievements section - better spacing
                                  _buildAchievementsSection(),
                                  SizedBox(height: isSmallScreen ? 20 : 30),
                                  
                                  // Skills section - more elegant design
                                  _buildSkillsSection(),
                                  
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SafeArea(
                        child: RefreshIndicator(
                          onRefresh: _loadUserProfile,
                          color: AppColors.primaryColor,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 16 : 24,
                              vertical: 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Profile header section
                                _buildProfileHeader(),
                                SizedBox(height: isSmallScreen ? 20 : 30),
                                
                                // Bio section - enhanced
                                _buildBioSection(),
                                
                                // Profile details card - improved visuals
                                _buildProfileCard(),
                                SizedBox(height: isSmallScreen ? 20 : 30),
                                
                                // Achievements section - better spacing
                                _buildAchievementsSection(),
                                SizedBox(height: isSmallScreen ? 20 : 30),
                                
                                // Skills section - more elegant design
                                _buildSkillsSection(),
                                
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryColor.withOpacity(0.05),
            AppColors.accentColor.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              // Avatar with enhanced appearance
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryColor.withOpacity(0.7),
                      AppColors.secondaryColor.withOpacity(0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryColor.withOpacity(0.2),
                      blurRadius: 25,
                      spreadRadius: 5,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 75,
                  backgroundColor: Colors.white,
                  backgroundImage: _user?.profileImage != null
                      ? FileImage(File(_user!.profileImage!))
                      : null,
                  child: _user?.profileImage == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 75,
                          color: AppColors.secondaryColor.withOpacity(0.7),
                        )
                      : null,
                ),
              ),
              
              // Edit button for image with improved styling
              if (!widget.viewOnly)
                GestureDetector(
                  onTap: _isUpdatingImage ? null : () => _showSettingsSidebar(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryColor,
                          AppColors.secondaryColor,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 0,
                          offset: const Offset(0, 3),
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
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          
          // User name with verification badge - improved typography
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _user!.fullName,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '+${_user!.phoneNumber}',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textColor.withOpacity(0.7),
              letterSpacing: 0.5,
            ),
          ),
          
          // User stats with improved visual design
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  spreadRadius: 0,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Applications', '0'),
                _buildDivider(),
                _buildStatItem('Achievements', '${_parseAchievements().length}'),
                _buildDivider(),
                _buildStatItem('Status', 'Active'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.withOpacity(0.3),
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

  Widget _buildBioSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.description_outlined, color: AppColors.secondaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      'About Me',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor,
                      ),
                    ),
                  ],
                ),
                if (!widget.viewOnly)
                  IconButton(
                    onPressed: _editBio,
                    icon: const Icon(Icons.edit, color: AppColors.secondaryColor),
                    tooltip: 'Edit Bio',
                  ),
              ],
            ),
          ),
          
          // Bio content
          Padding(
            padding: const EdgeInsets.all(16),
            child: _user?.bio != null && _user!.bio!.isNotEmpty
                ? Text(
                    _user!.bio!,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: AppColors.textColor,
                    ),
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.edit_note,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.viewOnly 
                                ? 'No bio available'
                                : 'Add a bio to tell others about yourself',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          if (!widget.viewOnly)
                            TextButton(
                              onPressed: _editBio,
                              child: const Text('Add Bio'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection() {
    List<Map<String, dynamic>> achievements = _parseAchievements();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium, color: AppColors.primaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      'Achievements & Certificates',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor,
                      ),
                    ),
                  ],
                ),
                if (!widget.viewOnly)
                  IconButton(
                    onPressed: _editAchievements,
                    icon: const Icon(Icons.edit, color: AppColors.primaryColor),
                    tooltip: 'Edit Achievements',
                  ),
              ],
            ),
          ),
          
          // Achievements content
          achievements.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.viewOnly 
                              ? 'No achievements available'
                              : 'Add your achievements and certificates',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        if (!widget.viewOnly)
                          TextButton(
                            onPressed: _editAchievements,
                            child: const Text('Add Achievements'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: achievements.length,
                  itemBuilder: (context, index) {
                    final achievement = achievements[index];
                    return _buildAchievementItem(achievement);
                  },
                ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _parseAchievements() {
    if (_user?.achievements == null || _user!.achievements!.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(_user!.achievements!);
      return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      print('Error parsing achievements: $e');
      return [];
    }
  }

  Widget _buildAchievementItem(Map<String, dynamic> achievement) {
    final String title = achievement['title'] ?? 'Unnamed Achievement';
    final String issuer = achievement['issuer'] ?? '';
    final String date = achievement['date'] ?? '';
    final String? description = achievement['description'];
    final String? imagePath = achievement['imagePath'];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display certificate image if available
          if (imagePath != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: GestureDetector(
                onTap: () => _viewFullImage(imagePath),
                child: Image.file(
                  File(imagePath),
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, error, _) => Container(
                    width: double.infinity,
                    height: 100,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    color: AppColors.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textColor,
                        ),
                      ),
                      if (issuer.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          issuer,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                      if (date.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Issued: $date',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: AppColors.textColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _viewFullImage(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Certificate'),
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20.0),
              minScale: 0.5,
              maxScale: 4,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                height: MediaQuery.of(context).size.height * 0.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editBio() async {
    final TextEditingController bioController = TextEditingController(text: _user?.bio);
    
    final String? result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Bio'),
        content: TextField(
          controller: bioController,
          decoration: const InputDecoration(
            hintText: 'Tell others about yourself...',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
          maxLength: 500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, bioController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
            ),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    
    if (result != null && _user != null) {
      try {
        await _dbHelper.updateBio(_user!.id!, result);
        await _loadUserProfile();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bio updated successfully'),
            backgroundColor: AppColors.primaryColor,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update bio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editAchievements() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AchievementsEditorScreen(
          userId: _user!.id!,
          initialAchievements: _parseAchievements(),
        ),
      ),
    );
    
    if (result == true) {
      await _loadUserProfile();
    }
  }

  void _showSettingsSidebar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSettingsSidebar(),
    );
  }

  Widget _buildSettingsSidebar() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          // Handle bar at top with improved styling
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          
          // Header with improved typography
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryColor.withOpacity(0.8),
                        AppColors.secondaryColor.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryColor.withOpacity(0.15),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Profile Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Settings options with improved styling
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSettingsItem(
                  icon: Icons.person_outline_rounded,
                  title: 'Edit Profile',
                  subtitle: 'Update your personal information',
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToEditProfile();
                  },
                ),
                _buildSettingsItem(
                  icon: Icons.lock_outline_rounded,
                  title: 'Change Password',
                  subtitle: 'Update your account password',
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToChangePassword();
                  },
                ),
                _buildSettingsItem(
                  icon: Icons.history_rounded,
                  title: 'Application History',
                  subtitle: 'View your previous applications',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ApplicationHistoryScreen(
                          phoneNumber: widget.phoneNumber,
                        ),
                      ),
                    );
                  },
                ),
                _buildSettingsItem(
                  icon: Icons.image_rounded,
                  title: 'Change Profile Photo',
                  subtitle: 'Update your profile picture',
                  onTap: () {
                    Navigator.pop(context);
                    _updateProfileImage();
                  },
                ),
                _buildSettingsItem(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Manage Achievements',
                  subtitle: 'Add or edit your certificates',
                  onTap: () {
                    Navigator.pop(context);
                    _editAchievements();
                  },
                ),
                _buildSettingsItem(
                  icon: Icons.edit_note_rounded,
                  title: 'Edit Bio',
                  subtitle: 'Update your personal bio',
                  onTap: () {
                    Navigator.pop(context);
                    _editBio();
                  },
                ),
                // Added Sign Out option
                _buildSettingsItem(
                  icon: Icons.logout_rounded,
                  title: 'Sign Out',
                  subtitle: 'Log out of your account',
                  onTap: _confirmSignOut,
                  iconColor: AppColors.errorColor,
                  showDivider: false,
                ),
              ],
            ),
          ),
          
          // Close button with improved styling
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Close',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (iconColor ?? AppColors.primaryColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? AppColors.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: iconColor ?? AppColors.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 70,
            endIndent: 24,
            color: Colors.grey[200],
          ),
      ],
    );
  }
  
  // Add method to handle sign out confirmation and action
  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close settings
              _signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('SIGN OUT'),
          ),
        ],
      ),
    );
  }
  
  void _signOut() async {
    try {
      // Clear any stored user credentials/tokens
      // For example:
      // await SharedPreferences.getInstance().then((prefs) => prefs.clear());
      
      // Navigate to login screen and clear navigation stack
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully signed out'),
          backgroundColor: AppColors.primaryColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }
  
  Widget _buildSkillsSection() {
    return FutureBuilder<List<String>>(
      future: DatabaseHelper().getUserSkills(_user!.id!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final skills = snapshot.data ?? [];
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Skills',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SkillsAssessment(
                          user: _user!,
                          isEditing: true,
                        ),
                      ),
                    ).then((_) => setState(() {})); // Refresh after returning
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            skills.isEmpty
                ? const Text('No skills added yet')
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: skills.map((skill) {
                      return Chip(
                        label: Text(skill),
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      );
                    }).toList(),
                  ),
          ],
        );
      },
    );
  }
}