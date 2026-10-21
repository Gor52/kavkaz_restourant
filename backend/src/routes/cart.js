const { Router } = require('express');
const { query } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const router = Router();

const getOrCreateCart = async (userId) => {
  const cartResult = await query('SELECT * FROM carts WHERE user_id = $1 LIMIT 1', [userId]);
  if (cartResult.rows[0]) return cartResult.rows[0];
  const createdResult = await query('INSERT INTO carts (user_id) VALUES ($1) RETURNING *', [userId]);
  return createdResult.rows[0];
};

router.get('/items', authenticateToken, async (req, res) => {
  const cart = await getOrCreateCart(req.user.id);
  const itemsResult = await query(
    `SELECT ci.*, d.id_dish AS d_id_dish, d.category_id AS d_category_id, d.title AS d_title, d.description AS d_description,
            d.ingredients AS d_ingredients, d.price AS d_price, d.weight AS d_weight, d.calories AS d_calories,
            d.allergens AS d_allergens, d.photo_path AS d_photo_path, d.is_available AS d_is_available, d.created_at AS d_created_at
     FROM cart_items ci
     JOIN dishes d ON d.id_dish = ci.dish_id
     WHERE ci.cart_id = $1
     ORDER BY ci.id_cart_item DESC`,
    [cart.id_cart]
  );
  const cartItems = itemsResult.rows.map((row) => ({
    id_cart_item: row.id_cart_item,
    cart_id: row.cart_id,
    dish_id: row.dish_id,
    quantity: row.quantity,
    comment: row.comment,
    selected_options: row.selected_options,
    dish: {
      id_dish: row.d_id_dish,
      category_id: row.d_category_id,
      title: row.d_title,
      description: row.d_description,
      ingredients: row.d_ingredients,
      price: row.d_price,
      weight: row.d_weight,
      calories: row.d_calories,
      allergens: row.d_allergens,
      photo_path: row.d_photo_path,
      is_available: row.d_is_available,
      created_at: row.d_created_at
    }
  }));
  res.json(cartItems);
});

router.post('/items', authenticateToken, async (req, res) => {
  const { dish_id, quantity, comment, selected_options } = req.body;
  const dishId = Number(dish_id);
  const qty = Number(quantity);
  if (!Number.isInteger(dishId) || dishId <= 0) {
    return res.status(400).json({ error: 'Некорректный идентификатор блюда' });
  }
  if (!Number.isInteger(qty) || qty <= 0) {
    return res.status(400).json({ error: 'Некорректное количество' });
  }

  const cart = await getOrCreateCart(req.user.id);
  const normalizedComment =
    typeof comment === 'string' && comment.trim().length > 0
        ? comment.trim()
        : null;
  const normalizedOptions =
    typeof selected_options === 'string' && selected_options.trim().length > 0
        ? selected_options.trim()
        : null;

  const existingResult = await query(
    `SELECT id_cart_item, quantity
     FROM cart_items
     WHERE cart_id = $1
       AND dish_id = $2
       AND COALESCE(comment, '') = COALESCE($3, '')
       AND COALESCE(selected_options, '') = COALESCE($4, '')
     LIMIT 1`,
    [cart.id_cart, dishId, normalizedComment, normalizedOptions]
  );

  let item;
  if (existingResult.rows[0]) {
    const existing = existingResult.rows[0];
    const updatedResult = await query(
      `UPDATE cart_items
       SET quantity = $1
       WHERE id_cart_item = $2
       RETURNING *`,
      [Number(existing.quantity) + qty, existing.id_cart_item]
    );
    item = updatedResult.rows[0];
  } else {
    const createdResult = await query(
      `INSERT INTO cart_items (cart_id, dish_id, quantity, comment, selected_options)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [cart.id_cart, dishId, qty, normalizedComment, normalizedOptions]
    );
    item = createdResult.rows[0];
  }

  await query('UPDATE carts SET updated_at = CURRENT_TIMESTAMP WHERE id_cart = $1', [cart.id_cart]);
  return res.status(201).json(item);
});

router.put('/items/:cartItemId', authenticateToken, async (req, res) => {
  const updatedResult = await query(
    `UPDATE cart_items ci
     SET quantity = $1, comment = $2, selected_options = $3
     FROM carts c
     WHERE ci.id_cart_item = $4 AND ci.cart_id = c.id_cart AND c.user_id = $5
     RETURNING ci.*, c.id_cart AS owner_cart_id`,
    [
      Number(req.body.quantity),
      req.body.comment || null,
      req.body.selected_options || null,
      Number(req.params.cartItemId),
      req.user.id
    ]
  );
  const updated = updatedResult.rows[0];
  if (!updated) return res.status(404).json({ error: 'Позиция корзины не найдена' });
  await query('UPDATE carts SET updated_at = CURRENT_TIMESTAMP WHERE id_cart = $1', [updated.owner_cart_id]);
  delete updated.owner_cart_id;
  res.json(updated);
});

router.delete('/items/:cartItemId', authenticateToken, async (req, res) => {
  const delResult = await query(
    `DELETE FROM cart_items ci
     USING carts c
     WHERE ci.id_cart_item = $1 AND ci.cart_id = c.id_cart AND c.user_id = $2
     RETURNING c.id_cart`,
    [Number(req.params.cartItemId), req.user.id]
  );
  if (delResult.rows[0]) {
    await query('UPDATE carts SET updated_at = CURRENT_TIMESTAMP WHERE id_cart = $1', [delResult.rows[0].id_cart]);
  }
  res.status(204).send();
});

router.delete('/', authenticateToken, async (req, res) => {
  const cartResult = await query('SELECT id_cart FROM carts WHERE user_id = $1 LIMIT 1', [req.user.id]);
  const cart = cartResult.rows[0];
  if (cart) {
    await query('DELETE FROM cart_items WHERE cart_id = $1', [cart.id_cart]);
    await query('UPDATE carts SET updated_at = CURRENT_TIMESTAMP WHERE id_cart = $1', [cart.id_cart]);
  }
  res.status(204).send();
});

module.exports = router;
