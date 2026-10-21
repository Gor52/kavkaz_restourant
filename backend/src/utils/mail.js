const nodemailer = require('nodemailer');

function createTransport() {
  if (String(process.env.MAIL_MODE || '').toLowerCase() === 'log') {
    return null;
  }
  const host = process.env.SMTP_HOST;
  if (!host) return null;
  const port = Number(process.env.SMTP_PORT || 587);
  const secure = String(process.env.SMTP_SECURE || '').toLowerCase() === 'true';
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  return nodemailer.createTransport({
    host,
    port,
    secure,
    auth: user ? { user, pass: pass || '' } : undefined,
    ...(port === 587 && !secure ? { requireTLS: true } : {})
  });
}

async function sendPasswordResetMail({ to, code, appName = 'Kavkaz Restaurant' }) {
  const from = process.env.MAIL_FROM || process.env.SMTP_USER || 'noreply@localhost';
  const subject = `${appName} — код восстановления пароля`;
  const text = [
    `Код восстановления пароля: ${code}`,
    '',
    'Код действует 15 минут.',
    'Если вы не запрашивали сброс пароля, проигнорируйте это письмо.'
  ].join('\n');
  const html = `
    <p>Здравствуйте,</p>
    <p>Код восстановления пароля:</p>
    <p style="font-size:26px;font-weight:700;letter-spacing:6px">${code}</p>
    <p>Код действует <strong>15 минут</strong>.</p>
    <p style="color:#666;font-size:13px">Если вы не запрашивали сброс пароля, проигнорируйте это письмо.</p>
  `.trim();

  if (String(process.env.MAIL_MODE || '').toLowerCase() === 'log') {
    console.warn('[mail] password reset code for', to, code);
    return;
  }

  const transport = createTransport();
  if (!transport) {
    const err = new Error('SMTP не настроен.');
    err.code = 'MAIL_NOT_CONFIGURED';
    throw err;
  }

  await transport.sendMail({ from, to, subject, text, html });
}

async function sendRegistrationSuccessMail({ to, fullName, appName = 'Kavkaz Restaurant' }) {
  const from = process.env.MAIL_FROM || process.env.SMTP_USER || 'noreply@localhost';
  const subject = `${appName} — регистрация успешно завершена`;
  const safeName = String(fullName || '').trim() || 'Пользователь';
  const text = [
    `Здравствуйте, ${safeName}!`,
    '',
    `Вы успешно зарегистрировались в ${appName}.`,
    'Теперь вы можете оформлять заказы, отслеживать статусы и использовать бонусы.',
  ].join('\n');
  const html = `
    <p>Здравствуйте, ${safeName}!</p>
    <p>Вы успешно зарегистрировались в <strong>${appName}</strong>.</p>
    <p>Теперь вы можете оформлять заказы, отслеживать статусы и использовать бонусы.</p>
  `.trim();

  const transport = createTransport();
  if (!transport) {
    const err = new Error('SMTP не настроен.');
    err.code = 'MAIL_NOT_CONFIGURED';
    throw err;
  }

  await transport.sendMail({ from, to, subject, text, html });
}

async function sendOrderCreatedMail({
  to,
  fullName,
  orderId,
  totalAmount,
  appName = 'Kavkaz Restaurant'
}) {
  const from = process.env.MAIL_FROM || process.env.SMTP_USER || 'noreply@localhost';
  const subject = `${appName} — заказ №${orderId} оформлен`;
  const safeName = String(fullName || '').trim() || 'Пользователь';
  const total = Number(totalAmount || 0).toFixed(2);
  const text = [
    `Здравствуйте, ${safeName}!`,
    '',
    `Ваш заказ №${orderId} успешно оформлен.`,
    `Сумма заказа: ${total} ₽.`,
    '',
    'Спасибо, что выбрали нас!'
  ].join('\n');
  const html = `
    <p>Здравствуйте, ${safeName}!</p>
    <p>Ваш заказ <strong>№${orderId}</strong> успешно оформлен.</p>
    <p>Сумма заказа: <strong>${total} ₽</strong>.</p>
    <p>Спасибо, что выбрали нас!</p>
  `.trim();

  const transport = createTransport();
  if (!transport) {
    const err = new Error('SMTP не настроен.');
    err.code = 'MAIL_NOT_CONFIGURED';
    throw err;
  }

  await transport.sendMail({ from, to, subject, text, html });
}

async function sendLoginCodeMail({ to, code, appName = 'Kavkaz Restaurant' }) {
  const from = process.env.MAIL_FROM || process.env.SMTP_USER || 'noreply@localhost';
  const subject = `${appName} — код для входа`;
  const text = [
    `Код для входа в приложение: ${code}`,
    '',
    'Код действует 15 минут.',
    'Если вы не запрашивали вход, проигнорируйте это письмо.'
  ].join('\n');
  const html = `
    <p>Здравствуйте,</p>
    <p>Код для входа в приложение:</p>
    <p style="font-size:26px;font-weight:700;letter-spacing:6px">${code}</p>
    <p>Код действует <strong>15 минут</strong>.</p>
    <p style="color:#666;font-size:13px">Если вы не запрашивали вход, проигнорируйте это письмо.</p>
  `.trim();

  if (String(process.env.MAIL_MODE || '').toLowerCase() === 'log') {
    console.warn('[mail] login code for', to, code);
    return;
  }

  const transport = createTransport();
  if (!transport) {
    const err = new Error('SMTP не настроен.');
    err.code = 'MAIL_NOT_CONFIGURED';
    throw err;
  }

  await transport.sendMail({ from, to, subject, text, html });
}

module.exports = {
  sendPasswordResetMail,
  sendLoginCodeMail,
  sendRegistrationSuccessMail,
  sendOrderCreatedMail,
  createTransport
};
