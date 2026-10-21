class ReviewModel {
  final int id;
  final int userId;
  final int dishId;
  final int rating;
  final String reviewText;
  final DateTime? publishedAt;
  final String? userName;

  const ReviewModel({
    required this.id,
    required this.userId,
    required this.dishId,
    required this.rating,
    required this.reviewText,
    this.publishedAt,
    this.userName,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id_review'] as int,
      userId: json['user_id'] as int,
      dishId: json['dish_id'] as int,
      rating: json['rating'] as int,
      reviewText: json['review_text'] as String,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'].toString())
          : null,
      userName: json['user_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_review': id,
      'user_id': userId,
      'dish_id': dishId,
      'rating': rating,
      'review_text': reviewText,
      'published_at': publishedAt?.toIso8601String(),
      'user_name': userName,
    };
  }
}