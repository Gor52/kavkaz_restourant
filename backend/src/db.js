const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

const query = (text, params = []) => pool.query(text, params);

const dbUserFromDatabaseUrl = () => {
  const url = process.env.DATABASE_URL;
  if (!url) return null;
  try {
    const u = new URL(url);
    const name = u.username ? decodeURIComponent(u.username) : '';
    return name || null;
  } catch {
    return null;
  }
};

const dbNameFromDatabaseUrl = () => {
  const url = process.env.DATABASE_URL;
  if (!url) return null;
  try {
    const u = new URL(url);
    const path = u.pathname || '';
    const name = path.replace(/^\//, '').split('/')[0];
    return name || null;
  } catch {
    return null;
  }
};

const printDatabaseMissingHint = (err) => {
  if (!err || err.code !== '3D000') return;
  const dbName = dbNameFromDatabaseUrl() || 'kavkaz_restaurant';
  console.error(`[PostgreSQL] База не найдена (${err.code}): "${dbName}". Создайте базу и укажите её в DATABASE_URL.`);
};

const printConnectionHint = (err) => {
  if (!err || err.code !== '28000') return;
  const role = dbUserFromDatabaseUrl() || '(не удалось прочитать из DATABASE_URL)';
  console.error(`[PostgreSQL] Ошибка входа (${err.code}): ${err.message}. Роль из DATABASE_URL: "${role}".`);
};

const testDatabaseConnection = async () => {
  if (!process.env.DATABASE_URL || !String(process.env.DATABASE_URL).trim()) {
    throw new Error('В .env не задан DATABASE_URL');
  }
  try {
    await pool.query('SELECT 1');
  } catch (e) {
    printConnectionHint(e);
    printDatabaseMissingHint(e);
    throw e;
  }
};

const ensureOrderItemsDishTitleColumn = async () => {
  try {
    await pool.query(`
      ALTER TABLE order_items
      ADD COLUMN IF NOT EXISTS dish_title VARCHAR(100)
    `);
    await pool.query(`
      UPDATE order_items oi
      SET dish_title = d.title
      FROM dishes d
      WHERE oi.dish_id = d.id_dish
        AND (oi.dish_title IS NULL OR trim(oi.dish_title) = '')
    `);
  } catch (e) {
    console.warn('[DB] Не удалось подготовить order_items.dish_title:', e.message || e);
  }
};

module.exports = {
  pool,
  query,
  testDatabaseConnection,
  ensureOrderItemsDishTitleColumn
};
