import 'package:flutter/material.dart';

class RatingDialog extends StatefulWidget {
  final int jobId;
  final int raterId;
  final int ratedId;
  final String ratedName;
  final String type; // 'worker' or 'employer'
  final String jobTitle;

  const RatingDialog({
    Key? key,
    required this.jobId,
    required this.raterId,
    required this.ratedId,
    required this.ratedName,
    required this.type,
    required this.jobTitle,
  }) : super(key: key);

  @override
  _RatingDialogState createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  double _rating = 5.0;
  final _reviewController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Rate ${widget.ratedName}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'for "${widget.jobTitle}"',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            
            // Star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 36,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1.0;
                    });
                  },
                );
              }),
            ),
            SizedBox(height: 16),
            
            // Review text field
            TextField(
              controller: _reviewController,
              decoration: InputDecoration(
                hintText: 'Write your review (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              maxLines: 3,
            ),
            SizedBox(height: 24),
            
            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'jobId': widget.jobId,
                    'raterId': widget.raterId,
                    'ratedId': widget.ratedId,
                    'rating': _rating,
                    'review': _reviewController.text,
                    'timestamp': DateTime.now().toIso8601String(),
                    'type': widget.type,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF06D6A0),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Submit Rating',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}