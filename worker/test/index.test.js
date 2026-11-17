import { test } from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/index.js';

const env = { GEMINI_API_KEY: 'test-key', AI_LIMIT: { limit: async () => ({ success: true }) } };
const req = body => new Request('https://example.com/generate', { method: 'POST', headers: { 'CF-Connecting-IP': '1.2.3.4' }, body: JSON.stringify(body) });
const valid = { topic: 'Nấu ăn', count: 1, level: 'Nhớ', bilingual: false };

test('validates input and rate limit before calling Gemini', async () => {
  assert.equal((await worker.fetch(req({ ...valid, count: 11 }), env)).status, 400);
  assert.equal((await worker.fetch(req(valid), { ...env, AI_LIMIT: { limit: async () => ({ success: false }) } })).status, 429);
  assert.equal((await worker.fetch(req(valid), {})).status, 503);
});

test('returns validated cards and never exposes the Gemini key', async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (_url, options) => {
    assert.equal(options.headers['x-goog-api-key'], 'test-key');
    assert.equal(JSON.parse(options.body).generationConfig.responseFormat.text.mimeType, 'APPLICATION_JSON');
    return Response.json({ candidates: [{ finishReason: 'STOP', content: { parts: [{ text: JSON.stringify({ cards: [{ front: 'Câu hỏi', back: 'Đáp án' }] }) }] } }] });
  };
  try {
    const response = await worker.fetch(req(valid), env);
    assert.equal(response.status, 200);
    const body = await response.text();
    assert.deepEqual(JSON.parse(body), { cards: [{ front: 'Câu hỏi', back: 'Đáp án' }] });
    assert.equal(body.includes('test-key'), false);
  } finally { globalThis.fetch = originalFetch; }
});

test('rejects malformed model output and maps provider quota errors', async () => {
  const originalFetch = globalThis.fetch;
  try {
    globalThis.fetch = async () => Response.json({ candidates: [{ finishReason: 'STOP', content: { parts: [{ text: '{"cards":[]}' }] } }] });
    assert.equal((await worker.fetch(req(valid), env)).status, 502);
    globalThis.fetch = async () => new Response('', { status: 429 });
    assert.equal((await worker.fetch(req(valid), env)).status, 429);
    globalThis.fetch = async () => new Response('private provider error', { status: 404 });
    const missing = await worker.fetch(req(valid), env);
    assert.deepEqual(await missing.json(), { error: 'provider_model_unavailable', providerStatus: 404 });
    globalThis.fetch = async () => Response.json({ error: { message: 'User location is not supported for the API use.' } }, { status: 400 });
    const region = await worker.fetch(req(valid), env);
    assert.equal((await region.json()).providerReason, 'LOCATION_NOT_SUPPORTED');
  } finally { globalThis.fetch = originalFetch; }
});
