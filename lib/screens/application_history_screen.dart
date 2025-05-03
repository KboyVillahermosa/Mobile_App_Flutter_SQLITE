import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../models/user.dart';

class AppColors {
  static const textColor = Color(0xFF050315);
  static const backgroundColor = Color(0xFFFBFBFE);
  static const primaryColor = Color(0xFF06D6A0);
  static const secondaryColor = Color(0xFF64DFDF);
  static const accentColor = Color(0xFF80FFDB);
}

class ApplicationHistoryScreen extends StatefulWidget {
  final String phoneNumber;

  const ApplicationHistoryScreen({
    Key? key,
    required this.phoneNumber,
  }) : super(key: key);

  @override
  State<ApplicationHistoryScreen> createState() => _ApplicationHistoryScreenState();
}

class _ApplicationHistoryScreenState extends State<ApplicationHistoryScreen> {
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadApplicationHistory();
  }

  Future<void> _loadApplicationHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserByPhone(widget.phoneNumber);
      
      if (user != null) {
        _currentUser = user;
        final applications = await dbHelper.getUserApplicationHistory(user.id!);
        
        setState(() {
          _applications = applications;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading application history: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Format the date and time
  String _formatDate(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeString;
    }
  }

  // Get color based on application status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'viewed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application History'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _applications.isEmpty
              ? _buildEmptyState()
              : _buildApplicationList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Applications Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You haven\'t applied to any jobs yet',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.search),
            label: const Text('Find Jobs'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationList() {
    return RefreshIndicator(
      onRefresh: _loadApplicationHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _applications.length,
        itemBuilder: (context, index) {
          final application = _applications[index];
          return _buildApplicationCard(application);
        },
      ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    final String jobTitle = application['title'] ?? 'Unknown Job';
    final String status = application['status'] ?? 'pending';
    final String appliedAt = _formatDate(application['appliedAt']);
    final double budget = application['budget'] ?? 0.0;
    final String location = application['location'] ?? 'Unknown location';
    
    // Parse additional details
    Map<String, dynamic>? additionalDetails;
    if (application['additionalDetails'] != null) {
      try {
        additionalDetails = jsonDecode(application['additionalDetails']);
      } catch (e) {
        print('Error decoding additionalDetails: $e');
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Job header with employer info
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            leading: CircleAvatar(
              backgroundColor: AppColors.secondaryColor.withOpacity(0.2),
              backgroundImage: application['uploaderImage'] != null 
                  ? FileImage(File(application['uploaderImage']))
                  : null,
              child: application['uploaderImage'] == null
                  ? const Icon(Icons.business, color: AppColors.secondaryColor)
                  : null,
            ),
            title: Text(
              jobTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              application['uploaderName'] ?? 'Unknown Employer',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            trailing: Chip(
              label: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: _getStatusColor(status),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
          
          const Divider(height: 1),
          
          // Job details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location and budget
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined, 
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.attach_money, 
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '₱${budget.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Application date
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Applied on: $appliedAt',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                
                // If we have additional details, show them
                if (additionalDetails != null) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  
                  Text(
                    'Your Application Details:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  if (additionalDetails['priceOffer'] != null)
                    _buildDetailItem('Your Price Offer', '₱${additionalDetails['priceOffer']}'),
                    
                  if (additionalDetails['skills'] != null)
                    _buildDetailItem('Skills', additionalDetails['skills']),
                    
                  if (additionalDetails['date'] != null)
                    _buildDetailItem(
                      'Availability', 
                      '${additionalDetails['date']} (${additionalDetails['timeSlot'] ?? 'Anytime'})'
                    ),
                ],
                
                const SizedBox(height: 16),
                
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => _viewJobDetails(application),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.secondaryColor,
                        side: BorderSide(color: AppColors.secondaryColor),
                      ),
                      child: const Text('View Job'),
                    ),
                    const SizedBox(width: 8),
                    if (status.toLowerCase() == 'pending')
                      ElevatedButton(
                        onPressed: () => _withdrawApplication(application),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[400],
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Withdraw'),
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

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _viewJobDetails(Map<String, dynamic> application) {
    // Implementation to view job details
    // This would navigate to a job details screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Viewing job details')),
    );
  }

  void _withdrawApplication(Map<String, dynamic> application) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Application'),
        content: const Text(
          'Are you sure you want to withdraw your application? '
          'This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('WITHDRAW'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        // Update application status to "withdrawn"
        final dbHelper = DatabaseHelper();
        await dbHelper.updateApplicationStatus(
          application['applicationId'], 
          'withdrawn'
        );
        
        // Refresh the list
        _loadApplicationHistory();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application withdrawn successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Error withdrawing application: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}