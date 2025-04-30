class User {
  int? id;
  String fullName;
  String phoneNumber;
  String password;
  String? profileImage; // Add this field

  User({
    this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.password,
    this.profileImage, // Add this parameter
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'password': password,
      'profileImage': profileImage, // Include in map
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      fullName: map['fullName'],
      phoneNumber: map['phoneNumber'],
      password: map['password'],
      profileImage: map['profileImage'], // Extract from map
    );
  }
}