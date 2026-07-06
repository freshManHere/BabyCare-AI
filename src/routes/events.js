import { Router } from 'express';
import { query } from '../db/index.js';
import { babyGuard } from '../middleware/babyGuard.js';

export const eventsRouter = Router();

// GET /babies/:babyId/events/sync  — MUST be before /:babyId/events to avoid route conflict
eventsRouter.get('/:babyId/events/sync', babyGuard, async (req, res, next) => {
  try {
    const { since } = req.query;
    if (!since) return res.status(400).json({ error: 'since parameter required' });
    const result = await query(
      `SELECT * FROM baby_events WHERE baby_id=$1 AND updated_at > $2 ORDER BY updated_at`,
      [req.params.babyId, since]
    );
    res.json(result.rows);
  } catch (err) { next(err); }
});

// GET /babies/:babyId/events  (?from=ISO&to=ISO&label=feeding&limit=200)
eventsRouter.get('/:babyId/events', babyGuard, async (req, res, next) => {
  try {
    const { from, to, label, cursor } = req.query;
    const limit = Math.min(Math.max(parseInt(req.query.limit) || 200, 1), 500);
    const params = [req.params.babyId];
    let sql = `SELECT * FROM baby_events WHERE baby_id=$1 AND deleted_at IS NULL`;

    if (from)   { params.push(from);  sql += ` AND start_time >= $${params.length}`; }
    if (to)     { params.push(to);    sql += ` AND start_time <= $${params.length}`; }
    if (label)  { params.push(label); sql += ` AND label = $${params.length}`; }
    if (cursor) { params.push(cursor); sql += ` AND start_time < $${params.length}`; }

    params.push(limit);
    sql += ` ORDER BY start_time DESC LIMIT $${params.length}`;

    const result = await query(sql, params);
    res.json(result.rows);
  } catch (err) { next(err); }
});

// POST /babies/:babyId/events  (upsert by id — returns 201 on insert, 200 on update)
eventsRouter.post('/:babyId/events', babyGuard, async (req, res, next) => {
  try {
    const { id, label, startTime, endTime, payload, note } = req.body;
    const isUpsert = !!id;
    const result = await query(
      `INSERT INTO baby_events (id, baby_id, label, start_time, end_time, payload, note)
       VALUES (COALESCE($1, gen_random_uuid()), $2, $3, $4, $5, $6, $7)
       ON CONFLICT (id) DO UPDATE
       SET label=$3, start_time=$4, end_time=$5, payload=$6, note=$7, updated_at=NOW()
       RETURNING *, (xmax = 0) AS inserted`,
      [id || null, req.params.babyId, label, startTime, endTime || null, payload || {}, note || '']
    );
    const row = result.rows[0];
    res.status(row.inserted ? 201 : 200).json(row);
  } catch (err) { next(err); }
});

// PUT /babies/:babyId/events/:id
eventsRouter.put('/:babyId/events/:id', babyGuard, async (req, res, next) => {
  try {
    const { label, startTime, endTime, payload, note } = req.body;
    const result = await query(
      `UPDATE baby_events SET label=$1, start_time=$2, end_time=$3, payload=$4, note=$5, updated_at=NOW()
       WHERE id=$6 AND baby_id=$7 AND deleted_at IS NULL RETURNING *`,
      [label, startTime, endTime || null, payload || {}, note || '', req.params.id, req.params.babyId]
    );
    if (!result.rows.length) return res.status(404).json({ error: 'Event not found' });
    res.json(result.rows[0]);
  } catch (err) { next(err); }
});

// DELETE /babies/:babyId/events/:id  (soft delete)
eventsRouter.delete('/:babyId/events/:id', babyGuard, async (req, res, next) => {
  try {
    await query(
      `UPDATE baby_events SET deleted_at=NOW(), updated_at=NOW() WHERE id=$1 AND baby_id=$2`,
      [req.params.id, req.params.babyId]
    );
    res.json({ message: 'Deleted' });
  } catch (err) { next(err); }
});

// Middleware is now in src/middleware/babyGuard.js
