const Joi = require('joi');
const { query, pool } = require('../db');
const { Router } = require('express');
const { authenticateToken } = require('../middleware/auth');
const { createNotificationWithPush } = require('../services/userNotify');
const { notifyStaffAboutNewOrder } = require('../services/staffNotify');
const { sendPushToUser } = require('../utils/sendPush');
const { sendOrderCreatedMail } = require('../utils/mail');

const router = Router();
const BONUS_SPEND_LIMIT_PERCENT = 0.3;

const createOrderSchema = Joi.object({
  pickup_type_id: Joi.number().integer().positive().required(),
  payment_method_id: Joi.number().integer().positive().required(),
  address_id: Joi.number().integer().positive().allow(null).optional(),
  receive_time: Joi.date().iso().required(),
  comment: Joi.string().max(300).allow('', null).optional(),
  spent_bonus: Joi.number().integer().min(0).default(0)
});

async function getOrderStatusIdByTitle(title, fallbackId) {
  try {
    const r = await query('SELECT id_order_status FROM order_statuses WHERE LOWER(title) = LOWER($1) LIMIT 1', [title]);
    return r.rows[0]?.id_order_status || fallbackId;
  } catch {
    return fallbackId;
  }
}

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

async function getUserBonusBalance(userId) {
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

function calculateMaxSpendBonus(subtotal) {
  return Math.floor(Number(subtotal || 0) * BONUS_SPEND_LIMIT_PERCENT);
}

async function fetchOrderItems(orderId) {
  const useSnapshotDishTitle = await hasOrderItemsDishTitleColumn();
  const dishTitleSql = useSnapshotDishTitle
    ? "COALESCE(NULLIF(trim(oi.dish_title), ''), d.title, 'Удаленное блюдо')"
    : "COALESCE(d.title, 'Удаленное блюдо')";
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
  return itemsResult.rows;
}

async function getOrderWithItems(orderId, userId = null) {
  const params = [orderId];
  const whereOwner = userId ? 'AND o.user_id = $2' : '';
  if (userId) params.push(userId);
  const orderResult = await query(
    `SELECT o.*, os.title AS order_status_title, pt.title AS pickup_type_title, pm.title AS payment_method_title
     FROM orders o
     LEFT JOIN order_statuses os ON os.id_order_status = o.order_status_id
     LEFT JOIN pickup_types pt ON pt.id_pickup_type = o.pickup_type_id
     LEFT JOIN payment_methods pm ON pm.id_payment_method = o.payment_method_id
     WHERE o.id_order = $1 ${whereOwner}
     LIMIT 1`,
    params
  );
  const order = orderResult.rows[0];
  if (!order) return null;

  const itemsRows = await fetchOrderItems(orderId);
  return { ...order, orderItems: itemsRows, items: itemsRows };
}

router.get('/', authenticateToken, async (req, res) => {
  const ordersResult = await query(
    `SELECT o.*, os.title AS order_status_title, pt.title AS pickup_type_title, pm.title AS payment_method_title
     FROM orders o
     LEFT JOIN order_statuses os ON os.id_order_status = o.order_status_id
     LEFT JOIN pickup_types pt ON pt.id_pickup_type = o.pickup_type_id
     LEFT JOIN payment_methods pm ON pm.id_payment_method = o.payment_method_id
     WHERE o.user_id = $1
     ORDER BY o.created_at DESC`,
    [req.user.id]
  );
  const orders = [];
  for (const order of ordersResult.rows) {
    const itemsRows = await fetchOrderItems(order.id_order);
    orders.push({ ...order, orderItems: itemsRows, items: itemsRows });
  }
  res.json(orders);
});

router.get('/:orderId', authenticateToken, async (req, res) => {
  const orderId = Number(req.params.orderId);
  if (!Number.isInteger(orderId) || orderId <= 0) return res.status(400).json({ error: 'Некорректный идентификатор заказа' });
  const order = await getOrderWithItems(orderId, req.user.id);
  if (!order) return res.status(404).json({ error: 'Заказ не найден' });
  return res.json(order);
});

router.post('/', authenticateToken, async (req, res) => {
  const { error, value } = createOrderSchema.validate(req.body || {}, { abortEarly: false });
  if (error) return res.status(400).json({ error: error.details.map((d) => d.message).join(', ') });

  const userCartResult = await query('SELECT id_cart FROM carts WHERE user_id = $1 LIMIT 1', [req.user.id]);
  const cart = userCartResult.rows[0];
  if (!cart) return res.status(400).json({ error: 'Корзина пуста' });

  const cartItemsResult = await query(
    `SELECT ci.*, d.price, d.is_available, d.title AS dish_title
     FROM cart_items ci
     JOIN dishes d ON d.id_dish = ci.dish_id
     WHERE ci.cart_id = $1`,
    [cart.id_cart]
  );
  const cartItems = cartItemsResult.rows;
  if (!cartItems.length) return res.status(400).json({ error: 'Корзина пуста' });

  const unavailable = cartItems.filter((i) => !i.is_available);
  if (unavailable.length) {
    return res.status(409).json({ error: 'Некоторые блюда недоступны', unavailable_dish_ids: unavailable.map((i) => i.dish_id) });
  }

  const isDelivery = Number(value.pickup_type_id) === 1;
  if (isDelivery) {
    if (!value.address_id) return res.status(400).json({ error: 'Адрес обязателен для доставки' });
    const addr = await query(
      'SELECT id_address FROM delivery_addresses WHERE id_address = $1 AND user_id = $2 LIMIT 1',
      [value.address_id, req.user.id]
    );
    if (!addr.rows[0]) return res.status(404).json({ error: 'Адрес не найден' });
  }

  const subtotal = cartItems.reduce((sum, i) => sum + Number(i.price) * Number(i.quantity), 0);
  const requestedBonus = Number(value.spent_bonus || 0);
  if (requestedBonus < 0) return res.status(400).json({ error: 'Списание бонусов не может быть отрицательным' });

  let userBonusBalance = 0;
  try {
    userBonusBalance = await getUserBonusBalance(req.user.id);
  } catch {
    userBonusBalance = 0;
  }
  if (requestedBonus > userBonusBalance) {
    return res.status(400).json({ error: 'Недостаточно бонусов' });
  }
  const maxAllowedByPercent = calculateMaxSpendBonus(subtotal);
  if (requestedBonus > maxAllowedByPercent) {
    return res.status(400).json({
      error: `Можно списать не более ${Math.floor(BONUS_SPEND_LIMIT_PERCENT * 100)}% от суммы заказа`,
      max_spent_bonus: maxAllowedByPercent
    });
  }

  const spentBonus = Math.min(requestedBonus, Math.floor(subtotal), maxAllowedByPercent);
  const totalAmount = Math.max(0, subtotal - spentBonus);
  const pendingStatusId = await getOrderStatusIdByTitle('Новый', 1);

  const client = await pool.connect();
  let committed = false;
  let orderId = null;
  try {
    await client.query('BEGIN');
    const orderResult = await client.query(
      `INSERT INTO orders (user_id, address_id, order_status_id, pickup_type_id, payment_method_id, receive_time, comment, total_amount, spent_bonus)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING id_order`,
      [
        req.user.id,
        value.address_id || null,
        pendingStatusId,
        value.pickup_type_id,
        value.payment_method_id,
        new Date(value.receive_time).toISOString(),
        value.comment ? String(value.comment) : null,
        totalAmount,
        spentBonus
      ]
    );
    orderId = orderResult.rows[0].id_order;

    const useSnapshotDishTitle = await hasOrderItemsDishTitleColumn();
    for (const item of cartItems) {
      const itemTotal = Number(item.price) * Number(item.quantity);
      if (useSnapshotDishTitle) {
        await client.query(
          `INSERT INTO order_items (order_id, dish_id, quantity, price_at_order_time, item_total, selected_options, dish_title)
           VALUES ($1, $2, $3, $4, $5, $6, $7)`,
          [
            orderId,
            item.dish_id,
            item.quantity,
            item.price,
            itemTotal,
            item.selected_options || null,
            item.dish_title || null
          ]
        );
      } else {
        await client.query(
          `INSERT INTO order_items (order_id, dish_id, quantity, price_at_order_time, item_total, selected_options)
           VALUES ($1, $2, $3, $4, $5, $6)`,
          [
            orderId,
            item.dish_id,
            item.quantity,
            item.price,
            itemTotal,
            item.selected_options || null
          ]
        );
      }
    }

    await client.query('DELETE FROM cart_items WHERE cart_id = $1', [cart.id_cart]);
    await client.query('UPDATE carts SET updated_at = CURRENT_TIMESTAMP WHERE id_cart = $1', [cart.id_cart]);

    if (spentBonus > 0) {
      try {
        const writeOffTypeId = await getBonusOperationTypeIdByTitle('Списание', 2);
        await client.query(
          `INSERT INTO bonus_operations (user_id, bonus_operation_type_id, bonus_amount, order_id)
           VALUES ($1, $2, $3, $4)`,
          [req.user.id, writeOffTypeId, spentBonus, orderId]
        );
      } catch (_) {}
    }

    await client.query('COMMIT');
    committed = true;
  } catch (e) {
    if (!committed) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {}
    }
    console.error('Create order error:', e);
    return res.status(500).json({ error: 'Не удалось оформить заказ' });
  } finally {
    client.release();
  }

  let order = null;
  try {
    order = await getOrderWithItems(orderId, req.user.id);
  } catch (orderReadErr) {
    console.error('Get created order error:', orderReadErr);
  }

  try {
    await query(
      `INSERT INTO notifications (user_id, title, text, is_read)
       VALUES ($1, $2, $3, FALSE)`,
      [req.user.id, 'Заказ оформлен', `Ваш заказ №${orderId} успешно оформлен`]
    );
    await sendPushToUser(
      pool,
      req.user.id,
      'Заказ оформлен',
      `Ваш заказ №${orderId} успешно оформлен`,
      {
        type: 'order_created',
        order_id: orderId
      }
    );
  } catch (_) {}

  let customerName = null;
  try {
    const userResult = await query(
      `SELECT full_name, email
       FROM users
       WHERE id_user = $1
       LIMIT 1`,
      [req.user.id]
    );
    const user = userResult.rows[0];
    customerName = user?.full_name;
    if (user?.email) {
      await sendOrderCreatedMail({
        to: String(user.email).trim(),
        fullName: user.full_name,
        orderId,
        totalAmount
      });
    }
  } catch (mailErr) {
    console.error('Order created mail error:', mailErr);
  }

  try {
    await notifyStaffAboutNewOrder({
      orderId,
      customerName,
      totalAmount,
    });
  } catch (notifyErr) {
    console.error('Order created staff notify error:', notifyErr);
  }

  if (order) {
    return res.status(201).json(order);
  }

  return res.status(201).json({
    id_order: orderId,
    order_status_id: pendingStatusId,
    pickup_type_id: value.pickup_type_id,
    payment_method_id: value.payment_method_id,
    address_id: value.address_id || null,
    receive_time: new Date(value.receive_time).toISOString(),
    comment: value.comment ? String(value.comment) : null,
    total_amount: totalAmount,
    spent_bonus: spentBonus,
    items: []
  });
});

router.put('/:orderId/cancel', authenticateToken, async (req, res) => {
  const orderId = Number(req.params.orderId);
  if (!Number.isInteger(orderId) || orderId <= 0) return res.status(400).json({ error: 'Некорректный идентификатор заказа' });

  const current = await getOrderWithItems(orderId, req.user.id);
  if (!current) return res.status(404).json({ error: 'Заказ не найден' });
  const title = String(current.order_status_title || '').toLowerCase();
  if (title !== 'новый') {
    return res.status(409).json({ error: 'Заказ уже нельзя отменить' });
  }

  const canceledStatusId = await getOrderStatusIdByTitle('Отменен', 5);
  const spentBonus = Number(current.spent_bonus || 0);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query(
      'UPDATE orders SET order_status_id = $1 WHERE id_order = $2 AND user_id = $3',
      [canceledStatusId, orderId, req.user.id]
    );

    if (spentBonus > 0) {
      const accrualTypeId = await getBonusOperationTypeIdByTitle('Начисление', 1);
      const existingRefund = await client.query(
        `SELECT 1
         FROM bonus_operations
         WHERE user_id = $1
           AND order_id = $2
           AND bonus_operation_type_id = $3
         LIMIT 1`,
        [req.user.id, orderId, accrualTypeId]
      );

      if (!existingRefund.rows.length) {
        await client.query(
          `INSERT INTO bonus_operations (user_id, bonus_operation_type_id, bonus_amount, order_id)
           VALUES ($1, $2, $3, $4)`,
          [req.user.id, accrualTypeId, spentBonus, orderId]
        );
      }
    }

    await client.query('COMMIT');
  } catch (e) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {}
    console.error('Cancel order error:', e);
    return res.status(500).json({ error: 'Не удалось отменить заказ' });
  } finally {
    client.release();
  }

  try {
    await createNotificationWithPush(req.user.id, 'Заказ отменен', `Ваш заказ #${orderId} отменен.`);
  } catch (_) {}
  return res.json({ message: 'Заказ отменен' });
});

router.post('/:orderId/repeat', authenticateToken, async (req, res) => {
  const orderId = Number(req.params.orderId);
  if (!Number.isInteger(orderId) || orderId <= 0) return res.status(400).json({ error: 'Некорректный идентификатор заказа' });

  const order = await getOrderWithItems(orderId, req.user.id);
  if (!order) return res.status(404).json({ error: 'Заказ не найден' });

  const cartResult = await query('SELECT id_cart FROM carts WHERE user_id = $1 LIMIT 1', [req.user.id]);
  let cartId = cartResult.rows[0]?.id_cart;
  if (!cartId) {
    const ins = await query('INSERT INTO carts (user_id) VALUES ($1) RETURNING id_cart', [req.user.id]);
    cartId = ins.rows[0].id_cart;
  }

  const unavailableDishIds = [];
  for (const item of order.orderItems || []) {
    const dish = await query('SELECT id_dish, is_available FROM dishes WHERE id_dish = $1 LIMIT 1', [item.dish_id]);
    if (!dish.rows[0] || !dish.rows[0].is_available) {
      unavailableDishIds.push(item.dish_id);
      continue;
    }

    const existing = await query(
      `SELECT id_cart_item, quantity
       FROM cart_items
       WHERE cart_id = $1 AND dish_id = $2 AND COALESCE(selected_options, '') = COALESCE($3, '')
       LIMIT 1`,
      [cartId, item.dish_id, item.selected_options || null]
    );
    if (existing.rows[0]) {
      await query('UPDATE cart_items SET quantity = quantity + $1 WHERE id_cart_item = $2', [item.quantity, existing.rows[0].id_cart_item]);
    } else {
      await query(
        `INSERT INTO cart_items (cart_id, dish_id, quantity, comment, selected_options)
         VALUES ($1, $2, $3, NULL, $4)`,
        [cartId, item.dish_id, item.quantity, item.selected_options || null]
      );
    }
  }
  await query('UPDATE carts SET updated_at = CURRENT_TIMESTAMP WHERE id_cart = $1', [cartId]);
  return res.json({ message: 'Заказ повторен', unavailable_dish_ids: unavailableDishIds });
});

router.put('/:orderId', authenticateToken, async (req, res) => {
  const orderId = Number(req.params.orderId);
  if (!Number.isInteger(orderId) || orderId <= 0) return res.status(400).json({ error: 'Некорректный идентификатор заказа' });

  const updateSchema = Joi.object({
    pickup_type_id: Joi.number().integer().positive().optional(),
    payment_method_id: Joi.number().integer().positive().optional(),
    address_id: Joi.number().integer().positive().allow(null).optional(),
    receive_time: Joi.date().iso().optional(),
    comment: Joi.string().max(300).allow('', null).optional(),
    spent_bonus: Joi.number().integer().min(0).optional()
  }).min(1);

  const { error, value } = updateSchema.validate(req.body || {}, { abortEarly: false });
  if (error) return res.status(400).json({ error: error.details.map((d) => d.message).join(', ') });

  const current = await getOrderWithItems(orderId, req.user.id);
  if (!current) return res.status(404).json({ error: 'Заказ не найден' });

  const statusTitle = String(current.order_status_title || '').toLowerCase();
  if (statusTitle !== 'новый') {
    return res.status(409).json({ error: 'Заказ можно редактировать только до подтверждения' });
  }

  const nextPickupTypeId = value.pickup_type_id != null ? Number(value.pickup_type_id) : Number(current.pickup_type_id);
  const nextPaymentMethodId =
    value.payment_method_id != null ? Number(value.payment_method_id) : Number(current.payment_method_id);
  const nextAddressId = value.address_id !== undefined ? value.address_id : current.address_id;
  const nextReceiveTime = value.receive_time != null ? new Date(value.receive_time).toISOString() : current.receive_time;
  const nextComment = value.comment !== undefined ? (value.comment ? String(value.comment) : null) : current.comment;

  const subtotal = (current.orderItems || []).reduce((sum, item) => sum + Number(item.item_total || 0), 0);
  const requestedBonus = value.spent_bonus != null ? Number(value.spent_bonus) : Number(current.spent_bonus || 0);

  let userBonusBalance = 0;
  try {
    userBonusBalance = await getUserBonusBalance(req.user.id);
  } catch {
    userBonusBalance = 0;
  }
  if (requestedBonus > userBonusBalance) {
    return res.status(400).json({ error: 'Недостаточно бонусов' });
  }
  const maxAllowedByPercent = calculateMaxSpendBonus(subtotal);
  if (requestedBonus > maxAllowedByPercent) {
    return res.status(400).json({
      error: `Можно списать не более ${Math.floor(BONUS_SPEND_LIMIT_PERCENT * 100)}% от суммы заказа`,
      max_spent_bonus: maxAllowedByPercent
    });
  }
  const spentBonus = Math.min(requestedBonus, Math.floor(subtotal), maxAllowedByPercent);
  const totalAmount = Math.max(0, subtotal - spentBonus);

  const isDelivery = nextPickupTypeId === 1;
  if (isDelivery) {
    if (!nextAddressId) return res.status(400).json({ error: 'Адрес обязателен для доставки' });
    const addr = await query(
      'SELECT id_address FROM delivery_addresses WHERE id_address = $1 AND user_id = $2 LIMIT 1',
      [nextAddressId, req.user.id]
    );
    if (!addr.rows[0]) return res.status(404).json({ error: 'Адрес не найден' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query(
      `UPDATE orders
       SET pickup_type_id = $1,
           payment_method_id = $2,
           address_id = $3,
           receive_time = $4,
           comment = $5,
           total_amount = $6,
           spent_bonus = $7
       WHERE id_order = $8 AND user_id = $9`,
      [nextPickupTypeId, nextPaymentMethodId, nextAddressId || null, nextReceiveTime, nextComment, totalAmount, spentBonus, orderId, req.user.id]
    );

    const oldSpentBonus = Number(current.spent_bonus || 0);
    const diff = spentBonus - oldSpentBonus;
    if (diff !== 0) {
      const writeOffTypeId = await getBonusOperationTypeIdByTitle('Списание', 2);
      const accrualTypeId = await getBonusOperationTypeIdByTitle('Начисление', 1);
      if (writeOffTypeId) {
        if (diff > 0) {
          await client.query(
            `INSERT INTO bonus_operations (user_id, bonus_operation_type_id, bonus_amount, order_id)
             VALUES ($1, $2, $3, $4)`,
            [req.user.id, writeOffTypeId, diff, orderId]
          );
        } else {
          await client.query(
            `INSERT INTO bonus_operations (user_id, bonus_operation_type_id, bonus_amount, order_id)
             VALUES ($1, $2, $3, $4)`,
            [req.user.id, accrualTypeId, Math.abs(diff), orderId]
          );
        }
      }
    }

    await client.query('COMMIT');
  } catch (e) {
    await client.query('ROLLBACK');
    console.error('Update order before confirmation error:', e);
    return res.status(500).json({ error: 'Не удалось изменить заказ' });
  } finally {
    client.release();
  }

  const updatedOrder = await getOrderWithItems(orderId, req.user.id);
  return res.json(updatedOrder);
});

module.exports = router;
