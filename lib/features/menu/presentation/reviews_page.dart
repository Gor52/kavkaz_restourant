import 'package:flutter/material.dart';

import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/review_card.dart';
import '../../../data/models/review_model.dart';
import '../../../shared/enums/user_role.dart';

class ReviewsPage extends StatefulWidget {
  final int dishId;

  const ReviewsPage({
    super.key,
    required this.dishId,
  });

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  final _formKey = GlobalKey<FormState>();
  final _reviewController = TextEditingController();

  int _rating = 5;
  List<ReviewModel> _reviews = [];
  bool _isLoading = true;
  bool _submitting = false;
  String? _error;
  bool _isStaff = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final roleTitle = await AppDi.sessionService.getRole();
    if (!mounted) return;
    setState(() {
      _isStaff = UserRole.fromTitle(roleTitle).isStaff;
    });
    await _loadReviews();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reviews =
          await AppDi.reviewRepository.getDishReviews(widget.dishId);

      if (!mounted) return;
      setState(() {
        _reviews = reviews;
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

  Future<void> _addReview() async {
    if (_isStaff) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      await AppDi.reviewRepository.addReview(
        dishId: widget.dishId,
        rating: _rating,
        reviewText: _reviewController.text.trim(),
      );

      _reviewController.clear();
      _rating = 5;

      await _loadReviews();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Отзыв отправлен')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось отправить отзыв.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Отзывы'),
      ),
      body: _isLoading
          ? const LoadingView(message: 'Загружаем отзывы...')
          : _error != null
              ? ErrorState(
                  title: 'Ошибка загрузки',
                  subtitle: _error!,
                  onRetry: _loadReviews,
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (!_isStaff)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Оставить отзыв',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: List.generate(
                                    5,
                                    (index) => IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _rating = index + 1;
                                        });
                                      },
                                      icon: Icon(
                                        index < _rating
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _reviewController,
                                  maxLines: 4,
                                  maxLength: 500,
                                  validator: Validators.validateReview,
                                  decoration: const InputDecoration(
                                    hintText: 'Текст отзыва',
                                  ),
                                ),
                                const SizedBox(height: 14),
                                PrimaryButton(
                                  text: 'Отправить отзыв',
                                  isLoading: _submitting,
                                  onPressed: _addReview,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (!_isStaff) const SizedBox(height: 18),
                    const Text(
                      'Отзывы пользователей',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_reviews.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Text(
                            'Пока нет отзывов',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._reviews.map(
                        (review) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ReviewCard(review: review),
                        ),
                      ),
                  ],
                ),
    );
  }
}