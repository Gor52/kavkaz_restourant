const Joi = require('joi');
const { query } = require('../db');
const { Router } = require('express');
const { authenticateToken, requireRole } = require('../middleware/auth');
const { createNotificationWithPush } = require('../services/userNotify');

const router = Router();

const deviceSchema = Joi.object({
  fcm_token: Joi.string().trim().min(1).max(500).required(),
  platform: Joi.string().valid('android', 'ios', 'web').allow(null, '').optional()
});

const deleteDeviceSchema = Joi.object({
  fcm_token: Joi.string().trim().min(1).max(500).required()
});

const sendSchema = Joi.object({
  user_id: Joi.number().integer().positive().required(),
  title: Joi.string().trim().min(1).max(100).required(),
  text: Joi.string().trim().min(1).max(300).required()
});

router.get('/', authenticateToken, async (req, res) => {
  const notificationsResult = await query(
    'SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC',
    [req.user.id]
  );
  res.json(notificationsResult.rows);
});

const upsertDeviceTokenHandler = async (req, res) => {
  try {
    const { error, value } = deviceSchema.validate(req.body || {});
    if (error) return res.status(400).json({ error: error.details[0].message });

    const platform =
      value.platform === '' || value.platform === undefined ? null : value.platform;

    const result = await query(
      `INSERT INTO device_tokens (user_id, fcm_token, platform, updated_at)
       VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
       ON CONFLICT (fcm_token) DO UPDATE SET
         user_id = EXCLUDED.user_id,
         platform = EXCLUDED.platform,
         updated_at = CURRENT_TIMESTAMP
       RETURNING *`,
      [req.user.id, value.fcm_token, platform]
    );
    return res.status(201).json(result.rows[0]);
  } catch (e) {
    if (e.code === '42P01') {
      return res.status(500).json({ error: 'Сервис push-уведомлений временно недоступен.' });
    }
    console.error('POST /notifications/device:', e);
    return res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
};

router.post('/device-token', authenticateToken, upsertDeviceTokenHandler);
router.post('/device', authenticateToken, upsertDeviceTokenHandler);

const deleteDeviceTokenHandler = async (req, res) => {
  try {
    const { error, value } = deleteDeviceSchema.validate(req.body || {});
    if (error) return res.status(400).json({ error: error.details[0].message });
    await query('DELETE FROM device_tokens WHERE user_id = $1 AND fcm_token = $2', [
      req.user.id,
      value.fcm_token
    ]);
    return res.status(204).send();
  } catch (e) {
    if (e.code === '42P01') return res.status(204).send();
    console.error('DELETE /notifications/device:', e);
    return res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
};

router.delete('/device-token', authenticateToken, deleteDeviceTokenHandler);
router.delete('/device', authenticateToken, deleteDeviceTokenHandler);

router.post('/send', authenticateToken, requireRole(2), async (req, res) => {
  try {
    const { error, value } = sendSchema.validate(req.body || {});
    if (error) return res.status(400).json({ error: error.details[0].message });

    const u = await query('SELECT id_user, is_blocked FROM users WHERE id_user = $1 LIMIT 1', [value.user_id]);
    if (!u.rows[0]) return res.status(404).json({ error: 'Пользователь не найден' });
    if (u.rows[0].is_blocked) return res.status(400).json({ error: 'Пользователь заблокирован' });

    const row = await createNotificationWithPush(value.user_id, value.title, value.text);
    return res.status(201).json(row);
  } catch (e) {
    console.error('POST /notifications/send:', e);
    return res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

router.put('/read-all', authenticateToken, async (req, res) => {
  await query('UPDATE notifications SET is_read = true WHERE user_id = $1', [req.user.id]);
  res.json({ message: 'Все уведомления отмечены как прочитанные' });
});

router.put('/:notificationId/read', authenticateToken, async (req, res) => {
  const notificationResult = await query(
    `UPDATE notifications
     SET is_read = true
     WHERE id_notification = $1 AND user_id = $2
     RETURNING *`,
    [Number(req.params.notificationId), req.user.id]
  );
  const notification = notificationResult.rows[0];
  if (!notification) return res.status(404).json({ error: 'Уведомление не найдено' });
  res.json(notification);
});

module.exports = router;
