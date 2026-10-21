const ONE_SIGNAL_API_URL = 'https://api.onesignal.com/notifications?c=push';

function getOneSignalConfig() {
  const appId = process.env.ONESIGNAL_APP_ID;
  const apiKey = process.env.ONESIGNAL_REST_API_KEY;
  const androidChannelId =
    process.env.ONESIGNAL_ANDROID_CHANNEL_ID || 'orders_status_channel';
  if (!appId || !apiKey) return null;
  return { appId, apiKey, androidChannelId };
}

async function sendPushToUser(pool, userId, title, body, data = {}) {
  const cfg = getOneSignalConfig();
  if (!cfg) {
    console.warn('[OneSignal] ONESIGNAL_APP_ID/ONESIGNAL_REST_API_KEY not set');
    return;
  }

  const tokensResult = await pool.query(
    `
    SELECT fcm_token
    FROM device_tokens
    WHERE user_id = $1
    `,
    [userId]
  );

  const tokens = [...new Set(tokensResult.rows.map((row) => row.fcm_token).filter(Boolean))];
  if (!tokens.length) return;

  const payload = {
    app_id: cfg.appId,
    include_subscription_ids: tokens,
    headings: { en: title, ru: title },
    contents: { en: body, ru: body },
    data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
    android_channel_id: cfg.androidChannelId,
  };

  const response = await fetch(ONE_SIGNAL_API_URL, {
    method: 'POST',
    headers: {
      Authorization: `Key ${cfg.apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`OneSignal send failed (${response.status}): ${errText}`);
  }
}

module.exports = { sendPushToUser };
