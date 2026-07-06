import { query } from '../db/index.js';

/**
 * Verifies that req.params.babyId belongs to the authenticated user.
 * Attaches nothing extra — just gates the route.
 */
export async function babyGuard(req, res, next) {
  try {
    const result = await query(
      'SELECT id FROM babies WHERE id=$1 AND user_id=$2',
      [req.params.babyId, req.userId]
    );
    if (!result.rows.length) return res.status(404).json({ error: 'Baby not found' });
    next();
  } catch (err) { next(err); }
}
