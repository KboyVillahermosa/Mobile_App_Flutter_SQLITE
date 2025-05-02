import 'dart:convert';

class JobApplication {
  final int? id;
  final int jobId;
  final int applicantId;
  final String applicantName;
  final String applicantPhone;
  final String status;
  final DateTime appliedAt;
  final Map<String, dynamic>? additionalDetails;

  JobApplication({
    this.id,
    required this.jobId,
    required this.applicantId,
    required this.applicantName,
    required this.applicantPhone,
    this.status = 'pending',
    DateTime? appliedAt,
    this.additionalDetails,
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
      'additionalDetails': additionalDetails != null ? jsonEncode(additionalDetails) : null,
    };
  }
}