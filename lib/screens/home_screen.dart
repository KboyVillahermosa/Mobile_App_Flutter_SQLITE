import 'dart:io'; // Add this import at the top
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'user_profile_screen.dart';
import 'job_posting_screen.dart'; // Add this import
import '../helpers/database_helper.dart'; // Add this import
import '../models/job.dart'; // Add this import
import '../models/job_application.dart'; // Add this import

// Color palette definition - consistent with other screens
class AppColors {
  static const textColor = Color(0xFF050315);
  static const backgroundColor = Color(0xFFFBFBFE);
  static const primaryColor = Color(0xFF06D6A0);
  static const secondaryColor = Color(0xFF64DFDF);
  static const accentColor = Color(0xFF80FFDB);
}

class HomeScreen extends StatefulWidget {
  final String? phoneNumber;

  const HomeScreen({
    super.key,
    this.phoneNumber,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<Job> _jobs = [];
  bool _isLoading = false;
  int _unreadNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadJobs();
    _updateNotificationCount();
  }

  // Load jobs from database
  Future<void> _loadJobs() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final dbHelper = DatabaseHelper();
      final jobs = await dbHelper.getAllJobs();
      
      if (mounted) {
        setState(() {
          _jobs = jobs;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading jobs: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateNotificationCount() async {
    if (widget.phoneNumber == null) {
      return;
    }
    
    try {
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserByPhone(widget.phoneNumber!);
      
      if (user != null) {
        final count = await dbHelper.getUnreadNotificationsCount(user.id!);
        
        if (mounted) {
          setState(() {
            _unreadNotificationsCount = count;
          });
        }
      }
    } catch (e) {
      print('Error updating notification count: $e');
    }
  }

  void _onItemTapped(int index) {
    // Always update the selected index first for visual feedback
    setState(() {
      _selectedIndex = index;
    });

    // For profile tab, navigate to the profile screen
    if (index == 3 && widget.phoneNumber != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(
            phoneNumber: widget.phoneNumber!,
          ),
        ),
      ).then((_) {
        // When returning from profile, reset to home tab
        setState(() {
          _selectedIndex = 0;
        });
      });
    }
  }

  // Get the appropriate body widget based on selected tab
  Widget _getBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildSearchTab();
      case 2:
        return _buildNotificationsTab();
      case 3:
        // For index 3, we navigate to profile screen, but still need a body
        return _buildProfilePreview();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryColor.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.work_outline,
                color: AppColors.primaryColor,
                size: 70,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No jobs available yet',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Be the first to post a job!',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToJobPosting(),
              icon: const Icon(Icons.add),
              label: const Text('Post a Job'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadJobs,
      color: AppColors.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _jobs.length,
        itemBuilder: (context, index) {
          final job = _jobs[index];
          return _buildJobCard(job);
        },
      ),
    );
  }

  Widget _buildJobCard(Job job) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Job images (if available)
          if (job.imagePaths.isNotEmpty)
            SizedBox(
              height: 150,
              child: PageView.builder(
                itemCount: job.imagePaths.length,
                itemBuilder: (context, index) {
                  return Image.file(
                    File(job.imagePaths[index]),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 50),
                      );
                    },
                  );
                },
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Job title
                Text(
                  job.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Budget
                Row(
                  children: [
                    const Icon(
                      Icons.attach_money,
                      size: 16,
                      color: AppColors.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '\$${job.budget.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textColor.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                
                // Location
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.secondaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      job.location,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                
                // Date/Time
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: AppColors.secondaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(job.dateTime),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                // Description (truncated)
                Text(
                  job.description.length > 100
                      ? '${job.description.substring(0, 100)}...'
                      : job.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textColor.withOpacity(0.8),
                  ),
                ),
                
                const SizedBox(height: 16),
                // Apply button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => _applyForJob(job),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    // Format the date and time in a user-friendly way
    final date = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    final time = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$date at $time';
  }

  void _applyForJob(Job job) async {
    if (widget.phoneNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to apply for jobs'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show a dialog to confirm application
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply for Job'),
        content: Text('Would you like to apply for "${job.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              setState(() {
                _isLoading = true;
              });
              
              try {
                // Get current user details
                final dbHelper = DatabaseHelper();
                final user = await dbHelper.getUserByPhone(widget.phoneNumber!);
                
                if (user == null) {
                  throw Exception('User not found');
                }
                
                // Create job application - make sure all required parameters are provided
                final application = JobApplication(
                  jobId: job.id!,
                  applicantId: user.id!,
                  applicantName: user.fullName,
                  applicantPhone: user.phoneNumber,
                );
                
                await dbHelper.insertJobApplication(application);
                
                if (!mounted) return;
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Application submitted successfully!'),
                    backgroundColor: AppColors.primaryColor,
                  ),
                );
              } catch (e) {
                print('Error applying for job: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _navigateToJobPosting() {
    if (widget.phoneNumber == null) {
      // User must be logged in to post jobs
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to post a job'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobPostingScreen(
          phoneNumber: widget.phoneNumber!,
        ),
      ),
    ).then((posted) {
      // Reload jobs when returning from job posting screen
      if (posted == true) {
        _loadJobs();
      }
    });
  }

  Widget _buildSearchTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: AppColors.secondaryColor,
          ),
          const SizedBox(height: 20),
          Text(
            'Search',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Find services and providers in your area',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textColor.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab() {
    if (widget.phoneNumber == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off,
              size: 80,
              color: AppColors.secondaryColor.withOpacity(0.7),
            ),
            const SizedBox(height: 20),
            const Text(
              'Not Logged In',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textColor,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please log in to view your notifications',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadNotifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }
        
        final notifications = snapshot.data ?? [];
        
        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 80,
                  color: AppColors.secondaryColor.withOpacity(0.7),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No Notifications',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You don\'t have any notifications yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return _buildNotificationCard(notification);
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadNotifications() async {
    try {
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserByPhone(widget.phoneNumber!);
      
      if (user == null) {
        return [];
      }
      
      return await dbHelper.getUserNotifications(user.id!);
    } catch (e) {
      print('Error loading notifications: $e');
      return [];
    }
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final bool isNew = notification['status'] == 'pending';
    final String jobTitle = notification['jobTitle'] ?? 'Unknown Job';
    final String applicantName = notification['applicantName'];
    final String applicantPhone = notification['applicantPhone'];
    final DateTime appliedAt = DateTime.parse(notification['appliedAt']);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isNew ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isNew 
          ? BorderSide(color: AppColors.primaryColor, width: 2)
          : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isNew ? AppColors.primaryColor : Colors.grey[300],
          child: Icon(
            Icons.person,
            color: Colors.white,
          ),
        ),
        title: Text(
          'New application for "$jobTitle"',
          style: TextStyle(
            fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('From: $applicantName'),
            Text('Phone: $applicantPhone'),
            Text(
              'Applied on: ${_formatDate(appliedAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: isNew 
          ? Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                shape: BoxShape.circle,
              ),
            )
          : null,
        onTap: () => _viewApplicantProfile(notification),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '$day/$month/$year at $hour:$minute';
  }

  void _viewApplicantProfile(Map<String, dynamic> notification) {
    // Navigate to applicant profile
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          phoneNumber: notification['applicantPhone'],
          viewOnly: true, // Change parameter name to match what UserProfileScreen expects
        ),
      ),
    );
    
    // Mark as read by updating status if it's pending
    if (notification['status'] == 'pending') {
      DatabaseHelper().updateApplicationStatus(notification['id'], 'viewed')
      .then((_) {
        // Refresh notifications
        setState(() {});
        _updateNotificationCount(); // Add this to update badge
      });
    }
  }

  Widget _buildProfilePreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person,
            size: 80,
            color: AppColors.secondaryColor,
          ),
          const SizedBox(height: 20),
          Text(
            'Profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              widget.phoneNumber != null
                  ? 'Loading your profile details...'
                  : 'Please log in to view your profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textColor.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servebisyo'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background pattern
          const PatternBackground(),

          // Dynamic content based on selected tab
          _getBody(),
        ],
      ),
      // Add floating action button for job posting
      floatingActionButton: _selectedIndex == 0 
          ? FloatingActionButton(
              onPressed: _navigateToJobPosting,
              backgroundColor: AppColors.primaryColor,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primaryColor,
          unselectedItemColor: AppColors.textColor.withOpacity(0.5),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: _unreadNotificationsCount > 0,
                label: Text(_unreadNotificationsCount.toString()),
                child: const Icon(Icons.notifications_outlined),
              ),
              activeIcon: Badge(
                isLabelVisible: _unreadNotificationsCount > 0,
                label: Text(_unreadNotificationsCount.toString()),
                child: const Icon(Icons.notifications),
              ),
              label: 'Notifications',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class PatternBackground extends StatelessWidget {
  const PatternBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        children: [
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppColors.secondaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}