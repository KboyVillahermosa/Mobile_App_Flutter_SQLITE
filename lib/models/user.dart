class User {
  int? id;
  String fullName;
  String phoneNumber;
  String password;
  String? profileImage;
  
  // Assessment data fields
  String? userRole;
  String? ageGroup;
  String? experienceLevel;
  List<String>? services;
  List<String>? interests;
  bool hasCompletedAssessment;

  User({
    this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.password,
    this.profileImage,
    
    // Assessment data parameters
    this.userRole,
    this.ageGroup,
    this.experienceLevel,
    this.services,
    this.interests,
    this.hasCompletedAssessment = false,
  });

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
      'services': services != null ? services!.join(',') : null, // Store as comma-separated string
      'interests': interests != null ? interests!.join(',') : null, // Store as comma-separated string
      'hasCompletedAssessment': hasCompletedAssessment ? 1 : 0, // SQLite doesn't have boolean
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    // Print the raw map for debugging
    print("Creating User from map: $map");
    
    // Check if assessment fields exist
    final hasRole = map.containsKey('userRole') && map['userRole'] != null;
    final hasAge = map.containsKey('ageGroup') && map['ageGroup'] != null;
    final hasServices = map.containsKey('services') && map['services'] != null;
    
    print("Has role: $hasRole, Has age: $hasAge, Has services: $hasServices");
    
    // Parse services and interests correctly
    List<String>? services;
    if (map['services'] != null && map['services'].toString().isNotEmpty) {
      services = map['services'].toString().split(',');
    }
    
    List<String>? interests;
    if (map['interests'] != null && map['interests'].toString().isNotEmpty) {
      interests = map['interests'].toString().split(',');
    }
    
    return User(
      id: map['id'],
      fullName: map['fullName'],
      phoneNumber: map['phoneNumber'],
      password: map['password'],
      profileImage: map['profileImage'],
      userRole: map['userRole'],
      ageGroup: map['ageGroup'],
      experienceLevel: map['experienceLevel'],
      services: services,
      interests: interests,
      hasCompletedAssessment: map['hasCompletedAssessment'] == 1,
    );
  }
}