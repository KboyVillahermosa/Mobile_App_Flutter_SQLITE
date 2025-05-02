import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../models/job_application.dart';
import '../models/job.dart';
import '../models/user.dart';

class AppColors {
  static const textColor = Color(0xFF050315);
  static const backgroundColor = Color(0xFFFBFBFE);
  static const primaryColor = Color(0xFF06D6A0);
  static const secondaryColor = Color(0xFF64DFDF);
  static const accentColor = Color(0xFF80FFDB);
}

class ApplicationDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> notification;
  
  const ApplicationDetailsScreen({
    Key? key,
    required this.notification,
  }) : super(key: key);

  @override
  _ApplicationDetailsScreenState createState() => _ApplicationDetailsScreenState();
}

class _ApplicationDetailsScreenState extends State<ApplicationDetailsScreen> {
  bool _isLoading = true;
  Job? _job;
  User? _applicant;
  Map<String, dynamic>? _assessmentDetails;
  
  @override
  void initState() {
    super.initState();
    _loadDetails();
  }
  
  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Parse assessment details if available
      if (widget.notification['additionalDetails'] != null) {
        try {
          _assessmentDetails = jsonDecode(widget.notification['additionalDetails']);
        } catch (e) {
          print('Error decoding assessment details: $e');
        }
      }
      
      // Load full job details
      final dbHelper = DatabaseHelper();
      _job = await dbHelper.getJobById(widget.notification['jobId']);
      
      // Load applicant details
      _applicant = await dbHelper.getUserById(widget.notification['applicantId']);
      
    } catch (e) {
      print('Error loading application details: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Application Details'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Application header with job title
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: AppColors.secondaryColor.withOpacity(0.1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Application for',
                          style: TextStyle(
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _job?.title ?? widget.notification['jobTitle'] ?? 'Unknown Job',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Applied on: ${_formatDate(DateTime.parse(widget.notification['appliedAt']))}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Applicant info
                  _buildApplicantSection(),
                  
                  // Assessment details
                  if (_assessmentDetails != null)
                    _buildAssessmentSection(),
                    
                  // Actions
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _acceptApplication(),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Accept Application'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _rejectApplication(),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Decline'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildApplicantSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Applicant',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: _applicant?.profileImage != null
                      ? FileImage(File(_applicant!.profileImage!))
                      : null,
                  child: _applicant?.profileImage == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.notification['applicantName'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.notification['applicantPhone'],
                        style: TextStyle(
                          color: Colors.grey[700],
                        ),
                      ),
                      if (_applicant?.experienceLevel != null)
                        Chip(
                          label: Text(_applicant!.experienceLevel!),
                          backgroundColor: AppColors.accentColor.withOpacity(0.2),
                          labelStyle: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAssessmentSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assessment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Skills
            if (_assessmentDetails!['skills'] != null) ...[
              _buildDetailItem('Skills', Icons.star_outline),
              Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _assessmentDetails!['skills']
                      .split(', ')
                      .map<Widget>((skill) => Chip(
                            label: Text(skill),
                            backgroundColor: AppColors.accentColor.withOpacity(0.2),
                            labelStyle: const TextStyle(fontSize: 12),
                          ))
                      .toList(),
                ),
              ),
            ],
            
            // Price offer
            if (_assessmentDetails!['priceOffer'] != null)
              _buildDetailItem(
                'Price Offer: ₱${_assessmentDetails!['priceOffer']}',
                Icons.payments_outlined,
              ),
              
            // Availability
            if (_assessmentDetails!['date'] != null)
              _buildDetailItem(
                'Available on: ${_assessmentDetails!['date']} (${_assessmentDetails!['timeSlot'] ?? 'Flexible'})',
                Icons.calendar_today_outlined,
              ),
              
            // Tools & Transportation
            Row(
              children: [
                if (_assessmentDetails!['hasTools'] == 'true')
                  _buildPropertyChip('Has Tools', Icons.handyman_outlined),
                const SizedBox(width: 8),
                if (_assessmentDetails!['hasTransportation'] == 'true')
                  _buildPropertyChip('Has Transport', Icons.directions_car_outlined),
              ],
            ),
            const SizedBox(height: 16),
            
            // Message
            if (_assessmentDetails!['message'] != null && _assessmentDetails!['message'].toString().isNotEmpty) ...[
              _buildDetailItem('Message', Icons.message_outlined),
              Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 16, right: 16),
                child: Text(
                  _assessmentDetails!['message'],
                  style: TextStyle(
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPropertyChip(String label, IconData icon) {
    return Chip(
      label: Text(label),
      avatar: Icon(icon, size: 16),
      backgroundColor: AppColors.secondaryColor.withOpacity(0.2),
      labelStyle: const TextStyle(fontSize: 12),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  Future<void> _acceptApplication() async {
    // Update application status
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.updateApplicationStatus(widget.notification['id'], 'accepted');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application accepted!'),
          backgroundColor: AppColors.primaryColor,
        ),
      );
      
      Navigator.pop(context, true);
    } catch (e) {
      print('Error accepting application: $e');
    }
  }
  
  Future<void> _rejectApplication() async {
    // Update application status
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.updateApplicationStatus(widget.notification['id'], 'rejected');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application declined'),
          backgroundColor: Colors.redAccent,
        ),
      );
      
      Navigator.pop(context, true);
    } catch (e) {
      print('Error rejecting application: $e');
    }
  }
}