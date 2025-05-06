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
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/image_picker_service.dart';
import 'message_screen.dart';
import 'conversations_screen.dart'; // Add this import for ConversationsScreen
import 'skills_assessment_screen.dart'; // Add this import for SkillsAssessment

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
  int _unreadMessagesCount = 0; // Add this state variable
  Map<int, int> _imageIndexMap = {}; // Maps job.id to current image index

  // Search state variables
  String _searchQuery = '';
  List<Job> _filteredJobs = [];
  RangeValues _priceRange = RangeValues(0, 10000);
  String _selectedCategory = 'All';
  String _selectedLocation = 'All';
  bool _isSearching = false;

  // Form controllers - move OUTSIDE of the build method to persist
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  // State variables for the form - store these in class properties instead
  int _currentStep = 0;
  final int _totalSteps = 6; // Increase from 5 to 6
  List<String> _selectedSkills = [];
  DateTime? _selectedDate;
  String _selectedTimeSlot = 'Morning';
  bool _hasTools = false;
  bool _hasTransportation = false;
  String? _resumePath;
  String? _bioDataImagePath;

  @override
  void initState() {
    super.initState();
    DatabaseHelper().checkAndFixApplicationsTable();
    DatabaseHelper().ensureNotificationsTableExists(); // Add this line
    _loadJobs();
    _updateNotificationCount();
    _updateUnreadMessagesCount();
    _checkDatabaseHealth(); // Add this line
    _checkSkillsAssessment(); // Call this after user authentication is confirmed
  }

  // Fix this method in your home screen class
  Future<void> _checkSkillsAssessment() async {
    if (widget.phoneNumber == null) {
      return; // No user logged in, skip assessment check
    }
    
    try {
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserByPhone(widget.phoneNumber!);
      
      if (user != null) {
        final hasCompleted = await dbHelper.hasCompletedAssessment(user.id!);
        
        if (!hasCompleted && mounted) {
          // Redirect to skills assessment
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SkillsAssessment(
                user: user,
                isEditing: false,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking skills assessment: $e');
    }
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
          // Initialize filtered jobs with all jobs
          _filteredJobs = List.from(jobs);
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

  Future<void> _updateUnreadMessagesCount() async {
    if (widget.phoneNumber == null) return;
    
    try {
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserByPhone(widget.phoneNumber!);
      
      if (user != null) {
        final count = await dbHelper.getUnreadMessagesCount(user.id!);
        
        if (mounted) {
          setState(() {
            _unreadMessagesCount = count;
          });
        }
      }
    } catch (e) {
      print('Error updating unread messages count: $e');
    }
  }

  Future<void> _checkDatabaseHealth() async {
    try {
      final dbHelper = DatabaseHelper();
      final diagnostics = await dbHelper.getDatabaseDiagnostics();
      print('Database diagnostics: $diagnostics');
      
      // This will help identify if there are any missing tables or columns
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Database health check failed: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Handle navigation for messages tab
    if (index == 2 && widget.phoneNumber != null) {
      final dbHelper = DatabaseHelper();
      dbHelper.getUserByPhone(widget.phoneNumber!).then((user) {
        if (user != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConversationsScreen(
                userId: user.id!,
              ),
            ),
          ).then((_) {
            // When returning from messages, reset to home tab
            setState(() {
              _selectedIndex = 0;
            });
            _updateUnreadMessagesCount();
          });
        }
      });
    }

    // For profile tab, navigate to the profile screen
    if (index == 4 && widget.phoneNumber != null) {
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
      case 3:
        return _buildNotificationsTab();
      case 4:
        // For index 4, we navigate to profile screen, but still need a body
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
                
                // Budget and Location row
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

  Future<String?> _pickPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      
      if (result != null) {
        File file = File(result.files.single.path!);
        
        // Copy file to app's documents directory for persistence
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'resume_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final savedFile = await file.copy('${appDir.path}/resumes/$fileName');
        
        return savedFile.path;
      }
      return null;
    } catch (e) {
      print('Error picking PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting PDF file')),
      );
      return null;
    }
  }

  Future<String?> _pickBioDataImage() async {
    try {
      final File? image = await ImagePickerService.showImageSourceDialog(context);
      if (image == null) return null;
      
      final String imagePath = await ImagePickerService.saveImagePermanently(image);
      return imagePath;
    } catch (e) {
      print('Error picking bio data image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image')),
      );
      return null;
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
            case 4: // Documents
              return true; // Optional step
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
                'resumePath': _resumePath, // Add resume path
                'bioDataImagePath': _bioDataImagePath, // Add bio data image path
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
        
        Widget buildDocumentsStep() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload Documents (Optional)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Adding a resume or bio data can increase your chances of getting hired',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 24),
              
              // Resume upload section
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.description,
                            color: AppColors.primaryColor,
                            size: 22,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Resume (PDF)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Upload your CV or resume',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    if (_resumePath == null)
                      Center(
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.upload_file),
                          label: Text('Select PDF'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          onPressed: () async {
                            final path = await _pickPDF();
                            if (path != null) {
                              setState(() {
                                _resumePath = path;
                              });
                            }
                          },
                        ),
                      )
                    else
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryColor),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.picture_as_pdf,
                              color: Colors.red[700],
                              size: 36,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Resume.pdf',
                                    style: TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    'PDF file selected',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _resumePath = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              SizedBox(height: 20),
              
              // Bio Data Image upload section
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.badge,
                            color: AppColors.secondaryColor,
                            size: 22,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bio Data Image',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Upload a photo of your handwritten bio data',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    if (_bioDataImagePath == null)
                      Center(
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.add_photo_alternate),
                          label: Text('Select Image'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          onPressed: () async {
                            final path = await _pickBioDataImage();
                            if (path != null) {
                              setState(() {
                                _bioDataImagePath = path;
                              });
                            }
                          },
                        ),
                      )
                    else
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_bioDataImagePath!),
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          IconButton(
                            icon: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                            onPressed: () {
                              setState(() {
                                _bioDataImagePath = null;
                              });
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: AppColors.primaryColor),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tip: Adding these documents is optional but can significantly improve your chances of getting hired.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                      ),
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
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.attach_file, size: 16, color: AppColors.secondaryColor),
                          SizedBox(width: 8),
                          Text(
                            'Documents: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            child: Text(
                              (_resumePath != null && _bioDataImagePath != null) 
                                  ? 'Resume & Bio Data'
                                  : (_resumePath != null) 
                                      ? 'Resume Only' 
                                      : (_bioDataImagePath != null)
                                          ? 'Bio Data Only'
                                          : 'None provided',
                            ),
                          ),
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
              return buildDocumentsStep(); // New documents step
            case 5:
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
    return Column(
      children: [
        // Search header with card design
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search input with button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search jobs...',
                          prefixIcon: const Icon(Icons.search),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    // Clear button shows when there's text
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _applySearchFilters();
                          });
                        },
                      ),
                    // Search button
                    InkWell(
                      onTap: () {
                        _applySearchFilters();
                        // Close keyboard
                        FocusScope.of(context).unfocus();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                        ),
                        child: const Text(
                          'Search',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Category filter with cleaner UI
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryChip('All'),
                        _buildCategoryChip('Gardening'),
                        _buildCategoryChip('Cleaning'),
                        _buildCategoryChip('Plumbing'),
                        _buildCategoryChip('Electrical'),
                        _buildCategoryChip('Carpentry'),
                        _buildCategoryChip('Delivery'),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Price range with dropdown instead of slider
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price Range',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _getPriceRangeAsString(),
                        isExpanded: true,
                        hint: const Text('Select price range'),
                        items: [
                          'Any price',
                          'Under ₱500',
                          '₱500 - ₱1,000',
                          '₱1,000 - ₱2,500',
                          '₱2,500 - ₱5,000',
                          '₱5,000 - ₱7,500',
                          'Over ₱7,500',
                          'Custom range',  // Add this item
                        ].map((range) {
                          return DropdownMenuItem<String>(
                            value: range,
                            child: Text(range),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _setPriceRangeFromString(value);
                              _applySearchFilters();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Location filter with improved design
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLocation,
                        isExpanded: true,
                        hint: const Text('Select location'),
                        items: [
                          'All',
                          'Manila',
                          'Quezon City',
                          'Cebu City',
                          'Davao City',
                          'Makati',
                          'Pasig',
                          'Taguig',
                        ].map((location) {
                          return DropdownMenuItem<String>(
                            value: location,
                            child: Text(location),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedLocation = value;
                              _applySearchFilters();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Reset button with better styling
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _resetFilters();
                    // Show feedback
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Search filters have been reset'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset All Filters'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppColors.secondaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Applied filters indicators
        if (_hasActiveFilters())
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: Row(
              children: [
                Icon(Icons.filter_list, size: 16, color: AppColors.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Active filters: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: Text(_getActiveFiltersText()),
                ),
              ],
            ),
          ),
        
        // Results count and loader
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredJobs.length} job${_filteredJobs.length == 1 ? '' : 's'} found',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              if (_isSearching)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                  ),
                ),
            ],
          ),
        ),
        
        // Results list
        Expanded(
          child: _filteredJobs.isEmpty
              ? _buildNoResultsFound()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _filteredJobs.length,
                  itemBuilder: (context, index) {
                    return _buildJobCard(_filteredJobs[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(category),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = category;
            _applySearchFilters();
          });
        },
        backgroundColor: Colors.grey[200],
        selectedColor: AppColors.primaryColor.withOpacity(0.2),
        checkmarkColor: AppColors.primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primaryColor : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildNoResultsFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search filters',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _applySearchFilters() {
    setState(() {
      _isSearching = true;
    });

    // Filter jobs based on criteria
    List<Job> results = _jobs.where((job) {
      // Filter by search query (in title and description)
      final matchesQuery = _searchQuery.isEmpty ||
          job.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          job.description.toLowerCase().contains(_searchQuery.toLowerCase());

      // Filter by category
      final matchesCategory = _selectedCategory == 'All' ||
          job.category?.toLowerCase() == _selectedCategory.toLowerCase();

      // Filter by price range
      final matchesPrice = job.budget >= _priceRange.start && 
                           job.budget <= _priceRange.end;

      // Filter by location
      final matchesLocation = _selectedLocation == 'All' ||
          job.location.toLowerCase().contains(_selectedLocation.toLowerCase());

      return matchesQuery && matchesCategory && matchesPrice && matchesLocation;
    }).toList();

    // Sort results (newest first)
    results.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    setState(() {
      _filteredJobs = results;
      _isSearching = false;
    });
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _selectedCategory = 'All';
      _priceRange = RangeValues(0, 10000);
      _selectedLocation = 'All';
      _filteredJobs = List.from(_jobs);
    });
  }

  // Helper to get price range as string
  String _getPriceRangeAsString() {
    if (_priceRange.start == 0 && _priceRange.end == 10000) {
      return 'Any price';
    } else if (_priceRange.start == 0 && _priceRange.end == 500) {
      return 'Under ₱500';
    } else if (_priceRange.start == 500 && _priceRange.end == 1000) {
      return '₱500 - ₱1,000';
    } else if (_priceRange.start == 1000 && _priceRange.end == 2500) {
      return '₱1,000 - ₱2,500';
    } else if (_priceRange.start == 2500 && _priceRange.end == 5000) {
      return '₱2,500 - ₱5,000';
    } else if (_priceRange.start == 5000 && _priceRange.end == 7500) {
      return '₱5,000 - ₱7,500';
    } else if (_priceRange.start == 7500 && _priceRange.end == 10000) {
      return 'Over ₱7,500';
    }
    return 'Custom range';
  }

  // Helper to set price range from string
  void _setPriceRangeFromString(String range) {
    switch (range) {
      case 'Any price':
        _priceRange = RangeValues(0, 10000);
        break;
      case 'Under ₱500':
        _priceRange = RangeValues(0, 500);
        break;
      case '₱500 - ₱1,000':
        _priceRange = RangeValues(500, 1000);
        break;
      case '₱1,000 - ₱2,500':
        _priceRange = RangeValues(1000, 2500);
        break;
      case '₱2,500 - ₱5,000':
        _priceRange = RangeValues(2500, 5000);
        break;
      case '₱5,000 - ₱7,500':
        _priceRange = RangeValues(5000, 7500);
        break;
      case 'Over ₱7,500':
        _priceRange = RangeValues(7500, 10000);
        break;
    }
  }

  // Check if any filters are active
  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty || 
           _selectedCategory != 'All' || 
           _selectedLocation != 'All' ||
           _priceRange.start > 0 || 
           _priceRange.end < 10000;
  }

  // Get a text description of active filters
  String _getActiveFiltersText() {
    List<String> filters = [];
    
    if (_searchQuery.isNotEmpty) {
      filters.add('"${_searchQuery}"');
    }
    
    if (_selectedCategory != 'All') {
      filters.add(_selectedCategory);
    }
    
    if (_selectedLocation != 'All') {
      filters.add(_selectedLocation);
    }
    
    if (_priceRange.start > 0 || _priceRange.end < 10000) {
      filters.add(_getPriceRangeAsString());
    }
    
    return filters.join(', ');
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
                  
                  // Resume & Bio Data
                  if (assessmentDetails?['resumePath'] != null || 
                      assessmentDetails?['bioDataImagePath'] != null) 
                    const SizedBox(height: 8),
                  Row(
                    children: [
                      if (assessmentDetails?['resumePath'] != null)
                        Chip(
                          label: const Text('Resume'),
                          avatar: Icon(Icons.description, size: 16),
                          backgroundColor: Colors.blue[100],
                          labelStyle: TextStyle(fontSize: 12),
                          visualDensity: VisualDensity.compact,
                        ),
                      const SizedBox(width: 8),
                      if (assessmentDetails?['bioDataImagePath'] != null)
                        Chip(
                          label: const Text('Bio Data'),
                          avatar: Icon(Icons.badge, size: 16),
                          backgroundColor: Colors.purple[100],
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
            child: Wrap(
              spacing: 4, // horizontal space between buttons
              runSpacing: 8, // vertical space between rows
              alignment: WrapAlignment.end,
              children: [
                if (assessmentDetails != null && 
                    (assessmentDetails['resumePath'] != null || assessmentDetails['bioDataImagePath'] != null))
                  TextButton.icon(
                    icon: Icon(Icons.description, size: 20),
                    label: Text('Documents', style: TextStyle(fontSize: 13)),
                    onPressed: () => _viewApplicationDocuments(assessmentDetails),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                TextButton.icon(
                  icon: Icon(Icons.message_outlined, size: 20),
                  label: Text('Message', style: TextStyle(fontSize: 13)),
                  onPressed: () => _openMessageDialog(notification),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                TextButton(
                  onPressed: () => _viewApplicantProfile(notification),
                  child: Text('View Profile', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                notification['status'] == 'hired' ? 
                  OutlinedButton.icon(
                    icon: Icon(Icons.check_circle, color: Colors.green, size: 18),
                    label: Text('Hired', style: TextStyle(color: Colors.green, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.green),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onPressed: null,
                  ) :
                  ElevatedButton.icon(
                    icon: Icon(Icons.handshake_outlined, size: 18),
                    label: Text('Hire', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onPressed: () => _hireApplicant(notification),
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
  void _contactApplicant(Map<String, dynamic> notification) async {
    try {
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserByPhone(widget.phoneNumber!);
      
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Could not find your user profile')),
        );
        return;
      }
      
      // Open message screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MessageScreen(
            jobId: notification['jobId'],
            jobTitle: notification['jobTitle'] ?? 'Unknown Job',
            senderId: user.id!,
            receiverId: notification['applicantId'],
            receiverName: notification['applicantName'],
          ),
        ),
      ).then((_) {
        // Refresh notifications when returning from messages
        _updateNotificationCount();
        setState(() {});
      });
    } catch (e) {
      print('Error contacting applicant: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
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

  void _viewResumePDF(String pdfPath) {
    // You'll need to implement a PDF viewer
    // For now, show a dialog confirming the PDF exists
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.red),
            SizedBox(width: 8),
            Text('Resume PDF'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PDF file is available at:'),
            SizedBox(height: 8),
            Text(
              pdfPath,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            SizedBox(height: 16),
            Text(
              'To view PDFs, you need to integrate a PDF viewer package like flutter_pdfview',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _viewBioDataImage(String imagePath) {
    // Show full-screen image viewer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Bio Data Image'),
            backgroundColor: AppColors.primaryColor,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Image.file(
                File(imagePath),
                errorBuilder: (context, error, stackTrace) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 100, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Could not load image'),
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

  void _viewApplicationDocuments(Map<String, dynamic>? assessmentDetails) {
    if (assessmentDetails == null) return;
    
    final resumePath = assessmentDetails['resumePath'];
    final bioDataPath = assessmentDetails['bioDataImagePath'];
    
    if (resumePath == null && bioDataPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No documents provided by this applicant')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Application Documents'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (resumePath != null)
              ListTile(
                leading: Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text('Resume PDF'),
                onTap: () {
                  Navigator.pop(context);
                  _viewResumePDF(resumePath);
                },
              ),
            if (bioDataPath != null)
              ListTile(
                leading: Icon(Icons.image, color: Colors.blue),
                title: Text('Bio Data Image'),
                onTap: () {
                  Navigator.pop(context);
                  _viewBioDataImage(bioDataPath);
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openMessageDialog(Map<String, dynamic> notification) {
    final TextEditingController messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Message to ${notification['applicantName']}'),
            SizedBox(height: 4),
            Text(
              'Regarding: ${notification['jobTitle']}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: messageController,
              decoration: InputDecoration(
                hintText: 'Type your message here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              maxLines: 5,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (messageController.text.isNotEmpty) {
                _sendMessage(
                  notification,
                  messageController.text,
                );
                Navigator.pop(context);
              }
            },
            child: Text('Send Message'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(Map<String, dynamic> notification, String message) async {
    try {
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserByPhone(widget.phoneNumber!);
      
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Could not find your user profile')),
        );
        return;
      }
      
      // Create message data
      final messageData = {
        'senderId': user.id,
        'receiverId': notification['applicantId'],
        'jobId': notification['jobId'],
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': 0,
      };
      
      // Insert message into database
      await dbHelper.insertMessage(messageData);
      
      // Create notification for applicant
      await dbHelper.createNotification(
        notification['applicantId'],
        user.id!,
        'message',
        'New message regarding ${notification['jobTitle']}',
        jsonEncode({'jobId': notification['jobId'], 'messagePreview': message}),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message sent to ${notification['applicantName']}'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Mark application as viewed if it was pending
      if (notification['status'] == 'pending') {
        await dbHelper.updateApplicationStatus(notification['id'], 'viewed');
        _updateNotificationCount();
        setState(() {});
      }
      
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  void _hireApplicant(Map<String, dynamic> notification) {
    final TextEditingController hireMessageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Hire ${notification['applicantName']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to hire this applicant for "${notification['jobTitle']}".',
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 16),
            Text(
              'Send a message with hiring details:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            TextField(
              controller: hireMessageController,
              decoration: InputDecoration(
                hintText: 'Include details about payment, schedule, location, etc.',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _confirmHiring(notification, hireMessageController.text);
            },
            child: Text('Confirm Hiring'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmHiring(Map<String, dynamic> notification, String message) async {
    try {
      final dbHelper = DatabaseHelper();
      
      // 1. Update application status to "hired"
      await dbHelper.updateApplicationStatus(notification['id'], 'hired');
      
      // 2. Create a notification for the applicant
      final user = await dbHelper.getUserByPhone(widget.phoneNumber!);
      if (user != null) {
        await dbHelper.createNotification(
          notification['applicantId'], 
          user.id!,
          'hired',
          'You\'ve been hired for "${notification['jobTitle']}"!',
          jsonEncode({
            'jobId': notification['jobId'],
            'message': message,
            'hiringDate': DateTime.now().toIso8601String(),
          }),
        );
        
        // 3. Send a message if provided
        if (message.isNotEmpty) {
          await dbHelper.insertMessage({
            'senderId': user.id,
            'receiverId': notification['applicantId'],
            'jobId': notification['jobId'],
            'message': message,
            'timestamp': DateTime.now().toIso8601String(),
            'isRead': 0,
          });
        }
        
        // 4. Update job status to "assigned" if needed
        await dbHelper.updateJobStatus(notification['jobId'], 'assigned');
      }
      
      // 5. Show success message and refresh
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${notification['applicantName']} has been hired!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // 6. Refresh notifications
      setState(() {});
      
    } catch (e) {
      print('Error hiring applicant: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
          selectedItemColor: AppColors.primaryColor,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  Icon(Icons.chat_bubble_outline),
                  if (_unreadMessagesCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          _unreadMessagesCount > 9 ? '9+' : _unreadMessagesCount.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                ],
              ),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: 'Notifications',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
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