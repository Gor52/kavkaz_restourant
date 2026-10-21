const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const { testDatabaseConnection, ensureOrderItemsDishTitleColumn } = require('./db');

const authRoutes = require('./routes/auth');
const menuRoutes = require('./routes/menu');
const cartRoutes = require('./routes/cart');
const bookingRoutes = require('./routes/booking');
const orderRoutes = require('./routes/order');
const profileRoutes = require('./routes/profile');
const reviewRoutes = require('./routes/review');
const notificationRoutes = require('./routes/notification');
const supportRoutes = require('./routes/support');
const adminRoutes = require('./routes/admin');
const { errorHandler } = require('./middleware/errorHandler');

const app = express();
const PORT = process.env.PORT || 3000;

app.set('trust proxy', 1);

const limiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 100, message: 'Слишком много запросов с этого IP. Попробуйте позже.' });
app.use(helmet());
const corsOrigins = (process.env.CORS_ORIGIN || 'http://localhost:3000')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);
app.use(
  cors({
    origin: corsOrigins.length === 1 ? corsOrigins[0] : corsOrigins,
    credentials: true
  })
);
app.use(morgan('combined'));
//app.use(limiter);
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use('/exports', express.static(path.join(__dirname, '..', 'exports')));
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

app.use('/auth', authRoutes);
app.use('/menu', menuRoutes);
app.use('/cart', cartRoutes);
app.use('/bookings', bookingRoutes);
app.use('/orders', orderRoutes);
app.use('/profile', profileRoutes);
app.use('/reviews', reviewRoutes);
app.use('/notifications', notificationRoutes);
app.use('/support', supportRoutes);
app.use('/admin', adminRoutes);
app.get('/', (req, res) =>
  res.json({
    name: 'kavkaz-restaurant-backend',
    health: '/health',
    routes: [
      '/auth',
      '/menu',
      '/cart',
      '/bookings',
      '/orders',
      '/profile',
      '/reviews',
      '/notifications',
      '/support',
      '/admin'
    ]
  })
);
app.get('/health', (req, res) => res.json({ status: 'OK', timestamp: new Date().toISOString() }));
app.use(errorHandler);
app.use('*', (req, res) => res.status(404).json({ error: 'Маршрут не найден' }));

async function startServer() {
  try {
    await testDatabaseConnection();
    await ensureOrderItemsDishTitleColumn();
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`Server listening on 0.0.0.0:${PORT}`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}
startServer();
