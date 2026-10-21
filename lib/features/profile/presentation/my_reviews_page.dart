import 'package:flutter/material.dart';

import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/review_card.dart';
import '../../../data/models/review_model.dart';

class MyReviewsPage extends StatefulWidget {
  const MyReviewsPage({super.key});

  @override
  State<MyReviewsPage> createState() => _MyReviewsPageState();
}

class _MyReviewsPageState extends State<MyReviewsPage> {
  List<({ReviewModel review, String dishTitle})> _entries = [];
  bool _isLoading = true;
  String? _error;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMyReviews();
  }

  Future<void> _loadMyReviews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await AppDi.profileRepository.getProfile();
      final dishes = await AppDi.menuRepository.getDishes();

      final entries = <({ReviewModel review, String dishTitle})>[];

      for (final dish in dishes) {
        final dishReviews = await AppDi.reviewRepository.getDishReviews(dish.id);
        for (final review in dishReviews) {
          if (review.userId != profile.id) continue;
          entries.add((review: review, dishTitle: dish.title));
        }
      }

      entries.sort((a, b) {
        final da = a.review.publishedAt;
        final db = b.review.publishedAt;
        if (da == null && db == null) {
          return b.review.id.compareTo(a.review.id);
        }
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

      if (!mounted) return;
      setState(() {
        _entries = entries;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(e, fallback: 'Не удалось загрузить отзывы.');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteReview(ReviewModel review) async {
    try {
      setState(() => _actionLoading = true);
      await AppDi.reviewRepository.deleteReview(review.id);
      await _loadMyReviews();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Отзыв удален')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось удалить отзыв.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Мои отзывы'),
      ),
      body: _isLoading
          ? const LoadingView(message: 'Загружаем отзывы...')
          : _error != null
              ? ErrorState(
                  title: 'Ошибка загрузки',
                  subtitle: _error!,
                  onRetry: _loadMyReviews,
                )
              : _entries.isEmpty
                  ? const Center(
                      child: Text(
                        'У вас пока нет отзывов',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadMyReviews,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _entries.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          final entry = _entries[index];
                          return ReviewCard(
                            review: entry.review,
                            dishTitle: entry.dishTitle,
                            showActions: true,
                            onEdit: null,
                            onDelete: _actionLoading
                                ? null
                                : () => _deleteReview(entry.review),
                          );
                        },
                      ),
                    ),
    );
  }
}