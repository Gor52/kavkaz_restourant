import 'package:postgres/postgres.dart';

import '../../app/di.dart';
import '../models/review_model.dart';
import '../sources/remote/postgres_service.dart';

class ReviewRepository {
  final PostgresService _postgresService;

  ReviewRepository(this._postgresService);

  Future<List<ReviewModel>> getDishReviews(int dishId) async {
    final conn = await _postgresService.connection;

    final result = await conn.execute(
      Sql.named(r'''
        SELECT
          r.id_review,
          r.user_id,
          r.dish_id,
          r.rating,
          r.review_text,
          r.published_at,
          u.full_name AS user_name
        FROM reviews r
        JOIN users u ON u.id_user = r.user_id
        WHERE r.dish_id = @dish_id
        ORDER BY r.id_review DESC
      '''),
      parameters: {
        'dish_id': dishId,
      },
    );

    return result.map((row) {
      final data = row.toColumnMap();
      return ReviewModel(
        id: data['id_review'] as int,
        userId: data['user_id'] as int,
        dishId: data['dish_id'] as int,
        rating: data['rating'] as int,
        reviewText: data['review_text'] as String,
        publishedAt: data['published_at'] as DateTime?,
        userName: data['user_name'] as String?,
      );
    }).toList();
  }

  Future<ReviewModel> addReview({
    required int dishId,
    required int rating,
    required String reviewText,
  }) async {
    final userId = await AppDi.sessionService.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final conn = await _postgresService.connection;

    final result = await conn.execute(
      Sql.named(r'''
        INSERT INTO reviews (
          user_id,
          dish_id,
          rating,
          review_text
        )
        VALUES (
          @user_id,
          @dish_id,
          @rating,
          @review_text
        )
        RETURNING
          id_review,
          user_id,
          dish_id,
          rating,
          review_text,
          published_at
      '''),
      parameters: {
        'user_id': userId,
        'dish_id': dishId,
        'rating': rating,
        'review_text': reviewText,
      },
    );

    final data = result.first.toColumnMap();

    return ReviewModel(
      id: data['id_review'] as int,
      userId: data['user_id'] as int,
      dishId: data['dish_id'] as int,
      rating: data['rating'] as int,
      reviewText: data['review_text'] as String,
      publishedAt: data['published_at'] as DateTime?,
      userName: 'Вы',
    );
  }

  Future<ReviewModel> updateReview({
    required int reviewId,
    required int rating,
    required String reviewText,
  }) async {
    final conn = await _postgresService.connection;

    final result = await conn.execute(
      Sql.named(r'''
        UPDATE reviews
        SET rating = @rating,
            review_text = @review_text
        WHERE id_review = @review_id
        RETURNING
          id_review,
          user_id,
          dish_id,
          rating,
          review_text,
          published_at
      '''),
      parameters: {
        'rating': rating,
        'review_text': reviewText,
        'review_id': reviewId,
      },
    );

    final data = result.first.toColumnMap();

    return ReviewModel(
      id: data['id_review'] as int,
      userId: data['user_id'] as int,
      dishId: data['dish_id'] as int,
      rating: data['rating'] as int,
      reviewText: data['review_text'] as String,
      publishedAt: data['published_at'] as DateTime?,
    );
  }

  Future<void> deleteReview(int reviewId) async {
    final conn = await _postgresService.connection;

    await conn.execute(
      Sql.named(r'''
        DELETE FROM reviews
        WHERE id_review = @review_id
      '''),
      parameters: {
        'review_id': reviewId,
      },
    );
  }
}