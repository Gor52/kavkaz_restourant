const jwt = require('jsonwebtoken');

const authenticateToken = (req, res, next) => {
  const authHeader = req.headers.authorization;
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Требуется токен доступа' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = { id: decoded.userId, roleId: decoded.roleId };
    next();
  } catch (error) {
    return res.status(403).json({ error: 'Недействительный или просроченный токен' });
  }
};

const requireRole = (requiredRoleId) => {
  return (req, res, next) => {
    if (!req.user) return res.status(401).json({ error: 'Требуется авторизация' });
    if (req.user.roleId < requiredRoleId) return res.status(403).json({ error: 'Недостаточно прав' });
    next();
  };
};

module.exports = { authenticateToken, requireRole };
