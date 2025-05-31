class Rating {
  final int? id;
  final int jobId;
  final int raterId;
  final int ratedId;
  final int rating;
  final String? comment;
  final String createdAt;

  Rating({
    this.id,
    required this.jobId,
    required this.raterId,
    required this.ratedId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobId': jobId,
      'raterId': raterId,
      'ratedId': ratedId,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt,
    };
  }

  factory Rating.fromMap(Map<String, dynamic> map) {
    return Rating(
      id: map['id'],
      jobId: map['jobId'],
      raterId: map['raterId'],
      ratedId: map['ratedId'],
      rating: map['rating'],
      comment: map['comment'],
      createdAt: map['createdAt'],
    );
  }
}