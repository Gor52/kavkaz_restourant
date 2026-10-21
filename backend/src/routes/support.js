const { Router } = require('express');
const Joi = require('joi');
const { query, pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { sendPushToUser } = require('../utils/sendPush');

const router = Router();

const createConversationSchema = Joi.object({
  subject: Joi.string().trim().max(150).allow('', null).optional()
});

const postMessageSchema = Joi.object({
  message_text: Joi.string().trim().min(1).max(2000).required()
});

function isStaff(roleId) {
  return Number(roleId) >= 2;
}

async function getConversationById(conversationId) {
  const r = await query(
    `SELECT
      sc.*,
      u.full_name AS user_name,
      u.phone AS user_phone,
      s.full_name AS assigned_staff_name
     FROM support_conversations sc
     LEFT JOIN users u ON u.id_user = sc.user_id
     LEFT JOIN users s ON s.id_user = sc.assigned_staff_id
     WHERE sc.id_support_conversation = $1
     LIMIT 1`,
    [conversationId]
  );
  return r.rows[0] || null;
}

async function notifyStaffAboutUserMessage({
  conversationId,
  senderUserId,
  senderName
}) {
  const staffResult = await query(
    `SELECT id_user
     FROM users
     WHERE role_id IN (2, 3)
       AND is_blocked = FALSE`
  );
  const staffUsers = staffResult.rows;
  if (!staffUsers.length) return;

  const title = 'Новое обращение в поддержку';
  const text = senderName && senderName.trim().length > 0
    ? `${senderName.trim()} написал(а) в чат поддержки`
    : `Пользователь #${senderUserId} написал(а) в чат поддержки`;

  for (const staff of staffUsers) {
    const staffId = Number(staff.id_user);
    await query(
      `INSERT INTO notifications (user_id, title, text, is_read)
       VALUES ($1, $2, $3, FALSE)`,
      [staffId, title, text]
    );
    try {
      await sendPushToUser(
        pool,
        staffId,
        title,
        text,
        {
          type: 'support_new_message',
          conversation_id: conversationId,
          from_user_id: senderUserId
        }
      );
    } catch (e) {
      console.error('[support] staff push error:', e.message || e);
    }
  }
}

async function notifyUserAboutStaffMessage({
  conversationId,
  userId,
  senderName
}) {
  const title = 'Ответ поддержки';
  const text = senderName && senderName.trim().length > 0
    ? `${senderName.trim()} ответил(а) в чате поддержки`
    : 'В чате поддержки появился новый ответ';

  await query(
    `INSERT INTO notifications (user_id, title, text, is_read)
     VALUES ($1, $2, $3, FALSE)`,
    [userId, title, text]
  );

  try {
    await sendPushToUser(
      pool,
      userId,
      title,
      text,
      {
        type: 'support_staff_reply',
        conversation_id: conversationId
      }
    );
  } catch (e) {
    console.error('[support] user push error:', e.message || e);
  }
}

async function ensureConversationAccess(req, res, conversationId) {
  const conversation = await getConversationById(conversationId);
  if (!conversation) {
    res.status(404).json({ error: 'Диалог не найден' });
    return null;
  }
  const staff = isStaff(req.user.roleId);
  if (!staff && Number(conversation.user_id) !== Number(req.user.id)) {
    res.status(403).json({ error: 'Недостаточно прав для этого диалога' });
    return null;
  }
  return conversation;
}

router.use(authenticateToken);

router.get('/conversations', async (req, res) => {
  const staff = isStaff(req.user.roleId);
  const sql = staff
    ? `SELECT
        sc.*,
        u.full_name AS user_name,
        u.phone AS user_phone,
        s.full_name AS assigned_staff_name,
        (
          SELECT sm.message_text
          FROM support_messages sm
          WHERE sm.conversation_id = sc.id_support_conversation
          ORDER BY sm.created_at DESC, sm.id_support_message DESC
          LIMIT 1
        ) AS last_message_text,
        (
          SELECT COUNT(*)::int
          FROM support_messages sm
          WHERE sm.conversation_id = sc.id_support_conversation
            AND sm.sender_user_id <> $1
            AND sm.is_read = FALSE
        ) AS unread_count
       FROM support_conversations sc
       LEFT JOIN users u ON u.id_user = sc.user_id
       LEFT JOIN users s ON s.id_user = sc.assigned_staff_id
       ORDER BY sc.created_at DESC, sc.id_support_conversation DESC`
    : `SELECT
        sc.*,
        u.full_name AS user_name,
        u.phone AS user_phone,
        s.full_name AS assigned_staff_name,
        (
          SELECT sm.message_text
          FROM support_messages sm
          WHERE sm.conversation_id = sc.id_support_conversation
          ORDER BY sm.created_at DESC, sm.id_support_message DESC
          LIMIT 1
        ) AS last_message_text,
        (
          SELECT COUNT(*)::int
          FROM support_messages sm
          WHERE sm.conversation_id = sc.id_support_conversation
            AND sm.sender_user_id <> $1
            AND sm.is_read = FALSE
        ) AS unread_count
       FROM support_conversations sc
       LEFT JOIN users u ON u.id_user = sc.user_id
       LEFT JOIN users s ON s.id_user = sc.assigned_staff_id
       WHERE sc.user_id = $1
       ORDER BY sc.created_at DESC, sc.id_support_conversation DESC`;

  const result = await query(sql, [req.user.id]);
  res.json(result.rows);
});

router.post('/conversations', async (req, res) => {
  if (isStaff(req.user.roleId)) {
    return res.status(403).json({ error: 'Сотрудники не создают клиентские диалоги' });
  }
  const { error, value } = createConversationSchema.validate(req.body || {});
  if (error) return res.status(400).json({ error: error.details[0].message });

  const opened = await query(
    `SELECT *
     FROM support_conversations
     WHERE user_id = $1 AND status = 'open'
     ORDER BY id_support_conversation DESC
     LIMIT 1`,
    [req.user.id]
  );
  if (opened.rows[0]) return res.json(opened.rows[0]);

  const created = await query(
    `INSERT INTO support_conversations (user_id, assigned_staff_id, status, subject)
     VALUES ($1, NULL, 'open', $2)
     RETURNING *`,
    [req.user.id, value.subject || null]
  );
  res.status(201).json(created.rows[0]);
});

router.put('/conversations/:conversationId/assign-to-me', async (req, res) => {
  if (!isStaff(req.user.roleId)) {
    return res.status(403).json({ error: 'Недостаточно прав' });
  }
  const conversationId = Number(req.params.conversationId);
  if (!Number.isInteger(conversationId) || conversationId <= 0) {
    return res.status(400).json({ error: 'Некорректный идентификатор диалога' });
  }

  const updated = await query(
    `UPDATE support_conversations
     SET assigned_staff_id = $1
     WHERE id_support_conversation = $2
     RETURNING *`,
    [req.user.id, conversationId]
  );
  if (!updated.rows[0]) return res.status(404).json({ error: 'Диалог не найден' });
  res.json(updated.rows[0]);
});

router.put('/conversations/:conversationId/close', async (req, res) => {
  if (!isStaff(req.user.roleId)) {
    return res.status(403).json({ error: 'Недостаточно прав' });
  }
  const conversationId = Number(req.params.conversationId);
  if (!Number.isInteger(conversationId) || conversationId <= 0) {
    return res.status(400).json({ error: 'Некорректный идентификатор диалога' });
  }
  const updated = await query(
    `UPDATE support_conversations
     SET status = 'closed', closed_at = CURRENT_TIMESTAMP
     WHERE id_support_conversation = $1
     RETURNING *`,
    [conversationId]
  );
  if (!updated.rows[0]) return res.status(404).json({ error: 'Диалог не найден' });
  res.json(updated.rows[0]);
});

router.get('/conversations/:conversationId/messages', async (req, res) => {
  const conversationId = Number(req.params.conversationId);
  if (!Number.isInteger(conversationId) || conversationId <= 0) {
    return res.status(400).json({ error: 'Некорректный идентификатор диалога' });
  }
  const conversation = await ensureConversationAccess(req, res, conversationId);
  if (!conversation) return;

  const messages = await query(
    `SELECT
      sm.*,
      u.full_name AS sender_name,
      u.role_id AS sender_role_id
     FROM support_messages sm
     LEFT JOIN users u ON u.id_user = sm.sender_user_id
     WHERE sm.conversation_id = $1
     ORDER BY sm.created_at ASC, sm.id_support_message ASC`,
    [conversationId]
  );
  res.json({
    conversation,
    messages: messages.rows
  });
});

router.post('/conversations/:conversationId/messages', async (req, res) => {
  const conversationId = Number(req.params.conversationId);
  if (!Number.isInteger(conversationId) || conversationId <= 0) {
    return res.status(400).json({ error: 'Некорректный идентификатор диалога' });
  }
  const { error, value } = postMessageSchema.validate(req.body || {});
  if (error) return res.status(400).json({ error: error.details[0].message });

  const conversation = await ensureConversationAccess(req, res, conversationId);
  if (!conversation) return;
  if (conversation.status === 'closed') {
    return res.status(409).json({ error: 'Диалог закрыт' });
  }

  if (isStaff(req.user.roleId)) {
    const me = await query(
      'SELECT role_id FROM users WHERE id_user = $1 LIMIT 1',
      [req.user.id]
    );
    const roleId = Number(me.rows[0]?.role_id || 0);
    if (roleId < 2) {
      return res.status(403).json({ error: 'Только менеджер или администратор может консультировать' });
    }
  }

  const inserted = await query(
    `INSERT INTO support_messages (conversation_id, sender_user_id, message_text, is_read)
     VALUES ($1, $2, $3, FALSE)
     RETURNING *`,
    [conversationId, req.user.id, value.message_text]
  );

  if (!isStaff(req.user.roleId)) {
    try {
      const senderResult = await query(
        'SELECT full_name FROM users WHERE id_user = $1 LIMIT 1',
        [req.user.id]
      );
      await notifyStaffAboutUserMessage({
        conversationId,
        senderUserId: req.user.id,
        senderName: senderResult.rows[0]?.full_name || null
      });
    } catch (e) {
      console.error('[support] notify staff failed:', e.message || e);
    }
  } else {
    try {
      const senderResult = await query(
        'SELECT full_name FROM users WHERE id_user = $1 LIMIT 1',
        [req.user.id]
      );
      await notifyUserAboutStaffMessage({
        conversationId,
        userId: Number(conversation.user_id),
        senderName: senderResult.rows[0]?.full_name || null
      });
    } catch (e) {
      console.error('[support] notify user failed:', e.message || e);
    }
  }

  res.status(201).json(inserted.rows[0]);
});

router.put('/conversations/:conversationId/read', async (req, res) => {
  const conversationId = Number(req.params.conversationId);
  if (!Number.isInteger(conversationId) || conversationId <= 0) {
    return res.status(400).json({ error: 'Некорректный идентификатор диалога' });
  }
  const conversation = await ensureConversationAccess(req, res, conversationId);
  if (!conversation) return;

  await query(
    `UPDATE support_messages
     SET is_read = TRUE
     WHERE conversation_id = $1
       AND sender_user_id <> $2`,
    [conversationId, req.user.id]
  );

  res.json({ message: 'Сообщения отмечены как прочитанные' });
});

module.exports = router;
