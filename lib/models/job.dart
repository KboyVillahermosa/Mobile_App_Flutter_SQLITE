import 'dart:convert';

class Job {
  final int? id;
  final int userId;
  final String title;
  final String description;
  final double budget;
  final String location;
  final DateTime dateTime;
  final List<String> imagePaths;
  final String status;
  final DateTime createdAt;
  String? uploaderName;
  String? uploaderImage;
  int? currentImageIndex; // Add this property to track the current image index

  Job({
    this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.budget,
    required this.location,
    required this.dateTime,
    this.imagePaths = const [],
    this.status = 'open',
    DateTime? createdAt,
    this.uploaderName,
    this.uploaderImage,
    this.currentImageIndex = 0, // Default to first image
  }) : this.createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'budget': budget,
      'location': location,
      'dateTime': dateTime.toIso8601String(),
      'imagePaths': jsonEncode(imagePaths),
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'uploaderName': uploaderName,
      'uploaderImage': uploaderImage,
      'currentImageIndex': currentImageIndex, // Include currentImageIndex in the map
    };
  }

  factory Job.fromMap(Map<String, dynamic> map) {
    List<String> parseImagePaths(String? jsonString) {
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      try {
        List<dynamic> decoded = jsonDecode(jsonString);
        return decoded.map((e) => e.toString()).toList();
      } catch (e) {
        return [];
      }
    }

    return Job(
      id: map['id'],
      userId: map['userId'],
      title: map['title'],
      description: map['description'],
      budget: map['budget'],
      location: map['location'],
      dateTime: DateTime.parse(map['dateTime']),
      imagePaths: parseImagePaths(map['imagePaths']),
      status: map['status'],
      createdAt: DateTime.parse(map['createdAt']),
      uploaderName: map['uploaderName'],
      uploaderImage: map['uploaderImage'],
      currentImageIndex: map['currentImageIndex'], // Parse currentImageIndex from the map
    );
  }
}