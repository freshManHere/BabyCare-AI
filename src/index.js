import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { authRouter } from './routes/auth.js';
import { babiesRouter } from './routes/babies.js';
import { eventsRouter } from './routes/events.js';
import { growthRouter } from './routes/growth.js';
import { authenticate } from './middleware/auth.js';

const app = express();
const PORT = process.env.PORT || 3000;

// CORS
const allowedOrigins = (process.env.ALLOWED_ORIGINS || '').split(',').map(s => s.trim()).filter(Boolean);
app.use(cors({
  origin: allowedOrigins.length ? allowedOrigins : '*',
  credentials: true,
}));

app.use(express.json({ limit: '100kb' }));

// Health check (public)
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Auth routes (public)
app.use('/auth', authRouter);

// Protected routes
app.use('/babies', authenticate, babiesRouter);
app.use('/babies', authenticate, eventsRouter);
app.use('/babies', authenticate, growthRouter);

// 404
app.use((req, res) => res.status(404).json({ error: 'Not found' }));

// Error handler
app.use((err, req, res, _next) => {
  console.error(err);
  const isProd = process.env.NODE_ENV === 'production';
  res.status(err.status || 500).json({
    error: isProd && !err.status ? 'Internal server error' : (err.message || 'Internal server error')
  });
});

app.listen(PORT, () => console.log(`[BabyCare API] listening on port ${PORT}`));
