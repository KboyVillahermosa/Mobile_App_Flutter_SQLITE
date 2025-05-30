import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'confirmation_screen.dart';
import '../helpers/database_helper.dart';
import '../models/job.dart';

class JobPostingScreen extends StatefulWidget {
  final String phoneNumber;  // Rename from userId to phoneNumber for clarity

  const JobPostingScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<JobPostingScreen> createState() => _JobPostingScreenState();
}

class _JobPostingScreenState extends State<JobPostingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  List<File> _selectedImages = [];
  bool _isSubmitting = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF06D6A0),
              onPrimary: Colors.white,
              onSurface: Color(0xFF050315),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF06D6A0),
              onPrimary: Colors.white,
              onSurface: Color(0xFF050315),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((image) => File(image.path)).toList());
      });
    }
  }

  Future<void> _takePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    
    if (photo != null) {
      setState(() {
        _selectedImages.add(File(photo.path));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitJobPosting() async {
    if (_formKey.currentState!.validate() && 
        _selectedDate != null && 
        _selectedTime != null) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        // Get user by phone number
        final dbHelper = DatabaseHelper();
        final user = await dbHelper.getUserByPhone(widget.phoneNumber);
        
        if (user == null) {
          throw Exception('User not found');
        }
        
        // Combine date and time
        final dateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
        
        // Save images to app directory and get paths
        List<String> savedImagePaths = [];
        for (var image in _selectedImages) {
          try {
            String fileName = 'job_image_${DateTime.now().millisecondsSinceEpoch}_${savedImagePaths.length}.jpg';
            Directory appDocDir = await getApplicationDocumentsDirectory();
            String savedPath = '${appDocDir.path}/$fileName';
            
            // Read source file as bytes and write to destination instead of using copy
            final bytes = await image.readAsBytes();
            final newFile = File(savedPath);
            await newFile.writeAsBytes(bytes);
            
            savedImagePaths.add(savedPath);
          } catch (e) {
            print('Error saving image: $e');
            // Continue with other images even if one fails
          }
        }
        
        // Create job object
        final job = Job(
          userId: user.id!,
          title: _titleController.text,
          description: _descriptionController.text,
          budget: double.parse(_budgetController.text),
          location: _locationController.text,
          dateTime: dateTime,
          imagePaths: savedImagePaths,
          category: 'General', // Add a default category
        );
        
        // Insert job into database
        final jobId = await dbHelper.insertJob(job);
        print('Inserted job with ID: $jobId'); // Add logging
        
        if (!mounted) return;
        
        // Navigate to confirmation screen
        Navigator.of(context).pop(true); // Return true to indicate success
      } catch (e) {
        print('Error submitting job: $e'); // Add logging
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Post a Job',
          style: TextStyle(
            color: Color(0xFF050315),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF050315)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Form Instructions
                  Text(
                    'Enter job details',
                    style: TextStyle(
                      fontSize: 16,
                      color: const Color(0xFF050315).withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Job Title field
                  _buildTextField(
                    controller: _titleController,
                    label: 'Job Title',
                    icon: Icons.work_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a job title';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Description field
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Job Description',
                    icon: Icons.description_outlined,
                    maxLines: 4,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a job description';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Budget field
                  _buildTextField(
                    controller: _budgetController,
                    label: 'Budget (₱)',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your budget';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Location field
                  _buildTextField(
                    controller: _locationController,
                    label: 'Location',
                    icon: Icons.location_on_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a location';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Date and Time Selection
                  Row(
                    children: [
                      // Date picker
                      Expanded(
                        child: _buildSelectionField(
                          label: _selectedDate == null
                              ? 'Select Date'
                              : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                          icon: Icons.calendar_today,
                          onTap: () => _selectDate(context),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Time picker
                      Expanded(
                        child: _buildSelectionField(
                          label: _selectedTime == null
                              ? 'Select Time'
                              : _selectedTime!.format(context),
                          icon: Icons.access_time,
                          onTap: () => _selectTime(context),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Photo Upload Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Photos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF050315),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Image selection buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildIconButton(
                                label: 'Gallery',
                                icon: Icons.photo_library,
                                onPressed: _pickImages,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildIconButton(
                                label: 'Camera',
                                icon: Icons.camera_alt,
                                onPressed: _takePicture,
                              ),
                            ),
                          ],
                        ),
                        
                        // Image preview
                        if (_selectedImages.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _selectedImages.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          _selectedImages[index],
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => _removeImage(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Submit button
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitJobPosting,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06D6A0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: const Color(0xFF06D6A0).withOpacity(0.5),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Post Job',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper methods for building consistent UI components
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF64DFDF)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF06D6A0), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildSelectionField({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF64DFDF), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: label.startsWith('Select') 
                      ? Colors.grey[600]
                      : Colors.black87,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF06D6A0),
        side: const BorderSide(color: Color(0xFF06D6A0)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}