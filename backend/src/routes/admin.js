const { Router } = require('express');
const Joi = require('joi');
const fs = require('fs/promises');
const path = require('path');
const multer = require('multer');
const { query, pool } = require('../db');
const { authenticateToken, requireRole } = require('../middleware/auth');
const { sendPushToUser } = require('../utils/sendPush');
const router = Router();
const BONUS_ACCRUAL_PERCENT = 0.05;

const dishPhotosDir = path.join(__dirname, '..', '..', 'uploads', 'dishes');
const imageUpload = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => cb(null, dishPhotosDir),
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase();
      const safeExt = ['.jpg', '.jpeg', '.png', '.webp'].includes(ext) ? ext : '.jpg';
      cb(null, `dish_${Date.now()}_${Math.round(Math.random() * 1e9)}${safeExt}`);
    }
  }),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (file.mimetype && file.mimetype.startsWith('image/')) {
      cb(null, true);
      return;
    }
    cb(new Error('Разрешены только изображения'));
  }
});

const categoryBodySchema = Joi.object({
  title: Joi.string().trim().min(1).max(100).required(),
  sort_order: Joi.number().integer().min(1).required()
});
const updateOrderStatusSchema = Joi.object({
  order_status_id: Joi.number().integer().positive().required()
});
const updateBookingStatusSchema = Joi.object({
  booking_status_id: Joi.number().integer().positive().required()
});
const updateRoleSchema = Joi.object({
  role_id: Joi.number().integer().min(1).max(3).required()
});
const adjustUserBonusSchema = Joi.object({
  operation_type: Joi.string().trim().valid('accrual', 'writeoff', 'set_balance').required(),
  bonus_amount: Joi.number().integer().positive().required(),
  comment: Joi.string().trim().max(200).allow('', null).optional()
});

async function getBonusOperationTypeIdByTitle(title, fallbackId = null) {
  try {
    const r = await query(
      'SELECT id_bonus_operation_type FROM bonus_operation_types WHERE LOWER(title) = LOWER($1) LIMIT 1',
      [title]
    );
    return r.rows[0]?.id_bonus_operation_type || fallbackId;
  } catch {
    return fallbackId;
  }
}

async function getOrderStatusIdByTitle(title, fallbackId = null) {
  try {
    const r = await query('SELECT id_order_status FROM order_statuses WHERE LOWER(title) = LOWER($1) LIMIT 1', [title]);
    return r.rows[0]?.id_order_status || fallbackId;
  } catch {
    return fallbackId;
  }
}

let hasOrderItemsDishTitleColumnCache = null;
async function hasOrderItemsDishTitleColumn() {
  if (hasOrderItemsDishTitleColumnCache != null) return hasOrderItemsDishTitleColumnCache;
  try {
    const r = await query(
      `SELECT 1
       FROM information_schema.columns
       WHERE table_schema = 'public'
         AND table_name = 'order_items'
         AND column_name = 'dish_title'
       LIMIT 1`
    );
    hasOrderItemsDishTitleColumnCache = Boolean(r.rows[0]);
  } catch {
    hasOrderItemsDishTitleColumnCache = false;
  }
  return hasOrderItemsDishTitleColumnCache;
}

async function getBookingStatusIdByTitle(title, fallbackId = null) {
  try {
    const r = await query('SELECT id_booking_status FROM booking_statuses WHERE LOWER(title) = LOWER($1) LIMIT 1', [title]);
    return r.rows[0]?.id_booking_status || fallbackId;
  } catch {
    return fallbackId;
  }
}

async function hasAccrualByOrderId(orderId, amount) {
  const accrualTypeId = await getBonusOperationTypeIdByTitle('Начисление', 1);
  if (!accrualTypeId) return false;
  const r = await query(
    `SELECT 1
     FROM bonus_operations
     WHERE order_id = $1
       AND bonus_operation_type_id = $2
       AND bonus_amount = $3
     LIMIT 1`,
    [orderId, accrualTypeId, amount]
  );
  return Boolean(r.rows[0]);
}

async function getUserBonusBalanceById(userId) {
  const result = await query(
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
      )::int AS balance
     FROM bonus_operations bo
     JOIN bonus_operation_types bot ON bot.id_bonus_operation_type = bo.bonus_operation_type_id
     WHERE bo.user_id = $1`,
    [userId]
  );
  return Number(result.rows[0]?.balance || 0);
}
const importPayloadSchema = Joi.alternatives()
  .try(
    Joi.array().items(Joi.object()).min(1),
    Joi.object({
      categories: Joi.array().items(Joi.object()).optional(),
      dishes: Joi.array().items(Joi.object()).optional()
    }).unknown(true)
  )
  .required()
  .messages({
    'alternatives.match':
      'payload: непустой массив объектов или объект с полями categories и/или dishes'
  });

const importSchema = Joi.object({
  import_type: Joi.string().trim().min(1).max(50).required(),
  file_name: Joi.string().trim().min(1).max(200).required(),
  payload: importPayloadSchema,
  comment: Joi.string().allow('', null).max(200).optional()
});
const exportSchema = Joi.object({
  export_type: Joi.string().trim().min(1).max(50).required(),
  date_from: Joi.date().iso().required(),
  date_to: Joi.date().iso().required(),
  format: Joi.string().trim().valid('json', 'csv').required(),
  order_status_id: Joi.number().integer().positive().optional(),
  category_id: Joi.number().integer().positive().optional()
});
const dishBodySchema = Joi.object({
  category_id: Joi.number().integer().positive().required(),
  title: Joi.string().trim().min(1).max(100).required(),
  description: Joi.string().trim().min(1).max(500).required(),
  ingredients: Joi.string().trim().min(1).max(300).required(),
  price: Joi.number().positive().required(),
  weight: Joi.number().integer().positive().required(),
  calories: Joi.number().integer().positive().allow(null).optional(),
  allergens: Joi.string().trim().max(200).allow('', null).optional(),
  photo_path: Joi.string().trim().max(500).allow('', null).optional(),
  is_available: Joi.boolean().required()
});

function normalizeImportRow(row) {
  if (!row || typeof row !== 'object') return {};
  const out = {};
  for (const [rawKey, val] of Object.entries(row)) {
    const key = String(rawKey)
      .trim()
      .toLowerCase()
      .replace(/\s+/g, '_');
    out[key] = val;
  }
  return out;
}

function parseFlexibleNumber(value) {
  if (value == null || value === '') return null;
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  const s = String(value)
    .trim()
    .replace(/\s+/g, '')
    .replace(',', '.');
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}

function parsePositiveInt(value) {
  const n = parseInt(String(value).trim(), 10);
  if (!Number.isFinite(n) || n <= 0) return null;
  return n;
}

function extractImportPayload(importType, payload) {
  if (Array.isArray(payload)) {
    if (importType === 'categories') {
      return { categories: payload.map(normalizeImportRow), dishes: [] };
    }
    return { categories: [], dishes: payload.map(normalizeImportRow) };
  }
  const obj = payload || {};
  return {
    categories: Array.isArray(obj.categories) ? obj.categories.map(normalizeImportRow) : [],
    dishes: Array.isArray(obj.dishes) ? obj.dishes.map(normalizeImportRow) : []
  };
}

function escapeCsvCell(value) {
  if (value == null) return '';
  const raw = String(value);
  if (/[",\n\r]/.test(raw)) {
    return `"${raw.replace(/"/g, '""')}"`;
  }
  return raw;
}

function toCsv(rows) {
  if (!rows.length) return '';
  const headerSet = new Set();
  for (const row of rows) {
    Object.keys(row || {}).forEach((key) => headerSet.add(key));
  }
  const headers = Array.from(headerSet);
  const lines = [headers.join(',')];
  for (const row of rows) {
    const line = headers.map((header) => escapeCsvCell(row?.[header])).join(',');
    lines.push(line);
  }
  return lines.join('\n');
}

router.use(authenticateToken, requireRole(2));

router.post('/dishes/photo', requireRole(3), async (req, res) => {
  try {
    await fs.mkdir(dishPhotosDir, { recursive: true });
    imageUpload.single('photo')(req, res, (err) => {
      if (err) {
        return res.status(400).json({ error: err.message || 'Не удалось загрузить изображение' });
      }
      if (!req.file) {
        return res.status(400).json({ error: 'Файл изображения не передан' });
      }
      const relativePath = `/uploads/dishes/${req.file.filename}`;
      const absoluteUrl = `${req.protocol}://${req.get('host')}${relativePath}`;
      return res.status(201).json({
        message: 'Фото загружено',
        photo_path: absoluteUrl,
        photo_relative_path: relativePath
      });
    });
  } catch (e) {
    console.error('Admin dish photo upload:', e);
    return res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

function normalizeExportTypeTitleKey(title) {
  return String(title || '')
    .trim()
    .replace(/^\uFEFF/, '')
    .replace(/[\u200B-\u200D\uFEFF]/g, '')
    .replace(/[\u2012\u2013\u2014\u2015\u2212]/g, '-')
    .replace(/\s+/g, ' ')
    .toLowerCase();
}

const exportTypeMetaEntries = [
  ['Экспорт заказов', { code: 'orders', sort_order: 10, requires_date_range: true, json_only: false }],
  ['Экспорт пользователей', { code: 'users', sort_order: 20, requires_date_range: true, json_only: false }],
  ['Экспорт меню', { code: 'menu', sort_order: 40, requires_date_range: false, json_only: true }],
  ['Экспорт категорий (импорт)', { code: 'categories', sort_order: 30, requires_date_range: false, json_only: false }],
  ['Экспорт категорий', { code: 'categories', sort_order: 30, requires_date_range: false, json_only: false }],
  [
    'Экспорт меню - категории и блюда (JSON)',
    { code: 'menu', sort_order: 50, requires_date_range: false, json_only: true }
  ],
  [
    'Экспорт меню - категории и блюда',
    { code: 'menu', sort_order: 50, requires_date_range: false, json_only: true }
  ],
  ['Экспорт меню — категории и блюда (JSON)', { code: 'menu', sort_order: 50, requires_date_range: false, json_only: true }],
  ['Экспорт меню — категории и блюда', { code: 'menu', sort_order: 50, requires_date_range: false, json_only: true }]
];

const exportTypeMetaByNormalizedTitle = new Map();
for (const [title, meta] of exportTypeMetaEntries) {
  exportTypeMetaByNormalizedTitle.set(normalizeExportTypeTitleKey(title), meta);
}

const categoriesExportMeta = exportTypeMetaByNormalizedTitle.get(
  normalizeExportTypeTitleKey('Экспорт категорий (импорт)')
);
const menuBundleExportMeta = exportTypeMetaByNormalizedTitle.get(
  normalizeExportTypeTitleKey('Экспорт меню - категории и блюда (JSON)')
);

function resolveExportTypeMeta(dbTitle) {
  if (dbTitle == null) return null;
  const n = normalizeExportTypeTitleKey(dbTitle);
  const direct = exportTypeMetaByNormalizedTitle.get(n);
  if (direct) return direct;
  if (
    categoriesExportMeta &&
    n.includes('экспорт') &&
    n.includes('категор') &&
    !/^экспорт меню\s*-\s*/.test(n)
  ) {
    return categoriesExportMeta;
  }
  if (
    menuBundleExportMeta &&
    /^экспорт меню\s*-\s*.+/.test(n) &&
    (n.includes('блюд') || n.includes('json') || n.includes('категор'))
  ) {
    return menuBundleExportMeta;
  }
  return null;
}

router.get('/export-types', requireRole(3), async (req, res) => {
  try {
    const r = await query(
      'SELECT id_export_type, title FROM export_types ORDER BY id_export_type ASC'
    );
    const rows = r.rows
      .map((row) => {
        const meta = resolveExportTypeMeta(row.title);
        if (!meta) {
          console.warn('[admin/export-types] Нет сопоставления для title:', row.title);
          return null;
        }
        return {
          id_export_type: row.id_export_type,
          title: row.title,
          code: meta.code,
          sort_order: meta.sort_order,
          requires_date_range: meta.requires_date_range,
          json_only: meta.json_only
        };
      })
      .filter(Boolean)
      .sort((a, b) => a.sort_order - b.sort_order || a.id_export_type - b.id_export_type);
    res.json(rows);
  } catch (e) {
    if (e && e.code === '42P01') {
      return res.status(503).json({
        error: 'Справочник типов экспорта временно недоступен.'
      });
    }
    console.error('Admin export-types:', e);
    return res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

router.get('/stats', async (req, res) => {
  const [usersR, bookingsR, activeOrdersR] = await Promise.all([
    query('SELECT COUNT(*)::int AS c FROM users'),
    query('SELECT COUNT(*)::int AS c FROM bookings'),
    query(
      `SELECT COUNT(*)::int AS c FROM orders o
       WHERE o.order_status_id NOT IN (
         SELECT id_order_status FROM order_statuses WHERE title IN ('Завершен', 'Отменен')
       )`
    )
  ]);
  res.json({
    activeOrders: activeOrdersR.rows[0].c,
    bookings: bookingsR.rows[0].c,
    users: usersR.rows[0].c
  });
});

router.get('/categories', async (req, res) => {
  try {
    const r = await query('SELECT * FROM categories ORDER BY sort_order ASC, id_category ASC');
    res.json(r.rows);
  } catch (e) {
    console.error('Admin categories list:', e);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

router.post('/categories', requireRole(3), async (req, res) => {
  try {
    const { error, value } = categoryBodySchema.validate(req.body);
    if (error) return res.status(400).json({ error: error.details[0].message });
    const r = await query(
      'INSERT INTO categories (title, sort_order) VALUES ($1, $2) RETURNING *',
      [value.title, value.sort_order]
    );
    return res.status(201).json(r.rows[0]);
  } catch (e) {
    if (e.code === '23505') return res.status(409).json({ error: 'Такая категория уже существует' });
    console.error('Admin category create:', e);
    return res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

router.put('/categories/:categoryId', requireRole(3), async (req, res) => {
  try {
    const { error, value } = categoryBodySchema.validate(req.body);
    if (error) return res.status(400).json({ error: error.details[0].message });
    const id = Number(req.params.categoryId);
    const r = await query(
      'UPDATE categories SET title = $1, sort_order = $2 WHERE id_category = $3 RETURNING *',
      [value.title, value.sort_order, id]
    );
    if (!r.rows[0]) return res.status(404).json({ error: 'Категория не найдена' });
    return res.json(r.rows[0]);
  } catch (e) {
    if (e.code === '23505') return res.status(409).json({ error: 'Такая категория уже существует' });
    console.error('Admin category update:', e);
    return res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

router.delete('/categories/:categoryId', requireRole(3), async (req, res) => {
  try {
    const id = Number(req.params.categoryId);
    const r = await query('DELETE FROM categories WHERE id_category = $1 RETURNING id_category', [id]);
    if (!r.rows[0]) return res.status(404).json({ error: 'Категория не найдена' });
    return res.status(204).send();
  } catch (e) {
    if (e.code === '23503') {
      return res.status(409).json({ error: 'Нельзя удалить категорию: есть связанные блюда' });
    }
    console.error('Admin category delete:', e);
    return res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

router.get('/dishes', async (req, res) => {
  try {
    const categoryId = req.query.category_id != null && req.query.category_id !== ''
      ? Number(req.query.category_id)
      : null;
    const params = [];
    let whereSql = '';
    if (categoryId) {
      params.push(categoryId);
      whereSql = 'WHERE category_id = $1';
    }
    const r = await query(`SELECT * FROM dishes ${whereSql} ORDER BY created_at DESC`, params);
    res.json(r.rows);
  } catch (e) {
    console.error('Admin dishes list:', e);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

router.post('/dishes', requireRole(3), async (req, res) => {
  const { error, value } = dishBodySchema.validate(req.body || {}, { abortEarly: false });
  if (error) return res.status(400).json({ error: error.details.map((d) => d.message).join(', ') });
  const created = await query(
    `INSERT INTO dishes (category_id, title, description, ingredients, price, weight, calories, allergens, photo_path, is_available)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
     RETURNING *`,
    [
      value.category_id,
      value.title,
      value.description,
      value.ingredients,
      value.price,
      value.weight,
      value.calories || null,
      value.allergens || null,
      value.photo_path || null,
      value.is_available
    ]
  );
  return res.status(201).json(created.rows[0]);
});

router.put('/dishes/:dishId', requireRole(3), async (req, res) => {
  const dishId = Number(req.params.dishId);
  if (!Number.isInteger(dishId) || dishId <= 0) return res.status(400).json({ error: 'Некорректный идентификатор блюда' });
  const { error, value } = dishBodySchema.validate(req.body || {}, { abortEarly: false });
  if (error) return res.status(400).json({ error: error.details.map((d) => d.message).join(', ') });
  const updated = await query(
    `UPDATE dishes
     SET category_id=$1, title=$2, description=$3, ingredients=$4, price=$5, weight=$6,
         calories=$7, allergens=$8, photo_path=$9, is_available=$10
     WHERE id_dish = $11
     RETURNING *`,
    [
      value.category_id,
      value.title,
      value.description,
      value.ingredients,
      value.price,
      value.weight,
      value.calories || null,
      value.allergens || null,
      value.photo_path || null,
      value.is_available,
      dishId
    ]
  );
  if (!updated.rows[0]) return res.status(404).json({ error: 'Блюдо не найдено' });
  return res.json(updated.rows[0]);
});

router.put('/dishes/:dishId/availability', requireRole(3), async (req, res) => {
  const dishId = Number(req.params.dishId);
  if (!Number.isInteger(dishId) || dishId <= 0) return res.status(400).json({ error: 'Некорректный идентификатор блюда' });
  const isAvailable = Boolean(req.body?.is_available);
  const updated = await query(
    'UPDATE dishes SET is_available = $1 WHERE id_dish = $2 RETURNING id_dish, is_available',
    [isAvailable, dishId]
  );
  if (!updated.rows[0]) return res.status(404).json({ error: 'Блюдо не найдено' });
  return res.json(updated.rows[0]);
});

router.delete('/dishes/:dishId', requireRole(3), async (req, res) => {
  try {
    const id = Number(req.params.dishId);
    const r = await query('DELETE FROM dishes WHERE id_dish = $1 RETURNING id_dish', [id]);
    if (!r.rows[0]) return res.status(404).json({ error: 'Блюдо не найдено' });
    return res.status(204).send();
  } catch (e) {
    if (e.code === '23503') {
      return res.status(409).json({ error: 'Нельзя удалить блюдо: на него ссылаются заказы или корзина' });
    }
    console.error('Admin dish delete:', e);
    return res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

router.get('/users', async (req, res) => {
  const usersResult = await query(
    `SELECT
      u.*,
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
     FROM users u
     LEFT JOIN bonus_operations bo ON bo.user_id = u.id_user
     LEFT JOIN bonus_operation_types bot ON bot.id_bonus_operation_type = bo.bonus_operation_type_id
     GROUP BY u.id_user
     ORDER BY u.registered_at DESC`
  );
  const users = usersResult.rows;
  res.json(users);
});

router.post('/users/:userId/bonus', requireRole(2), async (req, res) => {
  const userId = Number(req.params.userId);
  if (!Number.isInteger(userId) || userId <= 0) {
    return res.status(400).json({ error: 'Некорректный идентификатор пользователя' });
  }
  const { error, value } = adjustUserBonusSchema.validate(req.body || {});
  if (error) return res.status(400).json({ error: error.details[0].message });

  const userResult = await query(
    'SELECT id_user, is_blocked FROM users WHERE id_user = $1 LIMIT 1',
    [userId]
  );
  const user = userResult.rows[0];
  if (!user) return res.status(404).json({ error: 'Пользователь не найден' });
  if (user.is_blocked) return res.status(409).json({ error: 'Пользователь заблокирован' });

  const currentBalance = await getUserBonusBalanceById(userId);

  let operationType = value.operation_type;
  let amount = Number(value.bonus_amount);
  if (operationType === 'set_balance') {
    const targetBalance = amount;
    const diff = targetBalance - currentBalance;
    if (diff === 0) {
      return res.status(200).json({
        message: 'Баланс уже соответствует целевому значению',
        user_id: userId,
        operation_type: operationType,
        bonus_amount: 0,
        comment: value.comment || null,
        balance_before: currentBalance,
        balance_after: currentBalance
      });
    }
    operationType = diff > 0 ? 'accrual' : 'writeoff';
    amount = Math.abs(diff);
  }

  const isAccrual = operationType === 'accrual';
  const typeTitle = isAccrual ? 'Начисление' : 'Списание';
  const operationTypeId = await getBonusOperationTypeIdByTitle(typeTitle, isAccrual ? 1 : 2);
  if (!operationTypeId) {
    return res.status(500).json({ error: 'Не найден тип бонусной операции' });
  }

  if (!isAccrual && amount > currentBalance) {
    return res.status(400).json({ error: 'Недостаточно бонусов для списания' });
  }

  await query(
    `INSERT INTO bonus_operations (user_id, bonus_operation_type_id, bonus_amount, order_id)
     VALUES ($1, $2, $3, NULL)`,
    [userId, operationTypeId, amount]
  );

  const nextBalance = await getUserBonusBalanceById(userId);

  try {
    await query(
      `INSERT INTO notifications (user_id, title, text, is_read)
       VALUES ($1, $2, $3, FALSE)`,
      [
        userId,
        isAccrual ? 'Начислены бонусы' : 'Списаны бонусы',
        isAccrual
          ? `На ваш счет начислено ${amount} бонусов.`
          : `С вашего счета списано ${amount} бонусов.`,
      ]
    );
  } catch (_) {}

  return res.status(201).json({
    message: isAccrual ? 'Бонусы начислены' : 'Бонусы списаны',
    user_id: userId,
    operation_type: value.operation_type,
    applied_operation_type: operationType,
    bonus_amount: amount,
    comment: value.comment || null,
    balance_before: currentBalance,
    balance_after: nextBalance
  });
});
router.get('/orders', async (req, res) => {
  const useSnapshotDishTitle = await hasOrderItemsDishTitleColumn();
  const dishTitleSql = useSnapshotDishTitle
    ? "COALESCE(NULLIF(trim(oi.dish_title), ''), d.title, 'Удаленное блюдо')"
    : "COALESCE(d.title, 'Удаленное блюдо')";
  const ordersResult = await query(`
    SELECT
      o.*,
      os.title AS order_status_title,
      pt.title AS pickup_type_title,
      pm.title AS payment_method_title,
      u.full_name AS user_full_name,
      u.phone AS user_phone,
      u.email AS user_email,
      da.address_text AS delivery_address_text,
      da.comment AS delivery_address_comment
    FROM orders o
    JOIN order_statuses os ON os.id_order_status = o.order_status_id
    JOIN pickup_types pt ON pt.id_pickup_type = o.pickup_type_id
    JOIN payment_methods pm ON pm.id_payment_method = o.payment_method_id
    LEFT JOIN users u ON u.id_user = o.user_id
    LEFT JOIN delivery_addresses da ON da.id_address = o.address_id
    ORDER BY o.created_at DESC
  `);
  const orders = [];
  for (const order of ordersResult.rows) {
    const itemsResult = await query(
      `SELECT
        oi.*,
        ${dishTitleSql} AS dish_title,
        d.photo_path AS dish_photo
       FROM order_items oi
       LEFT JOIN dishes d ON d.id_dish = oi.dish_id
       WHERE oi.order_id = $1
       ORDER BY oi.id_order_item ASC`,
      [order.id_order]
    );
    orders.push({ ...order, orderItems: itemsResult.rows });
  }
  res.json(orders);
});

router.get('/orders/:orderId', async (req, res) => {
  const useSnapshotDishTitle = await hasOrderItemsDishTitleColumn();
  const dishTitleSql = useSnapshotDishTitle
    ? "COALESCE(NULLIF(trim(oi.dish_title), ''), d.title, 'Удаленное блюдо')"
    : "COALESCE(d.title, 'Удаленное блюдо')";
  const orderId = Number(req.params.orderId);
  if (!Number.isInteger(orderId) || orderId <= 0) return res.status(400).json({ error: 'Некорректный идентификатор заказа' });
  const orderResult = await query(
    `SELECT
      o.*,
      os.title AS order_status_title,
      pt.title AS pickup_type_title,
      pm.title AS payment_method_title,
      u.full_name AS user_full_name,
      u.phone AS user_phone,
      u.email AS user_email,
      da.address_text AS delivery_address_text,
      da.comment AS delivery_address_comment
     FROM orders o
     JOIN order_statuses os ON os.id_order_status = o.order_status_id
     JOIN pickup_types pt ON pt.id_pickup_type = o.pickup_type_id
     JOIN payment_methods pm ON pm.id_payment_method = o.payment_method_id
     LEFT JOIN users u ON u.id_user = o.user_id
     LEFT JOIN delivery_addresses da ON da.id_address = o.address_id
     WHERE o.id_order = $1
     LIMIT 1`,
    [orderId]
  );
  const order = orderResult.rows[0];
  if (!order) return res.status(404).json({ error: 'Заказ не найден' });
  const itemsResult = await query(
    `SELECT
      oi.*,
      ${dishTitleSql} AS dish_title,
      d.photo_path AS dish_photo
     FROM order_items oi
     LEFT JOIN dishes d ON d.id_dish = oi.dish_id
     WHERE oi.order_id = $1
     ORDER BY oi.id_order_item ASC`,
    [orderId]
  );
  res.json({ ...order, orderItems: itemsResult.rows, items: itemsResult.rows });
});

router.put('/orders/:orderId/status', async (req, res) => {
  const orderId = Number(req.params.orderId);
  if (!Number.isInteger(orderId) || orderId <= 0) return res.status(400).json({ error: 'Некорректный идентификатор заказа' });
  const { error, value } = updateOrderStatusSchema.validate(req.body || {});
  if (error) return res.status(400).json({ error: error.details[0].message });

  const currentOrderResult = await query(
    `SELECT id_order, user_id, order_status_id, total_amount, spent_bonus
     FROM orders
     WHERE id_order = $1
     LIMIT 1`,
    [orderId]
  );
  const currentOrder = currentOrderResult.rows[0];
  if (!currentOrder) return res.status(404).json({ error: 'Заказ не найден' });

  const completedStatusId = await getOrderStatusIdByTitle('Завершен', 6);
  const canceledStatusId = await getOrderStatusIdByTitle('Отменено', null)
    || await getOrderStatusIdByTitle('Отменен', 7);
  if (Number(currentOrder.order_status_id) === Number(canceledStatusId)) {
    return res.status(409).json({ error: 'Нельзя изменить статус отмененного заказа' });
  }
  const writeOffTypeId = await getBonusOperationTypeIdByTitle('Списание', 2);
  const accrualTypeId = await getBonusOperationTypeIdByTitle('Начисление', 1);

  const client = await pool.connect();
  let updatedOrder;
  try {
    await client.query('BEGIN');
    const updated = await client.query(
      `UPDATE orders
       SET order_status_id = $1
       WHERE id_order = $2
       RETURNING id_order, user_id, order_status_id`,
      [value.order_status_id, orderId]
    );
    if (!updated.rows[0]) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Заказ не найден' });
    }
    updatedOrder = updated.rows[0];

    const movedToCompleted =
      Number(value.order_status_id) === Number(completedStatusId) &&
      Number(currentOrder.order_status_id) !== Number(completedStatusId);
    if (movedToCompleted && accrualTypeId) {
      const accrualAmount = Math.floor(Number(currentOrder.total_amount || 0) * BONUS_ACCRUAL_PERCENT);
      if (accrualAmount > 0) {
        const alreadyAccrued = await hasAccrualByOrderId(orderId, accrualAmount);
        if (!alreadyAccrued) {
          await client.query(
            `INSERT INTO bonus_operations (user_id, bonus_operation_type_id, bonus_amount, order_id)
             VALUES ($1, $2, $3, $4)`,
            [currentOrder.user_id, accrualTypeId, accrualAmount, orderId]
          );
        }
      }
    }

    const movedToCanceled =
      Number(value.order_status_id) === Number(canceledStatusId) &&
      Number(currentOrder.order_status_id) !== Number(canceledStatusId);
    const spentBonus = Number(currentOrder.spent_bonus || 0);
    if (movedToCanceled && spentBonus > 0 && accrualTypeId && writeOffTypeId) {
      const spentOps = await client.query(
        `SELECT
          COALESCE(SUM(CASE WHEN bonus_operation_type_id = $1 THEN bonus_amount ELSE 0 END), 0)::int AS total_write_off,
          COALESCE(SUM(CASE WHEN bonus_operation_type_id = $2 THEN bonus_amount ELSE 0 END), 0)::int AS total_accrual
         FROM bonus_operations
         WHERE order_id = $3`,
        [writeOffTypeId, accrualTypeId, orderId]
      );
      const totalWriteOff = Number(spentOps.rows[0]?.total_write_off || 0);
      const totalAccrual = Number(spentOps.rows[0]?.total_accrual || 0);
      const refundAmount = Math.max(0, Math.min(spentBonus, totalWriteOff - totalAccrual));
      if (refundAmount > 0) {
        await client.query(
          `INSERT INTO bonus_operations (user_id, bonus_operation_type_id, bonus_amount, order_id)
           VALUES ($1, $2, $3, $4)`,
          [currentOrder.user_id, accrualTypeId, refundAmount, orderId]
        );
      }
    }

    await client.query('COMMIT');
  } catch (e) {
    await client.query('ROLLBACK');
    console.error('Admin order status update with bonus error:', e);
    return res.status(500).json({ error: 'Не удалось обновить статус заказа' });
  } finally {
    client.release();
  }
  let statusTitle = 'статус обновлён';
  try {
    const statusResult = await query(
      'SELECT title FROM order_statuses WHERE id_order_status = $1 LIMIT 1',
      [updatedOrder.order_status_id]
    );
    if (statusResult.rows[0]?.title) {
      statusTitle = statusResult.rows[0].title;
    }
  } catch (_) {}

  try {
    await query(
      `INSERT INTO notifications (user_id, title, text, is_read)
       VALUES ($1, $2, $3, FALSE)`,
      [
        updatedOrder.user_id,
        'Статус заказа изменён',
        `Заказ №${updatedOrder.id_order}: ${statusTitle}`,
      ]
    );
    await sendPushToUser(
      pool,
      updatedOrder.user_id,
      'Статус заказа изменён',
      `Заказ №${updatedOrder.id_order}: ${statusTitle}`,
      {
        type: 'order_status_changed',
        order_id: updatedOrder.id_order
      }
    );
  } catch (e) {
    console.error('Admin order status push error:', e.message || e);
  }

  res.json({ message: 'Статус заказа обновлен' });
});

router.get('/bookings', async (req, res) => {
  const bookings = await query(
    `SELECT
      b.*,
      bs.title AS booking_status_title,
      u.full_name AS user_full_name,
      u.phone AS user_phone,
      u.email AS user_email
     FROM bookings b
     LEFT JOIN booking_statuses bs ON bs.id_booking_status = b.booking_status_id
     LEFT JOIN users u ON u.id_user = b.user_id
     ORDER BY b.created_at DESC`
  );
  res.json(bookings.rows);
});

router.put('/bookings/:bookingId/status', async (req, res) => {
  const bookingId = Number(req.params.bookingId);
  if (!Number.isInteger(bookingId) || bookingId <= 0) return res.status(400).json({ error: 'Некорректный идентификатор бронирования' });
  const { error, value } = updateBookingStatusSchema.validate(req.body || {});
  if (error) return res.status(400).json({ error: error.details[0].message });

  const canceledStatusId = await getBookingStatusIdByTitle('Отменено', null)
    || await getBookingStatusIdByTitle('Отменен', 3);
  const currentBookingResult = await query(
    `SELECT id_booking, booking_status_id
     FROM bookings
     WHERE id_booking = $1
     LIMIT 1`,
    [bookingId]
  );
  const currentBooking = currentBookingResult.rows[0];
  if (!currentBooking) return res.status(404).json({ error: 'Бронирование не найдено' });
  if (Number(currentBooking.booking_status_id) === Number(canceledStatusId)) {
    return res.status(409).json({ error: 'Нельзя изменить статус отмененного бронирования' });
  }

  const updated = await query(
    `UPDATE bookings
     SET booking_status_id = $1
     WHERE id_booking = $2
     RETURNING id_booking, user_id, booking_status_id`,
    [value.booking_status_id, bookingId]
  );
  if (!updated.rows[0]) return res.status(404).json({ error: 'Бронирование не найдено' });

  const updatedBooking = updated.rows[0];
  let statusTitle = 'статус обновлен';
  try {
    const statusResult = await query(
      'SELECT title FROM booking_statuses WHERE id_booking_status = $1 LIMIT 1',
      [updatedBooking.booking_status_id]
    );
    if (statusResult.rows[0]?.title) {
      statusTitle = statusResult.rows[0].title;
    }
  } catch (_) {}

  try {
    await query(
      `INSERT INTO notifications (user_id, title, text, is_read)
       VALUES ($1, $2, $3, FALSE)`,
      [
        updatedBooking.user_id,
        'Статус брони изменен',
        `Бронь №${updatedBooking.id_booking}: ${statusTitle}`,
      ]
    );
    await sendPushToUser(
      pool,
      updatedBooking.user_id,
      'Статус брони изменен',
      `Бронь №${updatedBooking.id_booking}: ${statusTitle}`,
      {
        type: 'booking_status_changed',
        booking_id: updatedBooking.id_booking
      }
    );
  } catch (e) {
    console.error('Admin booking status push error:', e.message || e);
  }

  res.json({ message: 'Статус бронирования обновлен' });
});

router.put('/users/:userId/role', requireRole(3), async (req, res) => {
  const userId = Number(req.params.userId);
  if (!Number.isInteger(userId) || userId <= 0) return res.status(400).json({ error: 'Некорректный идентификатор пользователя' });
  const { error, value } = updateRoleSchema.validate(req.body || {});
  if (error) return res.status(400).json({ error: error.details[0].message });
  const updated = await query(
    'UPDATE users SET role_id = $1 WHERE id_user = $2 RETURNING id_user, role_id',
    [value.role_id, userId]
  );
  if (!updated.rows[0]) return res.status(404).json({ error: 'Пользователь не найден' });
  res.json(updated.rows[0]);
});

router.put('/users/:userId/block', requireRole(3), async (req, res) => {
  const userId = Number(req.params.userId);
  if (!Number.isInteger(userId) || userId <= 0) return res.status(400).json({ error: 'Некорректный идентификатор пользователя' });
  const blockValue = req.body?.is_blocked;
  const nextValue = typeof blockValue === 'boolean' ? blockValue : true;
  const updated = await query(
    'UPDATE users SET is_blocked = $1 WHERE id_user = $2 RETURNING id_user, is_blocked',
    [nextValue, userId]
  );
  if (!updated.rows[0]) return res.status(404).json({ error: 'Пользователь не найден' });
  res.json(updated.rows[0]);
});

router.get('/users/:userId/orders', async (req, res) => {
  const useSnapshotDishTitle = await hasOrderItemsDishTitleColumn();
  const dishTitleSql = useSnapshotDishTitle
    ? "COALESCE(NULLIF(trim(oi.dish_title), ''), d.title, 'Удаленное блюдо')"
    : "COALESCE(d.title, 'Удаленное блюдо')";
  const userId = Number(req.params.userId);
  if (!Number.isInteger(userId) || userId <= 0) return res.status(400).json({ error: 'Некорректный идентификатор пользователя' });
  const ordersResult = await query(
    `SELECT
      o.*,
      os.title AS order_status_title,
      pt.title AS pickup_type_title,
      pm.title AS payment_method_title
     FROM orders o
     LEFT JOIN order_statuses os ON os.id_order_status = o.order_status_id
     LEFT JOIN pickup_types pt ON pt.id_pickup_type = o.pickup_type_id
     LEFT JOIN payment_methods pm ON pm.id_payment_method = o.payment_method_id
     WHERE o.user_id = $1
     ORDER BY o.created_at DESC`,
    [userId]
  );
  const orders = [];
  for (const order of ordersResult.rows) {
    const itemsResult = await query(
      `SELECT oi.*, ${dishTitleSql} AS dish_title, d.photo_path AS dish_photo
       FROM order_items oi
       LEFT JOIN dishes d ON d.id_dish = oi.dish_id
       WHERE oi.order_id = $1
       ORDER BY oi.id_order_item ASC`,
      [order.id_order]
    );
    orders.push({ ...order, orderItems: itemsResult.rows, items: itemsResult.rows });
  }
  res.json(orders);
});

router.get('/users/:userId/bonus-history', requireRole(2), async (req, res) => {
  const userId = Number(req.params.userId);
  if (!Number.isInteger(userId) || userId <= 0) {
    return res.status(400).json({ error: 'Некорректный идентификатор пользователя' });
  }
  const userResult = await query(
    'SELECT id_user FROM users WHERE id_user = $1 LIMIT 1',
    [userId]
  );
  if (!userResult.rows[0]) return res.status(404).json({ error: 'Пользователь не найден' });

  const operationsResult = await query(
    `SELECT
      bo.*,
      bot.title AS operation_title
     FROM bonus_operations bo
     LEFT JOIN bonus_operation_types bot ON bot.id_bonus_operation_type = bo.bonus_operation_type_id
     WHERE bo.user_id = $1
     ORDER BY bo.created_at DESC, bo.id_bonus_operation DESC`,
    [userId]
  );
  res.json(operationsResult.rows);
});

router.delete('/users/:userId', requireRole(3), async (req, res) => {
  const userId = Number(req.params.userId);
  if (!Number.isInteger(userId) || userId <= 0) return res.status(400).json({ error: 'Некорректный идентификатор пользователя' });
  if (userId === req.user.id) return res.status(409).json({ error: 'Нельзя удалить собственного пользователя' });
  try {
    const deleted = await query('DELETE FROM users WHERE id_user = $1 RETURNING id_user', [userId]);
    if (!deleted.rows[0]) return res.status(404).json({ error: 'Пользователь не найден' });
    return res.status(204).send();
  } catch (e) {
    if (e.code === '23503') {
      const r = await query(
        `UPDATE users
         SET is_blocked = TRUE,
             full_name = CONCAT('[DELETED] ', full_name),
             email = NULL
         WHERE id_user = $1
         RETURNING id_user`,
        [userId]
      );
      if (!r.rows[0]) return res.status(404).json({ error: 'Пользователь не найден' });
      return res.json({ message: 'У пользователя есть связанная история. Аккаунт заблокирован и анонимизирован.' });
    }
    console.error('Admin delete user:', e);
    return res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

router.get('/reviews', async (req, res) => {
  const dishId = req.query.dish_id != null && req.query.dish_id !== '' ? Number(req.query.dish_id) : null;
  const userId = req.query.user_id != null && req.query.user_id !== '' ? Number(req.query.user_id) : null;
  const params = [];
  const clauses = [];
  if (dishId) {
    params.push(dishId);
    clauses.push(`r.dish_id = $${params.length}`);
  }
  if (userId) {
    params.push(userId);
    clauses.push(`r.user_id = $${params.length}`);
  }
  const whereSql = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
  const reviewsResult = await query(
    `SELECT
      r.*,
      u.full_name AS user_name,
      d.title AS dish_title
     FROM reviews r
     LEFT JOIN users u ON u.id_user = r.user_id
     LEFT JOIN dishes d ON d.id_dish = r.dish_id
     ${whereSql}
     ORDER BY r.published_at DESC`,
    params
  );
  res.json(reviewsResult.rows);
});

router.post('/imports', requireRole(3), async (req, res) => {
  const { error, value } = importSchema.validate(req.body || {}, { abortEarly: false });
  if (error) return res.status(400).json({ error: error.details.map((d) => d.message).join(', ') });

  const insertedCategories = [];
  const insertedDishes = [];
  const skipped = [];

  const pushSkip = (kind, row, reason) => {
    skipped.push({ kind, reason, row });
  };

  const importCategoryRow = async (raw) => {
    const item = normalizeImportRow(raw);
    const title = item.title != null ? String(item.title).trim() : '';
    if (!title) {
      pushSkip('category', raw, 'Нет поля title');
      return;
    }
    const sortOrderRaw = item.sort_order;
    const sortOrder =
      sortOrderRaw === null || sortOrderRaw === undefined || sortOrderRaw === ''
        ? 1
        : parseInt(String(sortOrderRaw), 10);
    if (!Number.isFinite(sortOrder)) {
      pushSkip('category', raw, 'Некорректный sort_order');
      return;
    }
    const dup = await query('SELECT 1 FROM categories WHERE title = $1 LIMIT 1', [title]);
    if (dup.rows[0]) {
      pushSkip('category', raw, 'Категория с таким title уже есть');
      return;
    }
    const r = await query(
      'INSERT INTO categories (title, sort_order) VALUES ($1, $2) RETURNING *',
      [title, sortOrder]
    );
    if (r.rows[0]) insertedCategories.push(r.rows[0]);
  };

  const importDishRow = async (raw) => {
    const item = normalizeImportRow(raw);
    const title = item.title != null ? String(item.title).trim() : '';
    const categoryId = parsePositiveInt(item.category_id);
    const price = parseFlexibleNumber(item.price);
    const weight = parsePositiveInt(item.weight);
    if (!title || !categoryId || price == null || weight == null) {
      pushSkip('dish', raw, 'Нужны title, category_id, price, weight');
      return;
    }
    const cat = await query('SELECT 1 FROM categories WHERE id_category = $1 LIMIT 1', [categoryId]);
    if (!cat.rows[0]) {
      pushSkip('dish', raw, `Категория id=${categoryId} не найдена`);
      return;
    }
    const description = item.description != null ? String(item.description) : '';
    const ingredients = item.ingredients != null ? String(item.ingredients) : '';
    let calories = null;
    if (item.calories != null && item.calories !== '') {
      const c = parseInt(String(item.calories), 10);
      calories = Number.isFinite(c) && c > 0 ? c : null;
    }
    const allergens = item.allergens != null && String(item.allergens).trim() !== '' ? String(item.allergens) : null;
    const photoPath =
      item.photo_path != null && String(item.photo_path).trim() !== '' ? String(item.photo_path) : null;
    const isAvailable = item.is_available !== false && item.is_available !== 0 && item.is_available !== '0';

    try {
      const r = await query(
        `INSERT INTO dishes (category_id, title, description, ingredients, price, weight, calories, allergens, photo_path, is_available)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
         RETURNING *`,
        [categoryId, title, description, ingredients, price, weight, calories, allergens, photoPath, isAvailable]
      );
      if (r.rows[0]) insertedDishes.push(r.rows[0]);
    } catch (e) {
      if (e && e.code === '23503') {
        pushSkip('dish', raw, 'Нарушение внешнего ключа (категория или связанные данные)');
        return;
      }
      throw e;
    }
  };

  try {
    if (!['categories', 'dishes', 'menu'].includes(value.import_type)) {
      return res.status(400).json({ error: 'Неподдерживаемый тип импорта' });
    }

    const { categories: catRows, dishes: dishRows } = extractImportPayload(value.import_type, value.payload);

    if (value.import_type === 'categories') {
      if (!catRows.length) {
        return res.status(400).json({ error: 'Для импорта категорий передайте непустой массив категорий' });
      }
      for (const row of catRows) {
        await importCategoryRow(row);
      }
    } else if (value.import_type === 'dishes') {
      if (!dishRows.length) {
        return res.status(400).json({ error: 'Для импорта блюд передайте непустой массив блюд' });
      }
      for (const row of dishRows) {
        await importDishRow(row);
      }
    } else if (value.import_type === 'menu') {
      if (!catRows.length && !dishRows.length) {
        return res.status(400).json({
          error: 'Для импорта меню передайте массив блюд или объект с категориями и блюдами'
        });
      }
      for (const row of catRows) {
        await importCategoryRow(row);
      }
      for (const row of dishRows) {
        await importDishRow(row);
      }
    }

    return res.status(201).json({
      message: 'Импорт успешно завершен',
      import_type: value.import_type,
      inserted_categories_count: insertedCategories.length,
      inserted_dishes_count: insertedDishes.length,
      skipped_count: skipped.length,
      inserted_categories: insertedCategories,
      inserted_dishes: insertedDishes,
      skipped
    });
  } catch (e) {
    console.error('Admin import:', e);
    return res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

router.post('/exports', requireRole(3), async (req, res) => {
  const { error, value } = exportSchema.validate(req.body || {}, { abortEarly: false });
  if (error) return res.status(400).json({ error: error.details.map((d) => d.message).join(', ') });
  if (new Date(value.date_from) > new Date(value.date_to)) {
    return res.status(400).json({ error: 'Дата начала должна быть меньше или равна дате окончания' });
  }

  let rows = [];
  let menuBundle = null;

  if (value.export_type === 'orders') {
    const params = [value.date_from, value.date_to];
    let where = 'WHERE o.created_at::date BETWEEN $1::date AND $2::date';
    if (value.order_status_id) {
      params.push(value.order_status_id);
      where += ` AND o.order_status_id = $${params.length}`;
    }
    const r = await query(`SELECT * FROM orders o ${where} ORDER BY o.created_at DESC`, params);
    rows = r.rows;
  } else if (value.export_type === 'users') {
    const r = await query(
      `SELECT * FROM users WHERE registered_at::date BETWEEN $1::date AND $2::date ORDER BY registered_at DESC`,
      [value.date_from, value.date_to]
    );
    rows = r.rows;
  } else if (value.export_type === 'categories') {
    const r = await query('SELECT * FROM categories ORDER BY sort_order ASC, id_category ASC');
    rows = r.rows;
  } else if (value.export_type === 'dishes') {
    const params = [];
    let where = '';
    if (value.category_id) {
      params.push(value.category_id);
      where = 'WHERE category_id = $1';
    }
    const r = await query(`SELECT * FROM dishes ${where} ORDER BY created_at DESC`, params);
    rows = r.rows;
  } else if (value.export_type === 'menu') {
    const catR = await query('SELECT * FROM categories ORDER BY sort_order ASC, id_category ASC');
    const params = [];
    let where = '';
    if (value.category_id) {
      params.push(value.category_id);
      where = 'WHERE category_id = $1';
    }
    const dishR = await query(`SELECT * FROM dishes ${where} ORDER BY created_at DESC`, params);
    if (value.format !== 'json') {
      return res.status(400).json({
        error: 'Полный экспорт меню (категории + блюда) доступен только в JSON — выберите формат JSON или тип «Экспорт блюд» для CSV'
      });
    }
    menuBundle = { categories: catR.rows, dishes: dishR.rows };
    rows = [];
  } else {
    return res.status(400).json({ error: 'Неподдерживаемый тип экспорта' });
  }

  const exportsDir = path.join(__dirname, '..', '..', 'exports');
  await fs.mkdir(exportsDir, { recursive: true });

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const fileName = `${value.export_type}_${timestamp}.${value.format}`;
  const filePath = path.join(exportsDir, fileName);

  if (menuBundle != null) {
    await fs.writeFile(filePath, JSON.stringify(menuBundle, null, 2), 'utf8');
  } else if (value.format === 'json') {
    await fs.writeFile(filePath, JSON.stringify(rows, null, 2), 'utf8');
  } else {
    await fs.writeFile(filePath, toCsv(rows), 'utf8');
  }

  const total =
    menuBundle != null
      ? menuBundle.categories.length + menuBundle.dishes.length
      : rows.length;

  res.status(201).json({
    message: 'Экспорт успешно завершен',
    format: value.format,
    export_type: value.export_type,
    total,
    file_name: fileName,
    file_path: filePath,
    file_url: `/exports/${fileName}`,
  });
});

module.exports = router;
