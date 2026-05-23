const express = require('express');
const router = express.Router();

const environments = [];

router.get('/environments', (req, res) => {
  res.json({ environments });
});

router.post('/environments', (req, res) => {
  const { name, type } = req.body;
  if (!name || !type) {
    return res.status(400).json({ error: 'name and type are required' });
  }
  const env = {
    id: Date.now().toString(),
    name,
    type,
    status: 'provisioning',
    created_at: new Date().toISOString()
  };
  environments.push(env);
  res.status(201).json(env);
});

router.delete('/environments/:id', (req, res) => {
  const index = environments.findIndex(e => e.id === req.params.id);
  if (index === -1) {
    return res.status(404).json({ error: 'Environment not found' });
  }
  const removed = environments.splice(index, 1)[0];
  res.json({ message: 'Environment destroyed', environment: removed });
});

module.exports = router;