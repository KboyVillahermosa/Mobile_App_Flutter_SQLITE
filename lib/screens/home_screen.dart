import 'dart:io';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'user_profile_screen.dart';
import 'job_posting_screen.dart';
import '../helpers/database_helper.dart';
import '../models/job.dart';
import '../models/job_application.dart';
import '../models/user.dart'; // Add this import for the User model
import 'dart:convert'; // Add this for jsonEncode in additionalDetails

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
  Map<int, int> _imageIndexMap = {}; // Maps job.id to current image index

  // Form controllers - move OUTSIDE of the build method to persist
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  // State variables for the form - store these in class properties instead
  int _currentStep = 0;
  final int _totalSteps = 5;
  List<String> _selectedSkills = [];
  DateTime? _selectedDate;
  String _selectedTimeSlot = 'Morning';
  bool _hasTools = false;
  bool _hasTransportation = false;

  @override
  void initState() {
    super.initState();
    DatabaseHelper().checkAndFixApplicationsTable();
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
      final jobsData = await dbHelper.getAllJobsWithUserInfo();
      
      // Convert to Job objects and include uploader info
      final jobs = jobsData.map((map) {
        final job = Job.fromMap(map);
        job.uploaderName = map['uploaderName'] ?? 'Unknown';
        job.uploaderImage = map['uploaderImage'];
        return job;
      }).toList();
      
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
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Job poster info header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                // Profile image
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.secondaryColor.withOpacity(0.3),
                  backgroundImage: job.uploaderImage != null ? FileImage(File(job.uploaderImage!)) : null,
                  child: job.uploaderImage == null 
                    ? Icon(Icons.person, color: AppColors.secondaryColor) 
                    : null,
                ),
                const SizedBox(width: 12),
                // User name and post time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.uploaderName ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Posted ${_getTimeAgo(job.dateTime)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Job status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    job.status.toUpperCase(),
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Divider
          const Divider(),
          
          // Job images with carousel indicator (if available)
          if (job.imagePaths.isNotEmpty)
            Stack(
              children: [
                SizedBox(
                  height: 200,
                  child: PageView.builder(
                    itemCount: job.imagePaths.length,
                    onPageChanged: (index) {
                      setState(() {
                        // Store the current index in the map instead of on the job object
                        _imageIndexMap[job.id!] = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return Hero(
                        tag: 'job-image-${job.id}-$index',
                        child: GestureDetector(
                          onTap: () => _viewFullImage(job.imagePaths[index]),
                          child: Image.file(
                            File(job.imagePaths[index]),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, size: 40, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text('Image not available', style: TextStyle(color: Colors.grey[600])),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Carousel indicator dots
                if (job.imagePaths.length > 1)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        job.imagePaths.length,
                        (index) => Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index == (_imageIndexMap[job.id] ?? 0)
                                ? AppColors.primaryColor
                                : Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          
          // Job details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Job title
                Text(
                  job.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Job details in a row with icons
                Row(
                  children: [
                    // Budget
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.attach_money,
                              size: 18,
                              color: AppColors.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Budget',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '₱${job.budget.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Location
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: AppColors.secondaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Location',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  job.location,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Description
                Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  job.description.length > 120
                      ? '${job.description.substring(0, 120)}...'
                      : job.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                
                // Show more button if description is long
                if (job.description.length > 120)
                  TextButton(
                    onPressed: () => _showFullDescription(job),
                    child: Text(
                      'Read more',
                      style: TextStyle(
                        color: AppColors.secondaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 24),
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Apply button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _applyForJob(job),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Apply Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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

  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '$day/$month/$year at $hour:$minute';
  }

  // Format time relative to now (e.g., "2 hours ago")
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 7) {
      return _formatDateTime(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'just now';
    }
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

    // Get current user details first
    final dbHelper = DatabaseHelper();
    final user = await dbHelper.getUserByPhone(widget.phoneNumber!);
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User profile not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show application form dialog
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildApplicationForm(job, user),
    );
  }

  Widget _buildApplicationForm(Job job, User user) {
    return StatefulBuilder(
      builder: (context, setState) {
        // Navigation functions
        void nextStep() {
          if (_currentStep < _totalSteps - 1) {
            setState(() {
              _currentStep++;
            });
          }
        }
        
        void previousStep() {
          if (_currentStep > 0) {
            setState(() {
              _currentStep--;
            });
          }
        }
        
        // Validation for each step
        bool canMoveNext() {
          switch (_currentStep) {
            case 0: // Skills
              return _selectedSkills.isNotEmpty;
            case 1: // Availability
              return _selectedDate != null;
            case 2: // Price proposal
              return _priceController.text.isNotEmpty;
            case 3: // Additional info
              return true; // Always valid
            default:
              return true;
          }
        }
        
        // Submit application
        void submitApplication() async {
          try {
            print("Creating job application");
            final dbHelper = DatabaseHelper();
            
            // Create enhanced job application with additional info
            final application = JobApplication(
              jobId: job.id!,
              applicantId: user.id!,
              applicantName: user.fullName,
              applicantPhone: user.phoneNumber,
              // Add additional application details
              additionalDetails: {
                'skills': _selectedSkills.join(', '),
                'date': '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                'timeSlot': _selectedTimeSlot,
                'priceOffer': _priceController.text,
                'hasTools': _hasTools.toString(),
                'hasTransportation': _hasTransportation.toString(),
                'message': _messageController.text,
              },
            );
            
            print("Application created, about to insert: ${application.toMap()}");
            final result = await dbHelper.insertJobApplication(application);
            print("Database insert result: $result");
            
            Navigator.pop(context); // Close the form
            
            // Show success dialog
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppColors.primaryColor,
                        size: 30,
                      ),
                      SizedBox(width: 10),
                      Text('Success!'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.thumb_up,
                          size: 60,
                          color: AppColors.primaryColor,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Your application was submitted successfully!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'The job poster will be notified about your application.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      child: Text(
                        'OK',
                        style: TextStyle(
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
          } catch (e) {
            print('Error applying for job: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        
        // Step content widgets
        Widget buildSkillsStep() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select your relevant skills',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Gardening', 'Cleaning', 'Plumbing', 'Electrical', 'Carpentry', 
                  'Painting', 'Cooking', 'Pet Care', 'Babysitting', 'Tutoring',
                  'Computer Repair', 'Moving Help', 'Driving', 'Photography',
                  'Repair Work', 'Delivery', 'Laundry', 'Errands'
                ].map((skill) {
                  final isSelected = _selectedSkills.contains(skill);
                  return FilterChip(
                    label: Text(skill),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSkills.add(skill);
                        } else {
                          _selectedSkills.remove(skill);
                        }
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: AppColors.primaryColor.withOpacity(0.2),
                    checkmarkColor: AppColors.primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primaryColor : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 8),
              if (_selectedSkills.isEmpty)
                Text(
                  'Please select at least one skill to continue',
                  style: TextStyle(
                    color: Colors.red[400],
                    fontSize: 12,
                  ),
                ),
            ],
          );
        }
        
        Widget buildAvailabilityStep() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'When are you available?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Select date:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                    });
                  }
                },
                icon: Icon(Icons.calendar_today),
                label: Text(
                  _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : 'Select Date',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Select time slot:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedTimeSlot,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: ['Morning', 'Afternoon', 'Evening', 'Flexible']
                    .map((slot) => DropdownMenuItem(
                          value: slot,
                          child: Text(slot),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedTimeSlot = value;
                    });
                  }
                },
              ),
              SizedBox(height: 8),
              if (_selectedDate == null)
                Text(
                  'Please select a date to continue',
                  style: TextStyle(
                    color: Colors.red[400],
                    fontSize: 12,
                  ),
                ),
            ],
          );
        }
        
        Widget buildPriceStep() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your price proposal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'How much would you charge for this job?',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Your Rate (₱)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(Icons.attach_money),
                  helperText: 'The job poster\'s budget is ₱${job.budget}',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          );
        }
        
        Widget buildAdditionalInfoStep() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Additional Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Do you have the following?',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Card(
                elevation: 0,
                color: Colors.grey[100],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text('I have my own tools'),
                      subtitle: Text('Required equipment for the job'),
                      value: _hasTools,
                      onChanged: (value) {
                        setState(() {
                          _hasTools = value;
                        });
                      },
                    ),
                    Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: Text('I have transportation'),
                      subtitle: Text('Means to travel to the job location'),
                      value: _hasTransportation,
                      onChanged: (value) {
                        setState(() {
                          _hasTransportation = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        
        Widget buildMessageStep() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Message to job poster',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Introduce yourself and explain why you\'re suitable for this job',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Write your message here...',
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
                minLines: 4,
              ),
              SizedBox(height: 24),
              Text(
                'Application Summary:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Card(
                elevation: 0,
                color: Colors.grey[100],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star_outline, size: 16, color: AppColors.secondaryColor),
                          SizedBox(width: 8),
                          Text(
                            'Skills: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            child: Text(
                              _selectedSkills.isEmpty ? 'None selected' : _selectedSkills.join(', '),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.secondaryColor),
                          SizedBox(width: 8),
                          Text(
                            'Available: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(_selectedDate == null 
                            ? 'Not selected' 
                            : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year} ($_selectedTimeSlot)'),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.payments_outlined, size: 16, color: AppColors.secondaryColor),
                          SizedBox(width: 8),
                          Text(
                            'Price: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('₱${_priceController.text}'),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 16, color: AppColors.secondaryColor),
                          SizedBox(width: 8),
                          Text(
                            'Has Tools: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(_hasTools ? 'Yes' : 'No'),
                          SizedBox(width: 16),
                          Text(
                            'Transportation: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(_hasTransportation ? 'Yes' : 'No'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        
        // Get current step content
        Widget getCurrentStepContent() {
          switch (_currentStep) {
            case 0:
              return buildSkillsStep();
            case 1:
              return buildAvailabilityStep();
            case 2:
              return buildPriceStep();
            case 3:
              return buildAdditionalInfoStep();
            case 4:
              return buildMessageStep();
            default:
              return Container();
          }
        }
        
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Header with step indicator
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Draggable handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        // Title
                        Text(
                          'Apply for "${job.title}"',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        // Step indicator
                        Row(
                          children: List.generate(
                            _totalSteps,
                            (index) => Expanded(
                              child: Container(
                                height: 4,
                                margin: EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: index <= _currentStep 
                                    ? AppColors.primaryColor 
                                    : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        // Step title
                        Text(
                          'Step ${_currentStep + 1} of $_totalSteps',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Step content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: getCurrentStepContent(),
                      ),
                    ),
                  ),
                  
                  // Navigation buttons
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: Offset(0, -3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Back button (except on first step)
                        if (_currentStep > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: previousStep,
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text('Back'),
                            ),
                          ),
                        if (_currentStep > 0)
                          SizedBox(width: 16),
                        
                        // Next or Submit button
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: canMoveNext() 
                              ? (_currentStep < _totalSteps - 1 
                                  ? nextStep 
                                  : submitApplication)
                              : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              disabledBackgroundColor: Colors.grey[300],
                            ),
                            child: Text(
                              _currentStep < _totalSteps - 1 ? 'Next' : 'Submit Application',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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

  // Show full description dialog
  void _showFullDescription(Job job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Title
                Text(
                  job.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // Posted by
                Row(
                  children: [
                    Text(
                      'Posted by ',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      job.uploaderName ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      ' • ${_formatDateTime(job.dateTime)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Description
                const Text(
                  'Job Description',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  job.description,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // View full image
  void _viewFullImage(String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image, color: Colors.white, size: 60),
                      const SizedBox(height: 16),
                      Text(
                        'Image could not be loaded',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
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
    
    // Parse additional details if available
    Map<String, dynamic>? assessmentDetails;
    if (notification['additionalDetails'] != null) {
      try {
        assessmentDetails = jsonDecode(notification['additionalDetails']);
      } catch (e) {
        print('Error decoding assessment details: $e');
      }
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isNew ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isNew 
          ? BorderSide(color: AppColors.primaryColor, width: 2)
          : BorderSide.none,
      ),
      child: Column(
        children: [
          // Application header
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isNew ? AppColors.primaryColor : Colors.grey[300],
              backgroundImage: notification['applicantImage'] != null 
                  ? FileImage(File(notification['applicantImage']))
                  : null,
              child: notification['applicantImage'] == null
                  ? Icon(Icons.person, color: Colors.white)
                  : null,
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
          ),
          
          // Assessment details section (only if details exist)
          if (assessmentDetails != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  
                  // Skills
                  if (assessmentDetails['skills'] != null)
                    _buildAssessmentItem(
                      'Skills', 
                      assessmentDetails['skills'],
                      Icons.star_outline,
                    ),
                  
                  // Price offer
                  if (assessmentDetails['priceOffer'] != null)
                    _buildAssessmentItem(
                      'Price Offer', 
                      '₱${assessmentDetails['priceOffer']}',
                      Icons.payments_outlined,
                    ),
                  
                  if (assessmentDetails['date'] != null)
                    _buildAssessmentItem(
                      'Available', 
                      '${assessmentDetails['date']} (${assessmentDetails['timeSlot'] ?? 'Flexible'})',
                      Icons.calendar_today_outlined,
                    ),
                  
                  // Tools & Transportation
                  Row(
                    children: [
                      if (assessmentDetails['hasTools'] == 'true')
                        Chip(
                          label: const Text('Has Tools'),
                          avatar: Icon(Icons.handyman_outlined, size: 16),
                          backgroundColor: AppColors.accentColor.withOpacity(0.2),
                          labelStyle: TextStyle(fontSize: 12),
                          visualDensity: VisualDensity.compact,
                        ),
                      const SizedBox(width: 8),
                      if (assessmentDetails['hasTransportation'] == 'true')
                        Chip(
                          label: const Text('Has Transport'),
                          avatar: Icon(Icons.directions_car_outlined, size: 16),
                          backgroundColor: AppColors.secondaryColor.withOpacity(0.2),
                          labelStyle: TextStyle(fontSize: 12),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  
                  // Message preview
                  if (assessmentDetails['message'] != null && assessmentDetails['message'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Message:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            assessmentDetails['message'].length > 80
                                ? '${assessmentDetails['message'].substring(0, 80)}...'
                                : assessmentDetails['message'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _viewApplicantProfile(notification),
                  child: Text('View Profile'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _contactApplicant(notification),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Contact'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for assessment items
  Widget _buildAssessmentItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.secondaryColor),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Add this method to handle contacting applicants
  void _contactApplicant(Map<String, dynamic> notification) {
    // Implementation for contacting the applicant
    // This could launch a phone call, messaging app, etc.
    final String phoneNumber = notification['applicantPhone'];
    // For now, just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contacting ${notification['applicantName']} at $phoneNumber'),
      ),
    );
  }

  void _viewApplicantProfile(Map<String, dynamic> notification) {
    // Navigate to applicant profile
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          phoneNumber: notification['applicantPhone'],
          viewOnly: true,
        ),
      ),
    );
    
    // Mark as read by updating status if it's pending
    if (notification['status'] == 'pending') {
      DatabaseHelper().updateApplicationStatus(notification['id'], 'viewed')
      .then((_) {
        // Refresh notifications
        setState(() {});
        _updateNotificationCount(); // Update badge count
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

  // Add this method to your _HomeScreenState class
  Future<void> _testDatabaseInsert(Job job, User user) async {
    try {
      final db = await DatabaseHelper().database;
      final result = await db.insert(
        'applications',
        {
          'jobId': job.id!,
          'applicantId': user.id!,
          'applicantName': user.fullName,
          'applicantPhone': user.phoneNumber,
          'status': 'pending',
          'appliedAt': DateTime.now().toIso8601String(),
          // No additionalDetails to simplify test
        },
      );
      print("Test insert successful: $result");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test insert successful')),
      );
    } catch (e) {
      print("Test insert failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test failed: $e')),
      );
    }
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