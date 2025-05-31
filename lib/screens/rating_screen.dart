import 'package:flutter/material.dart';
import '../services/rating_service.dart';

class RatingScreen extends StatefulWidget {
  final Map<String, dynamic>? applicantData;

  const RatingScreen({Key? key, this.applicantData}) : super(key: key);

  @override
  _RatingScreenState createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  double _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  final RatingService _ratingService = RatingService();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Applicant'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.applicantData != null) ...[
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.applicantData!['name'] ?? 'Unnamed Applicant',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Email: ${widget.applicantData!['email'] ?? 'N/A'}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Position: ${widget.applicantData!['position'] ?? 'N/A'}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Text(
              'Rate the applicant:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 1; i <= 5; i++)
                    IconButton(
                      icon: Icon(
                        i <= _rating
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 40,
                      ),
                      onPressed: () {
                        setState(() {
                          _rating = i.toDouble();
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Additional Comments:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter your comments here...',
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  _submitRating();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
                  child: Text('Submit Rating'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a rating before submitting.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Prepare rating data
    final ratingData = {
      'applicantId': widget.applicantData?['id'],
      'rating': _rating,
      'comment': _commentController.text,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    // Save rating to storage
    try {
      await _ratingService.saveRating(ratingData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rating submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate back after submission
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pop(context, ratingData);  // Return rating data to previous screen
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting rating: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}
