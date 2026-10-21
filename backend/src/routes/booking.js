const Joi = require('joi');
const { Router } = require('express');
const { query } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { notifyStaffAboutNewBooking } = require('../services/staffNotify');

const router = Router();

const bookingSchema = Joi.object({
  booking_date: Joi.date().iso().required(),
  booking_time: Joi.string().trim().max(50).required(),
  guest_count: Joi.number().integer().min(1).required(),
  comment: Joi.string().trim().max(300).allow('', null).optional()
});

const updateSchema = Joi.object({
  booking_date: Joi.date().iso().optional(),
  booking_time: Joi.string().trim().max(50).optional(),
  guest_count: Joi.number().integer().min(1).optional(),
  comment: Joi.string().trim().max(300).allow('', null).optional()
}).min(1);

async function getBookingStatusIdByTitle(title, fallbackId = 1) {
  try {
    const r = await query('SELECT id_booking_status FROM booking_statuses WHERE LOWER(title) = LOWER($1) LIMIT 1', [title]);
    return r.rows[0]?.id_booking_status || fallbackId;
  } catch {
    return fallbackId;
  }
}

router.get('/', authenticateToken, async (req, res) => {
  const bookingsResult = await query(
    `SELECT b.*, bs.title AS booking_status_title
     FROM bookings b
     LEFT JOIN booking_statuses bs ON bs.id_booking_status = b.booking_status_id
     WHERE b.user_id = $1
     ORDER BY b.created_at DESC`,
    [req.user.id]
  );
  res.json(bookingsResult.rows);
});

router.post('/', authenticateToken, async (req, res) => {
  const { error, value } = bookingSchema.validate(req.body || {}, { abortEarly: false });
  if (error) return res.status(400).json({ error: error.details.map((d) => d.message).join(', ') });

  const createdStatusId = await getBookingStatusIdByTitle('Создано', 1);
  const bookingResult = await query(
    `INSERT INTO bookings (user_id, booking_date, booking_time, guest_count, comment, booking_status_id)
     VALUES ($1, $2::date, $3::time, $4, $5, $6)
     RETURNING *`,
    [
      req.user.id,
      value.booking_date,
      String(value.booking_time),
      Number(value.guest_count),
      value.comment ? String(value.comment) : null,
      createdStatusId
    ]
  );

  const booking = bookingResult.rows[0];

  try {
    const userResult = await query(
      `SELECT full_name
       FROM users
       WHERE id_user = $1
       LIMIT 1`,
      [req.user.id]
    );
    await notifyStaffAboutNewBooking({
      bookingId: booking.id_booking,
      customerName: userResult.rows[0]?.full_name,
      bookingDate: booking.booking_date,
      bookingTime: booking.booking_time,
      guestCount: booking.guest_count,
    });
  } catch (notifyErr) {
    console.error('Booking created staff notify error:', notifyErr);
  }

  res.status(201).json(booking);
});

router.put('/:bookingId', authenticateToken, async (req, res) => {
  const bookingId = Number(req.params.bookingId);
  if (!Number.isInteger(bookingId) || bookingId <= 0) {
    return res.status(400).json({ error: 'Некорректный идентификатор бронирования' });
  }

  const { error, value } = updateSchema.validate(req.body || {}, { abortEarly: false });
  if (error) return res.status(400).json({ error: error.details.map((d) => d.message).join(', ') });

  const currentResult = await query(
    `SELECT b.*, bs.title AS booking_status_title
     FROM bookings b
     LEFT JOIN booking_statuses bs ON bs.id_booking_status = b.booking_status_id
     WHERE b.id_booking = $1 AND b.user_id = $2 LIMIT 1`,
    [bookingId, req.user.id]
  );
  const current = currentResult.rows[0];
  if (!current) return res.status(404).json({ error: 'Бронирование не найдено' });
  if ((current.booking_status_title || '').toLowerCase() === 'отменен') {
    return res.status(409).json({ error: 'Нельзя редактировать отмененное бронирование' });
  }

  const updatedResult = await query(
    `UPDATE bookings
     SET booking_date = COALESCE($1::date, booking_date),
         booking_time = COALESCE($2::time, booking_time),
         guest_count = COALESCE($3, guest_count),
         comment = COALESCE($4, comment)
     WHERE id_booking = $5 AND user_id = $6
     RETURNING *`,
    [
      value.booking_date || null,
      value.booking_time != null ? String(value.booking_time) : null,
      value.guest_count != null ? Number(value.guest_count) : null,
      value.comment !== undefined ? (value.comment || null) : null,
      bookingId,
      req.user.id
    ]
  );
  res.json(updatedResult.rows[0]);
});

router.delete('/:bookingId', authenticateToken, async (req, res) => {
  const bookingId = Number(req.params.bookingId);
  if (!Number.isInteger(bookingId) || bookingId <= 0) {
    return res.status(400).json({ error: 'Некорректный идентификатор бронирования' });
  }
  const canceledStatusId = await getBookingStatusIdByTitle('Отменен', 3);
  const cancelResult = await query(
    `UPDATE bookings
     SET booking_status_id = $1
     WHERE id_booking = $2 AND user_id = $3
     RETURNING id_booking`,
    [canceledStatusId, bookingId, req.user.id]
  );
  if (!cancelResult.rows[0]) return res.status(404).json({ error: 'Бронирование не найдено' });
  res.status(204).send();
});

module.exports = router;
