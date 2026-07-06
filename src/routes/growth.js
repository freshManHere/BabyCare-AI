import { Router } from 'express';
import { query } from '../db/index.js';
import { babyGuard } from '../middleware/babyGuard.js';

export const growthRouter = Router();

// GET /babies/:babyId/growth
growthRouter.get('/:babyId/growth', babyGuard, async (req, res, next) => {
  try {
    const { from, to } = req.query;
    const params = [req.params.babyId];
    let sql = 'SELECT * FROM growth_records WHERE baby_id=$1';
    if (from) { params.push(from); sql += ` AND date >= $${params.length}`; }
    if (to)   { params.push(to);   sql += ` AND date <= $${params.length}`; }
    sql += ' ORDER BY date';
    const result = await query(sql, params);
    res.json(result.rows);
  } catch (err) { next(err); }
});

// POST /babies/:babyId/growth  (upsert — same day overwrites)
growthRouter.post('/:babyId/growth', babyGuard, async (req, res, next) => {
  try {
    const { id, date, weightKg, heightCm, headCm } = req.body;
    const result = await query(
      `INSERT INTO growth_records (id, baby_id, date, weight_kg, height_cm, head_cm)
       VALUES (COALESCE($1, gen_random_uuid()), $2, $3, $4, $5, $6)
       ON CONFLICT (baby_id, date) DO UPDATE
       SET weight_kg=$4, height_cm=$5, head_cm=$6, updated_at=NOW()
       RETURNING *`,
      [id || null, req.params.babyId, date, weightKg || null, heightCm || null, headCm || null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) { next(err); }
});

// DELETE /babies/:babyId/growth/:id
growthRouter.delete('/:babyId/growth/:id', babyGuard, async (req, res, next) => {
  try {
    await query('DELETE FROM growth_records WHERE id=$1 AND baby_id=$2', [req.params.id, req.params.babyId]);
    res.json({ message: 'Deleted' });
  } catch (err) { next(err); }
});

// Middleware is now in src/middleware/babyGuard.js
