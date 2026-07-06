import { Router } from 'express';
import { query } from '../db/index.js';
import { babyGuard } from '../middleware/babyGuard.js';

export const babiesRouter = Router();

// GET /babies
babiesRouter.get('/', async (req, res, next) => {
  try {
    const result = await query(
      'SELECT * FROM babies WHERE user_id = $1 ORDER BY created_at',
      [req.userId]
    );
    res.json(result.rows);
  } catch (err) { next(err); }
});

// POST /babies
babiesRouter.post('/', async (req, res, next) => {
  try {
    const { id, name, nickname, birthday, gender, avatarUrl } = req.body;
    const result = await query(
      `INSERT INTO babies (id, user_id, name, nickname, birthday, gender, avatar_url)
       VALUES (COALESCE($1, gen_random_uuid()), $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [id || null, req.userId, name, nickname, birthday, gender, avatarUrl || null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) { next(err); }
});

// PUT /babies/:babyId
babiesRouter.put('/:babyId', babyGuard, async (req, res, next) => {
  try {
    const { name, nickname, birthday, gender, avatarUrl } = req.body;
    const result = await query(
      `UPDATE babies SET name=$1, nickname=$2, birthday=$3, gender=$4,
       avatar_url=$5, updated_at=NOW() WHERE id=$6 RETURNING *`,
      [name, nickname, birthday, gender, avatarUrl || null, req.params.babyId]
    );
    res.json(result.rows[0]);
  } catch (err) { next(err); }
});

// DELETE /babies/:babyId
babiesRouter.delete('/:babyId', babyGuard, async (req, res, next) => {
  try {
    await query('DELETE FROM babies WHERE id = $1', [req.params.babyId]);
    res.json({ message: 'Deleted' });
  } catch (err) { next(err); }
});

// ownerGuard is now handled by shared babyGuard middleware
