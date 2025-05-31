import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RatingService {
  static const String _ratingsKey = 'applicant_ratings';
  
  // Save a new rating
  Future<void> saveRating(Map<String, dynamic> ratingData) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing ratings
    List<Map<String, dynamic>> ratings = await getRatings();
    
    // Add new rating
    ratings.add(ratingData);
    
    // Save updated list
    await prefs.setString(_ratingsKey, jsonEncode(ratings));
  }
  
  // Get all ratings
  Future<List<Map<String, dynamic>>> getRatings() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!prefs.containsKey(_ratingsKey)) {
      return [];
    }
    
    final String ratingsJson = prefs.getString(_ratingsKey) ?? '[]';
    List<dynamic> ratingsList = jsonDecode(ratingsJson);
    
    return ratingsList.cast<Map<String, dynamic>>();
  }
  
  // Get ratings for a specific applicant
  Future<List<Map<String, dynamic>>> getApplicantRatings(String applicantId) async {
    final allRatings = await getRatings();
    
    return allRatings.where((rating) => 
      rating['applicantId'] == applicantId
    ).toList();
  }
  
  // Calculate average rating for an applicant
  Future<double> getAverageRating(String applicantId) async {
    final applicantRatings = await getApplicantRatings(applicantId);
    
    if (applicantRatings.isEmpty) {
      return 0.0;
    }
    
    double sum = applicantRatings.fold(0.0, (sum, rating) => 
      sum + (rating['rating'] as double));
      
    return sum / applicantRatings.length;
  }
  
  // Check if an applicant has been rated
  Future<bool> hasBeenRated(String applicantId) async {
    final applicantRatings = await getApplicantRatings(applicantId);
    return applicantRatings.isNotEmpty;
  }
}
