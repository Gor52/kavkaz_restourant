const crypto = require('crypto');
const { Router } = require('express');
const rateLimit = require('express-rate-limit');
const Joi = require('joi');
const { query } = require('../db');
const { hashPassword, comparePassword, generateToken } = require('../utils/auth');
const {
  sendPasswordResetMail,
  sendLoginCodeMail,
  sendRegistrationSuccessMail
} = require('../utils/mail');

const router = Router();

const pwdStrong = Joi.string()
  .min(6)
  .max(50)
  .pattern(/^(?=.*[A-Za-z\u0400-\u04FF])(?=.*\d).+$/)
  .message('Пароль: 6–50 символов, минимум одна буква и одна цифра');

const loginSchema = Joi.object({ login: Joi.string().required(), password: Joi.string().min(6).required() });
const registerSchema = Joi.object({
  full_name: Joi.string().min(2).required(),
  phone: Joi.string().required(),
  email: Joi.string().trim().lowercase().email().required(),
  password: pwdStrong.required()
});

const forgotSchema = Joi.object({
  login: Joi.string().trim().email().required().messages({
    'string.email': 'Укажите корректный email',
    'any.required': 'Email обязателен'
  })
});

const resetSchema = Joi.object({
  code: Joi.string().trim().min(8).max(20).required(),
  password: pwdStrong.required()
});

const forgotPasswordLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 8,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Слишком много запросов. Попробуйте через час.' }
});

function sanitizeUser(row) {
  if (!row) return null;
  const { password_hash, ...rest } = row;
  return rest;
}

function maskEmail(email) {
  const s = String(email).trim();
  const at = s.indexOf('@');
  if (at < 1) return '***';
  const local = s.slice(0, at);
  const domain = s.slice(at + 1);
  const vis = local.slice(0, Math.min(2, local.length));
  return `${vis}***@${domain}`;
}

function generateResetCode() {
  return crypto.randomBytes(12).toString('base64url');
}

router.post('/login', async (req, res) => {
  try {
    const { error, value } = loginSchema.validate(req.body);
    if (error) return res.status(400).json({ error: error.details[0].message });
    const login = String(value.login).trim();
    const password = value.password;
    if (!login) return res.status(400).json({ error: 'Введите логин' });
    const userResult = await query(
      `SELECT * FROM users
       WHERE TRIM(phone) = $1
          OR (email IS NOT NULL AND LOWER(TRIM(email)) = LOWER($1))
       LIMIT 1`,
      [login]
    );
    const user = userResult.rows[0];
    if (!user) return res.status(401).json({ error: 'Неверный логин или пароль' });
    if (user.is_blocked) return res.status(403).json({ error: 'Аккаунт заблокирован' });
    const ok = await comparePassword(password, user.password_hash);
    if (!ok) return res.status(401).json({ error: 'Неверный логин или пароль' });
    const token = generateToken(user.id_user, user.role_id);
    return res.json({ access_token: token, user: sanitizeUser(user) });
  } catch (error) {
    console.error('Login error:', error);
    return res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

router.post('/register', async (req, res) => {
  try {
    const { error, value } = registerSchema.validate(req.body);
    if (error) return res.status(400).json({ error: error.details[0].message });
    const { full_name, phone, email, password } = value;
    const emailNorm = String(email).trim().toLowerCase();
    const existingResult = await query(
      `SELECT id_user FROM users
       WHERE phone = $1 OR LOWER(TRIM(email)) = LOWER($2)
       LIMIT 1`,
      [phone, emailNorm]
    );
    const existing = existingResult.rows[0];
    if (existing) return res.status(409).json({ error: 'Пользователь уже существует' });
    const password_hash = await hashPassword(password);
    const userResult = await query(
      `INSERT INTO users (role_id, full_name, phone, email, password_hash)
       VALUES (1, $1, $2, $3, $4)
       RETURNING *`,
      [full_name, phone, emailNorm, password_hash]
    );
    const user = userResult.rows[0];
    try {
      await sendRegistrationSuccessMail({
        to: emailNorm,
        fullName: full_name
      });
    } catch (mailErr) {
      console.error('Registration mail error:', mailErr);
    }
    return res.status(201).json({ user: sanitizeUser(user) });
  } catch (error) {
    console.error('Register error:', error);
    return res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

router.post('/forgot-password', forgotPasswordLimiter, async (req, res) => {
  try {
    const { error, value } = forgotSchema.validate(req.body || {});
    if (error) return res.status(400).json({ error: error.details[0].message });

    const emailLogin = String(value.login).trim().toLowerCase();
    const userResult = await query(
      `SELECT id_user, email, is_blocked FROM users
       WHERE email IS NOT NULL AND LOWER(TRIM(email)) = $1
       LIMIT 1`,
      [emailLogin]
    );
    const user = userResult.rows[0];
    if (!user) return res.status(404).json({ error: 'Аккаунт с таким email не найден' });
    if (user.is_blocked) return res.status(403).json({ error: 'Аккаунт заблокирован' });

    const code = generateResetCode();
    const emailTo = String(user.email).trim();

    await query(
      `UPDATE verification_codes
       SET is_used = TRUE, used_at = NOW()
       WHERE user_id = $1 AND code_type = 'password_reset' AND is_used = FALSE`,
      [user.id_user]
    );

    const ins = await query(
      `INSERT INTO verification_codes (user_id, code_type, code, expires_at, is_used)
       VALUES ($1, 'password_reset', $2, NOW() + INTERVAL '15 minutes', FALSE)
       RETURNING id_code`,
      [user.id_user, code]
    );
    const idCode = ins.rows[0].id_code;

    try {
      await sendPasswordResetMail({ to: emailTo, code });
    } catch (mailErr) {
      await query('DELETE FROM verification_codes WHERE id_code = $1', [idCode]);
      console.error('Forgot-password mail error:', mailErr);
      if (mailErr.code === 'MAIL_NOT_CONFIGURED') {
        return res.status(503).json({ error: 'Почтовый сервер не настроен.' });
      }
      return res.status(502).json({ error: 'Не удалось отправить письмо. Попробуйте позже.' });
    }

    return res.json({
      message: 'Письмо с кодом отправлено на указанный адрес электронной почты.',
      email_hint: maskEmail(emailTo)
    });
  } catch (err) {
    console.error('Forgot-password error:', err);
    if (err.code === '42P01') {
      return res.status(500).json({ error: 'Сервис восстановления пароля временно недоступен.' });
    }
    return res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

router.post('/request-login-code', forgotPasswordLimiter, async (req, res) => {
  try {
    const { error, value } = forgotSchema.validate(req.body || {});
    if (error) return res.status(400).json({ error: error.details[0].message });

    const emailLogin = String(value.login).trim().toLowerCase();
    const userResult = await query(
      `SELECT id_user, email, is_blocked FROM users
       WHERE email IS NOT NULL AND LOWER(TRIM(email)) = $1
       LIMIT 1`,
      [emailLogin]
    );
    const user = userResult.rows[0];
    if (!user) return res.status(404).json({ error: 'Аккаунт с таким email не найден' });
    if (user.is_blocked) return res.status(403).json({ error: 'Аккаунт заблокирован' });

    const code = generateResetCode();
    const emailTo = String(user.email).trim();

    await query(
      `UPDATE verification_codes
       SET is_used = TRUE, used_at = NOW()
       WHERE user_id = $1 AND code_type = 'login' AND is_used = FALSE`,
      [user.id_user]
    );

    const ins = await query(
      `INSERT INTO verification_codes (user_id, code_type, code, expires_at, is_used)
       VALUES ($1, 'login', $2, NOW() + INTERVAL '15 minutes', FALSE)
       RETURNING id_code`,
      [user.id_user, code]
    );
    const idCode = ins.rows[0].id_code;

    try {
      await sendLoginCodeMail({ to: emailTo, code });
    } catch (mailErr) {
      await query('DELETE FROM verification_codes WHERE id_code = $1', [idCode]);
      console.error('Login-code mail error:', mailErr);
      if (mailErr.code === 'MAIL_NOT_CONFIGURED') {
        return res.status(503).json({ error: 'Почтовый сервер не настроен.' });
      }
      return res.status(502).json({ error: 'Не удалось отправить письмо. Попробуйте позже.' });
    }

    return res.json({
      message: 'Письмо с кодом для входа отправлено.',
      email_hint: maskEmail(emailTo)
    });
  } catch (err) {
    console.error('Request-login-code error:', err);
    if (err.code === '42P01') {
      return res.status(500).json({ error: 'Сервис временно недоступен.' });
    }
    return res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

router.post('/login-with-code', async (req, res) => {
  try {
    const schema = Joi.object({
      login: Joi.string().trim().email().required(),
      code: Joi.string().trim().min(8).max(64).required()
    });
    const { error, value } = schema.validate(req.body || {});
    if (error) return res.status(400).json({ error: error.details[0].message });

    const emailLogin = String(value.login).trim().toLowerCase();
    const code = String(value.code).trim();

    const rowResult = await query(
      `SELECT vc.id_code, vc.user_id
       FROM verification_codes vc
       JOIN users u ON u.id_user = vc.user_id
       WHERE vc.code = $1
         AND vc.code_type = 'login'
         AND vc.is_used = FALSE
         AND vc.expires_at > NOW()
         AND LOWER(TRIM(u.email)) = $2
       ORDER BY vc.created_at DESC
       LIMIT 1`,
      [code, emailLogin]
    );
    const row = rowResult.rows[0];
    if (!row) {
      return res.status(401).json({ error: 'Неверный или просроченный код' });
    }

    const userResult = await query('SELECT * FROM users WHERE id_user = $1 LIMIT 1', [row.user_id]);
    const user = userResult.rows[0];
    if (!user) return res.status(401).json({ error: 'Пользователь не найден' });
    if (user.is_blocked) return res.status(403).json({ error: 'Аккаунт заблокирован' });

    await query(
      `UPDATE verification_codes SET is_used = TRUE, used_at = NOW() WHERE id_code = $1`,
      [row.id_code]
    );
    await query(
      `UPDATE verification_codes SET is_used = TRUE, used_at = NOW()
       WHERE user_id = $1 AND code_type = 'login' AND is_used = FALSE`,
      [row.user_id]
    );

    const token = generateToken(user.id_user, user.role_id);
    return res.json({ access_token: token, user: sanitizeUser(user) });
  } catch (err) {
    console.error('Login-with-code error:', err);
    if (err.code === '42P01') {
      return res.status(500).json({ error: 'Сервис временно недоступен.' });
    }
    return res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

router.post('/reset-password', async (req, res) => {
  try {
    const { error, value } = resetSchema.validate(req.body || {});
    if (error) return res.status(400).json({ error: error.details[0].message });

    const code = String(value.code).trim();
    const rowResult = await query(
      `SELECT id_code, user_id
       FROM verification_codes
       WHERE code = $1
         AND code_type = 'password_reset'
         AND is_used = FALSE
         AND expires_at > NOW()
       ORDER BY created_at DESC
       LIMIT 1`,
      [code]
    );
    const row = rowResult.rows[0];
    if (!row) {
      return res.status(400).json({ error: 'Неверный или просроченный код' });
    }

    const password_hash = await hashPassword(value.password);
    await query('UPDATE users SET password_hash = $1 WHERE id_user = $2', [password_hash, row.user_id]);
    await query(
      `UPDATE verification_codes SET is_used = TRUE, used_at = NOW() WHERE id_code = $1`,
      [row.id_code]
    );
    await query(
      `UPDATE verification_codes SET is_used = TRUE, used_at = NOW()
       WHERE user_id = $1 AND code_type = 'password_reset' AND is_used = FALSE`,
      [row.user_id]
    );

    return res.json({ message: 'Пароль обновлён' });
  } catch (err) {
    console.error('Reset-password error:', err);
    if (err.code === '42P01') {
      return res.status(500).json({ error: 'Сервис восстановления пароля временно недоступен.' });
    }
    return res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

router.post('/logout', async (req, res) => {
  return res.json({ message: 'Выход выполнен' });
});

module.exports = router;
