const Joi = require('joi');
const { query } = require('../db');
const { Router } = require('express');
const { authenticateToken, requireRole } = require('../middleware/auth');
const router = Router();

const createSchema = Joi.object({
  dish_id: Joi.number().integer().positive().required(),
  rating: Joi.number().integer().min(1).max(5).required(),
  review_text: Joi.string().trim().min(1).max(500).required()
});

const updateSchema = Joi.object({
  rating: Joi.number().integer().min(1).max(5).required(),
  review_text: Joi.string().trim().min(1).max(500).required()
});

router.get('/', async (req, res) => {
  const dishId = Number(req.query.dish_id);
  if (!dishId) return res.status(400).json({ error: 'Необходимо указать идентификатор блюда' });
  const reviewsResult = await query(
    `SELECT r.*, u.full_name AS user_name
     FROM reviews r
     LEFT JOIN users u ON u.id_user = r.user_id
     WHERE r.dish_id = $1
     ORDER BY r.published_at DESC`,
    [dishId]
  );
  const reviews = reviewsResult.rows;
  res.json(reviews);
});
router.post('/', authenticateToken, async (req, res) => {
  const { error, value } = createSchema.validate(req.body || {}, { abortEarly: false });
  if (error) return res.status(400).json({ error: error.details.map((d) => d.message).join(', ') });

  if (Number(req.user.roleId) >= 2) {
    return res.status(403).json({ error: 'Менеджер и администратор не могут оставлять отзывы' });
  }

  const canReviewResult = await query(
    `SELECT 1
     FROM order_items oi
     JOIN orders o ON o.id_order = oi.order_id
     JOIN order_statuses os ON os.id_order_status = o.order_status_id
     WHERE o.user_id = $1
       AND oi.dish_id = $2
       AND LOWER(os.title) = LOWER('Завершен')
     LIMIT 1`,
    [req.user.id, Number(value.dish_id)]
  );
  if (!canReviewResult.rows[0]) {
    return res.status(403).json({ error: 'Оставить отзыв можно только после завершенного заказа' });
  }

  const reviewResult = await query(
    `INSERT INTO reviews (user_id, dish_id, rating, review_text)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [req.user.id, Number(value.dish_id), Number(value.rating), String(value.review_text)]
  );
  const review = reviewResult.rows[0];
  res.status(201).json(review);
});

router.put('/:reviewId', authenticateToken, async (req, res) => {
  const reviewId = Number(req.params.reviewId);
  if (!Number.isInteger(reviewId) || reviewId <= 0) {
    return res.status(400).json({ error: 'Некорректный идентификатор отзыва' });
  }

  const { error, value } = updateSchema.validate(req.body || {}, { abortEarly: false });
  if (error) return res.status(400).json({ error: error.details.map((d) => d.message).join(', ') });

  const updatedResult = await query(
    `UPDATE reviews
     SET rating = $1, review_text = $2
     WHERE id_review = $3 AND user_id = $4
     RETURNING *`,
    [Number(value.rating), String(value.review_text), reviewId, req.user.id]
  );
  const updated = updatedResult.rows[0];
  if (!updated) return res.status(404).json({ error: 'Отзыв не найден' });
  return res.json(updated);
});

router.delete('/:reviewId', authenticateToken, async (req, res) => {
  const reviewId = Number(req.params.reviewId);
  if (!Number.isInteger(reviewId) || reviewId <= 0) {
    return res.status(400).json({ error: 'Некорректный идентификатор отзыва' });
  }
  const delResult = await query(
    'DELETE FROM reviews WHERE id_review = $1 AND user_id = $2 RETURNING id_review',
    [reviewId, req.user.id]
  );
  if (!delResult.rows[0]) return res.status(404).json({ error: 'Отзыв не найден' });
  return res.status(204).send();
});

router.delete('/admin/:reviewId', authenticateToken, requireRole(3), async (req, res) => {
  const reviewId = Number(req.params.reviewId);
  if (!Number.isInteger(reviewId) || reviewId <= 0) {
    return res.status(400).json({ error: 'Некорректный идентификатор отзыва' });
  }
  const delResult = await query('DELETE FROM reviews WHERE id_review = $1 RETURNING id_review', [reviewId]);
  if (!delResult.rows[0]) return res.status(404).json({ error: 'Отзыв не найден' });
  return res.status(204).send();
});

module.exports = router;
