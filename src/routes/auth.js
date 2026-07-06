import { Router } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { createHash } from 'crypto';
import rateLimit from 'express-rate-limit';
import { query } from '../db/index.js';
import { authenticate } from '../middleware/auth.js';

export const authRouter = Router();

const limiter = rateLimit({ windowMs: 60_000, max: 10, standardHeaders: true, legacyHeaders: false });

// POST /auth/register
authRouter.post('/register', limiter, async (req, res, next) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'email and password required' });
    if (password.length < 8) return res.status(400).json({ error: 'password must be at least 8 characters' });

    const exists = await query('SELECT id FROM users WHERE email = $1', [email.toLowerCase()]);
    if (exists.rows.length) return res.status(409).json({ error: 'Email already registered' });

    const hash = await bcrypt.hash(password, 12);
    const result = await query(
      'INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id, email, created_at',
      [email.toLowerCase(), hash]
    );
    const user = result.rows[0];
    const { accessToken, refreshToken } = await issueTokens(user.id);
    res.status(201).json({ user: { id: user.id, email: user.email }, accessToken, refreshToken });
  } catch (err) { next(err); }
});

// POST /auth/login
authRouter.post('/login', limiter, async (req, res, next) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'email and password required' });

    const result = await query('SELECT id, password_hash FROM users WHERE email = $1', [email.toLowerCase()]);
    const user = result.rows[0];
    if (!user) return res.status(401).json({ error: 'Invalid credentials' });

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) return res.status(401).json({ error: 'Invalid credentials' });

    const { accessToken, refreshToken } = await issueTokens(user.id);
    res.json({ accessToken, refreshToken });
  } catch (err) { next(err); }
});

// POST /auth/refresh
authRouter.post('/refresh', async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) return res.status(400).json({ error: 'refreshToken required' });

    let payload;
    try {
      payload = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
    } catch {
      return res.status(401).json({ error: 'Invalid or expired refresh token' });
    }

    // Check token exists in db
    const hash = createHash('sha256').update(refreshToken).digest('hex');
    const found = await query(
      'SELECT id FROM refresh_tokens WHERE token_hash = $1 AND user_id = $2 AND expires_at > NOW()',
      [hash, payload.userId]
    );
    if (!found.rows.length) return res.status(401).json({ error: 'Refresh token revoked or expired' });

    // Rotate — delete old, issue new
    await query('DELETE FROM refresh_tokens WHERE token_hash = $1', [hash]);
    const { accessToken, refreshToken: newRefreshToken } = await issueTokens(payload.userId);
    res.json({ accessToken, refreshToken: newRefreshToken });
  } catch (err) { next(err); }
});

// DELETE /auth/account  (App Store requirement)
authRouter.delete('/account', authenticate, async (req, res, next) => {
  try {
    await query('DELETE FROM users WHERE id = $1', [req.userId]);
    res.json({ message: 'Account deleted' });
  } catch (err) { next(err); }
});

// --- helpers ---
async function issueTokens(userId) {
  const accessToken = jwt.sign({ userId }, process.env.JWT_SECRET, { expiresIn: '7d' });
  const refreshToken = jwt.sign({ userId }, process.env.JWT_REFRESH_SECRET, { expiresIn: '30d' });

  const hash = createHash('sha256').update(refreshToken).digest('hex');
  const expires = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
  await query(
    'INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)',
    [userId, hash, expires]
  );
  return { accessToken, refreshToken };
}
