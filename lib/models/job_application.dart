import 'package:flutter/foundation.dart';

class JobApplication {
  final int? id;
  final int jobId;
  final int applicantId;
  final String applicantName;
  final String applicantPhone;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime appliedAt;
  
  JobApplication({
    this.id,
    required this.jobId,
    required this.applicantId,
    required this.applicantName,
    required this.applicantPhone,
    this.status = 'pending',
    DateTime? appliedAt,
  }) : this.appliedAt = appliedAt ?? DateTime.now();
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobId': jobId,
      'applicantId': applicantId,
      'applicantName': applicantName,
      'applicantPhone': applicantPhone,
      'status': status,
      'appliedAt': appliedAt.toIso8601String(),
    };
  }
  
  factory JobApplication.fromMap(Map<String, dynamic> map) {
    return JobApplication(
      id: map['id'],
      jobId: map['jobId'],
      applicantId: map['applicantId'],
      applicantName: map['applicantName'],
      applicantPhone: map['applicantPhone'],
      status: map['status'],
      appliedAt: DateTime.parse(map['appliedAt']),
    );
  }
}