const { Router } = require('express');
const { query } = require('../db');
const router = Router();

router.get('/', (req, res) =>
  res.json({
    hint: 'Используйте /menu/categories или /menu/dishes',
    endpoints: ['/menu/categories', '/menu/dishes', '/menu/dishes/:dishId']
  })
);

router.get('/categories', async (req, res) => {
  const categoriesResult = await query('SELECT * FROM categories ORDER BY sort_order ASC');
  const categories = categoriesResult.rows;
  res.json(categories);
});

router.get('/dishes', async (req, res) => {
  const { category_id, search, sort, available } = req.query;
  const clauses = [];
  const params = [];

  if (category_id) {
    params.push(Number(category_id));
    clauses.push(`category_id = $${params.length}`);
  }
  if (search) {
    params.push(`%${String(search)}%`);
    const i = params.length;
    clauses.push(`(title ILIKE $${i} OR description ILIKE $${i})`);
  }
  if (available === 'true') {
    clauses.push('is_available = true');
  }

  let orderBy = 'created_at DESC';
  if (sort === 'price_asc') orderBy = 'price ASC';
  if (sort === 'price_desc') orderBy = 'price DESC';
  if (sort === 'title') orderBy = 'title ASC';

  const whereSql = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
  const dishesResult = await query(`SELECT * FROM dishes ${whereSql} ORDER BY ${orderBy}`, params);
  const dishes = dishesResult.rows;
  res.json(dishes);
});

router.get('/dishes/:dishId', async (req, res) => {
  const dishResult = await query('SELECT * FROM dishes WHERE id_dish = $1 LIMIT 1', [Number(req.params.dishId)]);
  const dish = dishResult.rows[0];
  if (!dish) return res.status(404).json({ error: 'Блюдо не найдено' });
  return res.json(dish);
});

module.exports = router;
