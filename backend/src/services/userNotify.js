const { query, pool } = require('../db');
const { sendPushToUser } = require('../utils/sendPush');

async function createNotificationWithPush(userId, title, text) {
  const t = String(title).trim().slice(0, 100);
  const body = String(text).trim().slice(0, 300);

  const ins = await query(
    `INSERT INTO notifications (user_id, title, text, is_read)
     VALUES ($1, $2, $3, FALSE)
     RETURNING id_notification, user_id, title, text, is_read, created_at`,
    [userId, t, body]
  );
  const row = ins.rows[0];

  try {
    await sendPushToUser(
      pool,
      userId,
      t,
      body,
      { id_notification: row.id_notification }
    );
  } catch (e) {
    console.error('[OneSignal] sendPushToUser:', e.message || e);
  }

  return row;
}

module.exports = { createNotificationWithPush };
