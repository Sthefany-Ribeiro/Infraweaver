const request = require('supertest');
const app = require('../src/index');

describe('InfraWeaver API', () => {
  let server;

  beforeAll(() => {
    server = app.listen(0);
  });

  afterAll((done) => {
    server.close(done);
  });

  test('GET /health returns ok', async () => {
    const res = await request(server).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  test('GET /api/environments returns empty list', async () => {
    const res = await request(server).get('/api/environments');
    expect(res.statusCode).toBe(200);
    expect(res.body.environments).toEqual([]);
  });

  test('POST /api/environments creates environment', async () => {
    const res = await request(server)
      .post('/api/environments')
      .send({ name: 'test-env', type: 'development' });
    expect(res.statusCode).toBe(201);
    expect(res.body.name).toBe('test-env');
    expect(res.body.status).toBe('provisioning');
  });

  test('POST /api/environments returns 400 without name', async () => {
    const res = await request(server)
      .post('/api/environments')
      .send({ type: 'development' });
    expect(res.statusCode).toBe(400);
  });
});