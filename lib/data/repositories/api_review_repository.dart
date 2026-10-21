import '../models/review_model.dart';
import '../sources/remote/api_service.dart';

class ApiReviewRepository {
  final ApiService _apiService;

  ApiReviewRepository(this._apiService);

  Future<List<ReviewModel>> getDishReviews(int dishId) async {
    final response = await _apiService.get<List<dynamic>>(
      '/reviews',
      queryParameters: {'dish_id': dishId},
    );

    return (response.data ?? [])
        .map((item) => ReviewModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ReviewModel> addReview({
    required int dishId,
    required int rating,
    required String reviewText,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      '/reviews',
      data: {
        'dish_id': dishId,
        'rating': rating,
        'review_text': reviewText,
      },
    );

    if (response.data == null) {
      throw Exception('Не удалось добавить отзыв');
    }

    return ReviewModel.fromJson(response.data!);
  }

  Future<ReviewModel> updateReview({
    required int reviewId,
    required int rating,
    required String reviewText,
  }) async {
    final response = await _apiService.put<Map<String, dynamic>>(
      '/reviews/$reviewId',
      data: {
        'rating': rating,
        'review_text': reviewText,
      },
    );

    if (response.data == null) {
      throw Exception('Не удалось обновить отзыв');
    }

    return ReviewModel.fromJson(response.data!);
  }

  Future<void> deleteReview(int reviewId) async {
    await _apiService.delete<void>('/reviews/$reviewId');
  }
}
