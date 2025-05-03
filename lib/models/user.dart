class User {
  final int? id;
  final String fullName;
  final String phoneNumber;
  final String password;
  final String? profileImage;
  final String? userRole;
  final String? ageGroup;
  final String? experienceLevel;
  final String? services;
  final String? interests;
  final int? hasCompletedAssessment;
  
  // Add new fields
  final String? bio;
  final String? achievements; // Store as JSON string
  
  // Update constructor
  User({
    this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.password,
    this.profileImage,
    this.userRole,
    this.ageGroup,
    this.experienceLevel,
    this.services,
    this.interests,
    this.hasCompletedAssessment,
    this.bio,
    this.achievements,
  });

  // Update toMap method
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'password': password,
      'profileImage': profileImage,
      'userRole': userRole,
      'ageGroup': ageGroup,
      'experienceLevel': experienceLevel,
      'services': services,
      'interests': interests,
      'hasCompletedAssessment': hasCompletedAssessment,
      'bio': bio,
      'achievements': achievements,
    };
  }

  // Update fromMap method
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      fullName: map['fullName'],
      phoneNumber: map['phoneNumber'],
      password: map['password'],
      profileImage: map['profileImage'],
      userRole: map['userRole'],
      ageGroup: map['ageGroup'],
      experienceLevel: map['experienceLevel'],
      services: map['services'],
      interests: map['interests'],
      hasCompletedAssessment: map['hasCompletedAssessment'],
      bio: map['bio'],
      achievements: map['achievements'],
    );
  }
}