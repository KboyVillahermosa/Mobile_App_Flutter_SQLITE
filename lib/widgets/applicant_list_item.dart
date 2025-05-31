import 'package:flutter/material.dart';
import '../services/rating_service.dart';
import '../screens/rating_screen.dart';

class ApplicantListItem extends StatelessWidget {
  final Map<String, dynamic> applicantData;

  ApplicantListItem({required this.applicantData});

  void _onMarkCompleted(BuildContext context, Map<String, dynamic> applicantData) async {
    // Your existing code to mark as completed
    // ...
    
    // After marking as completed, navigate to rating screen
    final RatingService ratingService = RatingService();
    final bool alreadyRated = await ratingService.hasBeenRated(applicantData['id']);
    
    if (!alreadyRated) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RatingScreen(
            applicantData: applicantData,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(applicantData['name']),
      subtitle: Text('Rating: ${applicantData['rating']}'),
      trailing: IconButton(
        icon: Icon(Icons.check),
        onPressed: () => _onMarkCompleted(context, applicantData),
      ),
    );
  }
}