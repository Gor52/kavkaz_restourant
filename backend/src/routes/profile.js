const { query } = require('../db');
const { Router } = require('express');
const Joi = require('joi');
const { authenticateToken } = require('../middleware/auth');
const { hashPassword, comparePassword } = require('../utils/auth');

const router = Router();

async function deleteIfTableExists(text, params) {
  try {
    await query(text, params);
  } catch (e) {
    if (e.code !== '42P01') throw e;
  }
}

function sanitizeUser(row) {
  if (!row) return null;
  const { password_hash, ...rest } = row;
  return rest;
}

router.get('/', authenticateToken, async (req, res) => {
  const userResult = await query('SELECT * FROM users WHERE id_user = $1 LIMIT 1', [req.user.id]);
  const user = userResult.rows[0];
  if (!user) return res.status(404).json({ error: 'Пользователь не найден' });
  return res.json(sanitizeUser(user));
});

const profileSchema = Joi.object({
  full_name: Joi.string().trim().min(2).max(50).required(),
  phone: Joi.string().trim().min(3).max(20).required(),
  email: Joi.string().trim().email().max(100).allow(null, '').optional(),
  confirm_password: Joi.string().allow('', null).optional()
});

router.put('/', authenticateToken, async (req, res) => {
  const cur = (await query('SELECT * FROM users WHERE id_user = $1 LIMIT 1', [req.user.id])).rows[0];
  if (!cur) return res.status(404).json({ error: 'Пользователь не найден' });

  const { error, value } = profileSchema.validate(req.body || {}, { abortEarly: false });
  if (error) return res.status(400).json({ error: error.details.map((d) => d.message).join(', ') });

  const b = value;
  const full_name =
    b.full_name !== undefined
      ? (b.full_name == null ? null : String(b.full_name).trim() || null)
      : cur.full_name;
  const phone =
    b.phone !== undefined
      ? (b.phone == null ? null : String(b.phone).trim() || null)
      : cur.phone;
  const email =
    b.email !== undefined
      ? (b.email == null ? null : String(b.email).trim().toLowerCase() || null)
      : cur.email;

  const curPhone = String(cur.phone || '').trim();
  const newPhone = String(phone || '').trim();
  if (newPhone !== curPhone) {
    const cp = b.confirm_password;
    if (cp == null || String(cp).trim() === '') {
      return res.status(400).json({
        error:
          'Для смены номера телефона укажите текущий пароль в поле confirm_password'
      });
    }
    const ok = await comparePassword(String(cp).trim(), cur.password_hash);
    if (!ok) {
      return res.status(400).json({ error: 'Неверный текущий пароль' });
    }
  }

  const updatedResult = await query(
    `UPDATE users
     SET full_name = $1, phone = $2, email = $3
     WHERE id_user = $4
     RETURNING *`,
    [full_name, phone, email, req.user.id]
  );
  const updated = updatedResult.rows[0];
  return res.json(sanitizeUser(updated));
});

const pwdStrongProfile = Joi.string()
  .min(6)
  .max(50)
  .pattern(/^(?=.*[A-Za-z\u0400-\u04FF])(?=.*\d).+$/)
  .message('Пароль: 6–50 символов, минимум одна буква и одна цифра');

const passwordSchema = Joi.object({
  current_password: Joi.string().required(),
  new_password: pwdStrongProfile.required()
});

router.put('/password', authenticateToken, async (req, res) => {
  const { error, value } = passwordSchema.validate(req.body || {}, { abortEarly: false });
  if (error) return res.status(400).json({ error: error.details.map((d) => d.message).join(', ') });

  const userResult = await query('SELECT * FROM users WHERE id_user = $1 LIMIT 1', [req.user.id]);
  const user = userResult.rows[0];
  if (!user) return res.status(404).json({ error: 'Пользователь не найден' });

  const ok = await comparePassword(value.current_password, user.password_hash);
  if (!ok) return res.status(400).json({ error: 'Текущий пароль введен неверно' });

  const newHash = await hashPassword(value.new_password);
  await query('UPDATE users SET password_hash = $1 WHERE id_user = $2', [newHash, req.user.id]);
  return res.json({ message: 'Пароль обновлен' });
});

router.delete('/', authenticateToken, async (req, res) => {
  const uid = req.user.id;
  try {
    await query(
      `UPDATE users
       SET is_blocked = TRUE,
           full_name = CONCAT('[DELETED] ', full_name),
           email = NULL
       WHERE id_user = $1
       RETURNING id_user`,
      [uid]
    );
    await deleteIfTableExists('DELETE FROM delivery_addresses WHERE user_id = $1', [uid]);
    await deleteIfTableExists('DELETE FROM carts WHERE user_id = $1', [uid]);
    return res.status(204).send();
  } catch (e) {
    console.error('Delete account:', e);
    return res.status(500).json({ error: 'Не удалось удалить аккаунт' });
  }
});

const addressBodySchema = Joi.object({
  address_text: Joi.string().min(1).required(),
  comment: Joi.string().allow('', null).optional(),
  is_default: Joi.boolean().optional()
});

router.get('/addresses', authenticateToken, async (req, res) => {
  const r = await query(
    `SELECT id_address, user_id, address_text, comment, is_default, created_at
     FROM delivery_addresses
     WHERE user_id = $1
     ORDER BY is_default DESC, created_at DESC`,
    [req.user.id]
  );
  return res.json(r.rows);
});

router.post('/addresses', authenticateToken, async (req, res) => {
  const { error, value } = addressBodySchema.validate(req.body || {}, { abortEarly: false });
  if (error) return res.status(400).json({ error: error.details.map((d) => d.message).join(', ') });

  const isDefault = Boolean(value.is_default);
  if (isDefault) {
    await query('UPDATE delivery_addresses SET is_default = false WHERE user_id = $1', [req.user.id]);
  }

  const ins = await query(
    `INSERT INTO delivery_addresses (user_id, address_text, comment, is_default)
     VALUES ($1, $2, $3, $4)
     RETURNING id_address, user_id, address_text, comment, is_default, created_at`,
    [
      req.user.id,
      value.address_text.trim(),
      value.comment == null || value.comment === '' ? null : String(value.comment),
      isDefault
    ]
  );
  return res.status(201).json(ins.rows[0]);
});

router.put('/addresses/:addressId', authenticateToken, async (req, res) => {
  const addressId = parseInt(req.params.addressId, 10);
  if (Number.isNaN(addressId)) return res.status(400).json({ error: 'Некорректный идентификатор адреса' });

  const { error, value } = addressBodySchema.validate(req.body || {}, { abortEarly: false });
  if (error) return res.status(400).json({ error: error.details.map((d) => d.message).join(', ') });

  const own = await query(
    'SELECT id_address FROM delivery_addresses WHERE id_address = $1 AND user_id = $2',
    [addressId, req.user.id]
  );
  if (!own.rows[0]) return res.status(404).json({ error: 'Адрес не найден' });

  const isDefault = Boolean(value.is_default);
  if (isDefault) {
    await query('UPDATE delivery_addresses SET is_default = false WHERE user_id = $1', [req.user.id]);
  }

  const comment =
    value.comment == null || value.comment === '' ? null : String(value.comment);
  const trimmed = value.address_text.trim();

  const upd = await query(
    `UPDATE delivery_addresses
     SET address_text = $1, comment = $2, is_default = $3
     WHERE id_address = $4 AND user_id = $5
     RETURNING id_address, user_id, address_text, comment, is_default, created_at`,
    [trimmed, comment, isDefault, addressId, req.user.id]
  );
  return res.json(upd.rows[0]);
});

router.delete('/addresses/:addressId', authenticateToken, async (req, res) => {
  const addressId = parseInt(req.params.addressId, 10);
  if (Number.isNaN(addressId)) return res.status(400).json({ error: 'Некорректный идентификатор адреса' });

  const del = await query(
    'DELETE FROM delivery_addresses WHERE id_address = $1 AND user_id = $2 RETURNING id_address',
    [addressId, req.user.id]
  );
  if (!del.rows[0]) return res.status(404).json({ error: 'Адрес не найден' });
  return res.status(204).send();
});

router.get('/bonus-history', authenticateToken, async (req, res) => {
  const r = await query(
    `SELECT bo.id_bonus_operation, bo.user_id, bo.bonus_operation_type_id, bo.bonus_amount,
            bo.order_id, bo.created_at, bot.title AS operation_title
     FROM bonus_operations bo
     LEFT JOIN bonus_operation_types bot ON bot.id_bonus_operation_type = bo.bonus_operation_type_id
     WHERE bo.user_id = $1
     ORDER BY bo.created_at DESC NULLS LAST, bo.id_bonus_operation DESC`,
    [req.user.id]
  );
  return res.json(r.rows);
});

router.get('/bonus-balance', authenticateToken, async (req, res) => {
  const r = await query(
    `SELECT
      COALESCE(
        SUM(
          CASE
            WHEN LOWER(bot.title) = LOWER('Начисление') THEN bo.bonus_amount
            WHEN LOWER(bot.title) = LOWER('Списание') THEN -bo.bonus_amount
            ELSE 0
          END
        ),
        0
      )::int AS bonus_balance
     FROM bonus_operations bo
     JOIN bonus_operation_types bot ON bot.id_bonus_operation_type = bo.bonus_operation_type_id
     WHERE bo.user_id = $1`,
    [req.user.id]
  );
  return res.json({ bonus_balance: Number(r.rows[0]?.bonus_balance || 0) });
});

module.exports = router;
