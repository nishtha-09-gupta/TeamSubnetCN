// backend-B.js — Backend B (Mac 4 / Shrijan)
const express = require('express');
const app = express();

const PORT = 3002;
const BACKEND_ID = 'B';

app.get('/', (req, res) => {
  res.json({ message: `Backend ${BACKEND_ID} is running` });
});

app.get('/api/status', (req, res) => {
  res.set('X-Backend', BACKEND_ID);
  res.set('Cache-Control', 'max-age=60');
  res.json({ backend: BACKEND_ID, status: 'ok' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Backend ${BACKEND_ID} listening on 0.0.0.0:${PORT}`);
});
