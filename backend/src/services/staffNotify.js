const { query, pool } = require('../db');
const { sendPushToUser } = require('../utils/sendPush');

async function getStaffUserIds() {
  const staffResult = await query(
    `SELECT id_user
     FROM users
     WHERE role_id IN (2, 3)
       AND is_blocked = FALSE`
  );
  return staffResult.rows.map((row) => Number(row.id_user));
}

async function notifyStaff({ title, text, data = {} }) {
  const staffIds = await getStaffUserIds();
  if (!staffIds.length) return;

  const notificationTitle = String(title).trim().slice(0, 100);
  const notificationText = String(text).trim().slice(0, 300);

  for (const staffId of staffIds) {
    try {
      await query(
        `INSERT INTO notifications (user_id, title, text, is_read)
         VALUES ($1, $2, $3, FALSE)`,
        [staffId, notificationTitle, notificationText]
      );
    } catch (e) {
      console.error('[staffNotify] insert notification:', e.message || e);
    }

    try {
      await sendPushToUser(
        pool,
        staffId,
        notificationTitle,
        notificationText,
        Object.fromEntries(
          Object.entries(data).map(([key, value]) => [key, String(value)])
        )
      );
    } catch (e) {
      console.error('[staffNotify] push error:', e.message || e);
    }
  }
}

async function notifyStaffAboutNewOrder({ orderId, customerName, totalAmount }) {
  const name =
    customerName && String(customerName).trim().length > 0
      ? String(customerName).trim()
      : 'Клиент';
  const amountText =
    totalAmount != null ? ` на сумму ${Number(totalAmount).toFixed(2)} ₽` : '';

  await notifyStaff({
    title: 'Новый заказ',
    text: `${name} оформил(а) заказ №${orderId}${amountText}`,
    data: {
      type: 'admin_new_order',
      order_id: orderId,
    },
  });
}

async function notifyStaffAboutNewBooking({
  bookingId,
  customerName,
  bookingDate,
  bookingTime,
  guestCount,
}) {
  const name =
    customerName && String(customerName).trim().length > 0
      ? String(customerName).trim()
      : 'Клиент';
  const datePart = bookingDate ? String(bookingDate).slice(0, 10) : '';
  const timePart = bookingTime ? String(bookingTime).slice(0, 5) : '';
  const when =
    datePart && timePart
      ? ` на ${datePart} в ${timePart}`
      : datePart
        ? ` на ${datePart}`
        : '';
  const guests =
    guestCount != null ? `, гостей: ${Number(guestCount)}` : '';

  await notifyStaff({
    title: 'Новая бронь',
    text: `${name} создал(а) бронь №${bookingId}${when}${guests}`,
    data: {
      type: 'admin_new_booking',
      booking_id: bookingId,
    },
  });
}

module.exports = {
  notifyStaff,
  notifyStaffAboutNewOrder,
  notifyStaffAboutNewBooking,
};
