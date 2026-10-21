const errorHandler = (err, req, res, next) => {
  console.error('Error:', err);

  if (err && err.code) {
    if (err.code === '23505') return res.status(409).json({ error: 'Нарушено ограничение уникальности данных' });
    if (err.code === '23503') return res.status(400).json({ error: 'Нарушена ссылочная целостность данных' });
    return res.status(500).json({ error: 'Ошибка базы данных' });
  }

  if (err && err.name === 'JsonWebTokenError') return res.status(401).json({ error: 'Недействительный токен' });
  if (err && err.name === 'TokenExpiredError') return res.status(401).json({ error: 'Срок действия токена истек' });

  if (err && err.isJoi) {
    return res.status(400).json({
      error: 'Ошибка валидации',
      details: err.details.map((detail) => detail.message)
    });
  }

  return res.status(err.statusCode || 500).json({ error: err.message || 'Внутренняя ошибка сервера' });
};

module.exports = { errorHandler };
