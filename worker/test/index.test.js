import { beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/index.js';

const env = { GEMINI_API_KEY: 'test-key', AI_LIMIT: { limit: async () => ({ success: true }) } };
const req = body => new Request('https://example.com/generate', { method: 'POST', headers: { 'CF-Connecting-IP': '1.2.3.4' }, body: JSON.stringify(body) });
const valid = { topic: 'Nấu ăn', count: 1, level: 'Nhớ', bilingual: false };

beforeEach(t => {
  t.mock.method(console, 'warn', () => {});
  t.mock.method(console, 'info', () => {});
});

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

const generatedCards = () => Response.json({ candidates: [{ finishReason: 'STOP', content: { parts: [{ text: JSON.stringify({ cards: [{ front: 'Câu hỏi', back: 'Đáp án' }] }) }] } }] });

function immediateRetries(t) {
  const delays = [];
  const originalSetTimeout = globalThis.setTimeout;
  t.mock.method(Math, 'random', () => 0);
  t.mock.method(globalThis, 'setTimeout', (callback, delay) => {
    delays.push(delay);
    return originalSetTimeout(callback, 0);
  });
  return delays;
}

test('recovers after two 503 responses with backoff and one shared timeout', async t => {
  const delays = immediateRetries(t);
  const calls = [];
  let rateLimitCalls = 0;
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    calls.push({ url, ...options });
    return calls.length < 3 ? new Response('private provider error test-key', { status: 503 }) : generatedCards();
  });
  const response = await worker.fetch(req(valid), {
    ...env,
    AI_LIMIT: { limit: async () => { rateLimitCalls++; return { success: true }; } },
  });
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).cards, [{ front: 'Câu hỏi', back: 'Đáp án' }]);
  assert.deepEqual(delays, [1000, 2000]);
  assert.equal(rateLimitCalls, 1);
  assert.equal(calls.length, 3);
  assert.ok(calls.every(call => call.signal === calls[0].signal && call.body === calls[0].body && call.url === calls[0].url));
});

test('stops after three attempts and reports transient provider failures safely', async t => {
  for (const status of [500, 502, 503, 504]) {
    await t.test(`HTTP ${status}`, async t => {
      const delays = immediateRetries(t);
      const mocked = t.mock.method(globalThis, 'fetch', async () => new Response('private provider error test-key', { status }));
      const response = await worker.fetch(req(valid), env);
      assert.equal(response.status, 502);
      assert.deepEqual(await response.json(), { error: 'provider_unavailable', providerStatus: status });
      assert.equal(mocked.mock.callCount(), 3);
      assert.deepEqual(delays, [1000, 2000]);
    });
  }
});

test('does not retry quota, credentials, model or request errors', async t => {
  for (const status of [400, 401, 403, 404, 429]) {
    await t.test(`HTTP ${status}`, async t => {
      const delays = immediateRetries(t);
      const mocked = t.mock.method(globalThis, 'fetch', async () => new Response('', { status }));
      const response = await worker.fetch(req(valid), env);
      assert.equal(response.status, status === 429 ? 429 : 502);
      assert.equal(mocked.mock.callCount(), 1);
      assert.deepEqual(delays, []);
    });
  }
});

test('respects Retry-After without extending the total timeout', async t => {
  for (const [retryAfter, expectedDelay] of [['5', 5000], ['invalid', 1000], ['60', 60000], ['120', null]]) {
    await t.test(`Retry-After: ${retryAfter}`, async t => {
      const delays = immediateRetries(t);
      let calls = 0;
      t.mock.method(globalThis, 'fetch', async () => ++calls === 1
        ? new Response('', { status: 503, headers: { 'Retry-After': retryAfter } })
        : generatedCards());
      const response = await worker.fetch(req(valid), env);
      assert.equal(response.status, expectedDelay === null ? 502 : 200);
      assert.equal(calls, expectedDelay === null ? 1 : 2);
      assert.deepEqual(delays, expectedDelay === null ? [] : [expectedDelay]);
    });
  }
});

test('aborts backoff when the shared 90 second deadline expires', async t => {
  const controller = new AbortController();
  t.mock.method(AbortSignal, 'timeout', timeout => {
    assert.equal(timeout, 90000);
    return controller.signal;
  });
  t.mock.method(globalThis, 'setTimeout', () => {
    queueMicrotask(() => controller.abort(new DOMException('deadline', 'TimeoutError')));
    return 0;
  });
  const mocked = t.mock.method(globalThis, 'fetch', async () => new Response('', { status: 503 }));
  const response = await worker.fetch(req(valid), env);
  assert.equal(response.status, 502);
  assert.deepEqual(await response.json(), { error: 'provider_timeout' });
  assert.equal(mocked.mock.callCount(), 1);
  const diagnostic = JSON.parse(console.warn.mock.calls.at(-1).arguments[0]);
  assert.equal(diagnostic.error, 'provider_timeout');
  assert.equal(diagnostic.exceptionType, 'TimeoutError');
  assert.equal(diagnostic.attempts.length, 1);
});

test('logs final provider status and all retries without private provider data', async t => {
  immediateRetries(t);
  t.mock.method(globalThis, 'fetch', async () => Response.json({
    error: { status: 'UNAVAILABLE', message: `private provider error test-key ${valid.topic}` },
  }, { status: 503 }));
  const response = await worker.fetch(req(valid), env);
  assert.equal(response.status, 502);
  assert.equal(console.warn.mock.callCount(), 1);
  const raw = console.warn.mock.calls[0].arguments[0];
  const diagnostic = JSON.parse(raw);
  assert.equal(diagnostic.event, 'ai_generation_failed');
  assert.equal(diagnostic.error, 'provider_unavailable');
  assert.equal(diagnostic.model, 'gemini-3.5-flash-lite');
  assert.equal(diagnostic.providerStatus, 503);
  assert.equal(diagnostic.providerCode, 'UNAVAILABLE');
  assert.deepEqual(diagnostic.attempts.map(attempt => attempt.providerStatus), [503, 503, 503]);
  assert.deepEqual(diagnostic.attempts.map(attempt => attempt.attempt), [1, 2, 3]);
  assert.ok(diagnostic.attempts.every(attempt => attempt.elapsedMs >= 0));
  for (const secret of ['test-key', valid.topic, 'private provider error']) assert.equal(raw.includes(secret), false);
});

test('logs network failures without logging exception messages', async t => {
  t.mock.method(globalThis, 'fetch', async () => { throw new TypeError(`test-key ${valid.topic}`); });
  const response = await worker.fetch(req(valid), env);
  assert.deepEqual(await response.json(), { error: 'provider_error' });
  const raw = console.warn.mock.calls[0].arguments[0];
  const diagnostic = JSON.parse(raw);
  assert.equal(diagnostic.stage, 'provider_request');
  assert.equal(diagnostic.exceptionType, 'TypeError');
  assert.equal(diagnostic.attempts.length, 1);
  assert.equal(raw.includes('test-key'), false);
  assert.equal(raw.includes(valid.topic), false);
});

test('distinguishes provider quota errors from the local rate limit in logs', async t => {
  t.mock.method(globalThis, 'fetch', async () => new Response('', { status: 429 }));
  assert.equal((await worker.fetch(req(valid), env)).status, 429);
  const diagnostic = JSON.parse(console.warn.mock.calls[0].arguments[0]);
  assert.equal(diagnostic.error, 'rate_limited');
  assert.deepEqual(diagnostic.attempts.map(attempt => attempt.providerStatus), [429]);
  assert.equal((await worker.fetch(req(valid), { ...env, AI_LIMIT: { limit: async () => ({ success: false }) } })).status, 429);
  assert.equal(console.warn.mock.callCount(), 1);
});

test('uses the configured model and preserves structured bilingual output', async t => {
  const cards = [{ front: 'Câu hỏi', back: 'Đáp án', frontEn: 'Question', backEn: 'Answer' }];
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    assert.equal(url, 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent');
    const format = JSON.parse(options.body).generationConfig.responseFormat.text;
    assert.equal(format.mimeType, 'APPLICATION_JSON');
    assert.deepEqual(format.schema.properties.cards.items.required, ['front', 'back', 'frontEn', 'backEn']);
    return Response.json({ candidates: [{ finishReason: 'STOP', content: { parts: [{ text: JSON.stringify({ cards }) }] } }] });
  });
  const response = await worker.fetch(req({ ...valid, bilingual: true }), { ...env, GEMINI_MODEL: 'gemini-3.1-flash-lite' });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { cards });
});

const fallbackEnv = { ...env, GROQ_API_KEY: 'groq-test-key' };
const groqCards = cards => Response.json({ choices: [{ finish_reason: 'stop', message: { content: JSON.stringify({ cards }) } }] });

test('keeps Gemini as primary when Groq is configured', async t => {
  const mocked = t.mock.method(globalThis, 'fetch', async url => {
    assert.ok(url.startsWith('https://generativelanguage.googleapis.com/'));
    return generatedCards();
  });
  assert.equal((await worker.fetch(req(valid), fallbackEnv)).status, 200);
  assert.equal(mocked.mock.callCount(), 1);
  assert.equal(console.warn.mock.callCount(), 0);
});

test('falls back after Gemini 503 retries and validates bilingual cards privately', async t => {
  immediateRetries(t);
  const cards = [
    { front: 'Câu 1', back: 'Đáp án 1', frontEn: 'Question 1', backEn: 'Answer 1' },
    { front: 'Câu 2', back: 'Đáp án 2', frontEn: 'Question 2', backEn: 'Answer 2' },
  ];
  let geminiCalls = 0;
  let groqCalls = 0;
  let rateLimitCalls = 0;
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    if (url.startsWith('https://generativelanguage.googleapis.com/')) {
      geminiCalls++;
      assert.equal(options.headers.Authorization, undefined);
      return new Response('private test-key provider error', { status: 503 });
    }
    groqCalls++;
    assert.equal(url, 'https://api.groq.com/openai/v1/chat/completions');
    assert.equal(options.headers.Authorization, 'Bearer groq-test-key');
    assert.equal(options.headers['x-goog-api-key'], undefined);
    const body = JSON.parse(options.body);
    assert.equal(body.model, 'openai/gpt-oss-120b');
    assert.equal(body.reasoning_effort, 'low');
    assert.ok(body.max_completion_tokens <= 6000);
    const format = body.response_format;
    assert.equal(format.type, 'json_schema');
    assert.equal(format.json_schema.strict, true);
    assert.equal(format.json_schema.schema.additionalProperties, false);
    const items = format.json_schema.schema.properties.cards.items;
    assert.equal(items.additionalProperties, false);
    assert.deepEqual(items.required, ['front', 'back', 'frontEn', 'backEn']);
    return groqCards(cards);
  });
  const response = await worker.fetch(req({ ...valid, count: 2, bilingual: true }), {
    ...fallbackEnv, AI_LIMIT: { limit: async () => { rateLimitCalls++; return { success: true }; } },
  });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { cards });
  assert.equal(geminiCalls, 3);
  assert.equal(groqCalls, 1);
  assert.equal(rateLimitCalls, 1);
  assert.equal(JSON.parse(console.warn.mock.calls[0].arguments[0]).event, 'ai_fallback_started');
  const success = JSON.parse(console.info.mock.calls[0].arguments[0]);
  assert.equal(success.event, 'ai_fallback_succeeded');
  assert.deepEqual(success.attempts.map(attempt => attempt.provider), ['gemini', 'gemini', 'gemini', 'groq']);
  const output = JSON.stringify([...console.warn.mock.calls, ...console.info.mock.calls]);
  for (const secret of ['groq-test-key', 'test-key', valid.topic, 'Đáp án 1', 'private']) assert.equal(output.includes(secret), false);
});

test('reserves time for Groq when Gemini uses its entire 55 second budget', async t => {
  const primary = new AbortController();
  const secondary = new AbortController();
  const timeouts = [];
  let elapsed = 0;
  t.mock.method(Date, 'now', () => 100000 + elapsed);
  t.mock.method(AbortSignal, 'timeout', timeout => {
    timeouts.push(timeout);
    return timeouts.length === 1 ? primary.signal : secondary.signal;
  });
  t.mock.method(globalThis, 'fetch', async url => {
    if (url.includes('googleapis.com')) {
      elapsed = 55000;
      primary.abort(new DOMException('private timeout message', 'TimeoutError'));
      throw primary.signal.reason;
    }
    return groqCards([{ front: 'Question', back: 'Answer' }]);
  });
  const response = await worker.fetch(req(valid), fallbackEnv);
  assert.equal(response.status, 200);
  assert.deepEqual(timeouts, [55000, 35000]);
  assert.equal(JSON.parse(console.warn.mock.calls[0].arguments[0]).reason, 'provider_timeout');
});

test('caps both providers at one shared 90 second deadline', async t => {
  const primary = new AbortController();
  const secondary = new AbortController();
  const timeouts = [];
  let elapsed = 0;
  t.mock.method(Date, 'now', () => 100000 + elapsed);
  t.mock.method(AbortSignal, 'timeout', timeout => {
    timeouts.push(timeout);
    return timeouts.length === 1 ? primary.signal : secondary.signal;
  });
  const mocked = t.mock.method(globalThis, 'fetch', async url => {
    elapsed = url.includes('googleapis.com') ? 55000 : 90000;
    const controller = url.includes('googleapis.com') ? primary : secondary;
    controller.abort(new DOMException('deadline', 'TimeoutError'));
    throw controller.signal.reason;
  });
  const response = await worker.fetch(req(valid), fallbackEnv);
  assert.deepEqual(await response.json(), { error: 'provider_timeout' });
  assert.deepEqual(timeouts, [55000, 35000]);
  assert.equal(mocked.mock.callCount(), 2);
  const diagnostic = JSON.parse(console.warn.mock.calls.at(-1).arguments[0]);
  assert.equal(diagnostic.provider, 'groq');
  assert.equal(diagnostic.elapsedMs, 90000);
});

test('uses Groq for Gemini quota or network errors', async t => {
  for (const failure of ['quota', 'network']) {
    await t.test(failure, async t => {
      const mocked = t.mock.method(globalThis, 'fetch', async url => {
        if (url.includes('googleapis.com')) {
          if (failure === 'network') throw new TypeError('private test-key');
          return new Response('', { status: 429 });
        }
        return groqCards([{ front: 'Question', back: 'Answer' }]);
      });
      assert.equal((await worker.fetch(req(valid), fallbackEnv)).status, 200);
      assert.equal(mocked.mock.callCount(), 2);
    });
  }
});

test('uses Groq when the Gemini response stream disconnects after HTTP 200', async t => {
  const mocked = t.mock.method(globalThis, 'fetch', async url => {
    if (url.includes('googleapis.com')) {
      return new Response(new ReadableStream({
        start(controller) { controller.error(new TypeError('private network error test-key')); },
      }), { status: 200, headers: { 'Content-Type': 'application/json' } });
    }
    return groqCards([{ front: 'Question', back: 'Answer' }]);
  });
  const response = await worker.fetch(req(valid), fallbackEnv);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { cards: [{ front: 'Question', back: 'Answer' }] });
  assert.equal(mocked.mock.callCount(), 2);
  assert.equal(JSON.parse(console.warn.mock.calls[0].arguments[0]).reason, 'provider_error');
  assert.equal(JSON.stringify(console.warn.mock.calls).includes('private network error'), false);
});

test('rejects malformed Gemini JSON structures without treating them as network failures', async t => {
  for (const body of [null, {}, { candidates: [{ finishReason: 'STOP', content: { parts: {} } }] }]) {
    await t.test(JSON.stringify(body), async t => {
      const mocked = t.mock.method(globalThis, 'fetch', async url => {
        assert.ok(url.includes('googleapis.com'));
        return Response.json(body);
      });
      const response = await worker.fetch(req(valid), fallbackEnv);
      assert.equal(response.status, 502);
      assert.deepEqual(await response.json(), { error: 'invalid_response' });
      assert.equal(mocked.mock.callCount(), 1);
    });
  }
});

test('does not use Groq to bypass input, credentials, model or safety failures', async t => {
  const cases = [
    ['request', () => new Response('', { status: 400 })],
    ['key', () => new Response('', { status: 401 })],
    ['access', () => new Response('', { status: 403 })],
    ['model', () => new Response('', { status: 404 })],
    ['safety', () => Response.json({ candidates: [{ finishReason: 'SAFETY' }] })],
    ['invalid_json', () => Response.json({ candidates: [{ finishReason: 'STOP', content: { parts: [{ text: 'invalid' }] } }] })],
  ];
  for (const [name, response] of cases) {
    await t.test(name, async t => {
      const mocked = t.mock.method(globalThis, 'fetch', async url => {
        assert.ok(url.includes('googleapis.com'));
        return response();
      });
      assert.equal((await worker.fetch(req(valid), fallbackEnv)).status, 502);
      assert.equal(mocked.mock.callCount(), 1);
    });
  }
});

test('enforces the local rate limit and validation before either provider', async t => {
  const mocked = t.mock.method(globalThis, 'fetch', async () => { throw new Error('unexpected provider call'); });
  assert.equal((await worker.fetch(req(valid), { ...fallbackEnv, AI_LIMIT: { limit: async () => ({ success: false }) } })).status, 429);
  assert.equal((await worker.fetch(req({ ...valid, count: 11 }), fallbackEnv)).status, 400);
  assert.equal(mocked.mock.callCount(), 0);
});

test('bounds Groq failures and returns generic errors without provider secrets', async t => {
  for (const status of [400, 401, 403, 429, 503]) {
    await t.test(`Groq HTTP ${status}`, async t => {
      const mocked = t.mock.method(globalThis, 'fetch', async url => new Response('private groq-test-key', { status: url.includes('googleapis.com') ? 429 : status }));
      const response = await worker.fetch(req(valid), fallbackEnv);
      assert.equal(response.status, status === 429 ? 429 : 502);
      const body = await response.json();
      assert.equal(body.error, status === 429 ? 'rate_limited' : 'providers_unavailable');
      assert.equal(mocked.mock.callCount(), 2);
      const diagnostic = JSON.parse(console.warn.mock.calls.at(-1).arguments[0]);
      assert.equal(diagnostic.provider, 'groq');
      assert.equal(JSON.stringify(body).includes('groq-test-key'), false);
      assert.equal(JSON.stringify(console.warn.mock.calls).includes('groq-test-key'), false);
    });
  }
});

test('validates Groq card count, translations, JSON and completion status', async t => {
  const cases = [
    ['count', () => groqCards([])],
    ['translations', () => groqCards([{ front: 'Question', back: 'Answer' }])],
    ['empty', () => groqCards([{ front: ' ', back: 'Answer', frontEn: 'Question', backEn: 'Answer' }])],
    ['json', () => Response.json({ choices: [{ finish_reason: 'stop', message: { content: 'invalid JSON' } }] })],
    ['null', () => Response.json({ choices: [{ finish_reason: 'stop', message: { content: 'null' } }] })],
    ['truncated', () => Response.json({ choices: [{ finish_reason: 'length', message: { content: '{}' } }] })],
    ['refusal', () => Response.json({ choices: [{ finish_reason: 'stop', message: { refusal: 'refused', content: '{}' } }] })],
  ];
  for (const [name, response] of cases) {
    await t.test(name, async t => {
      t.mock.method(globalThis, 'fetch', async url => url.includes('googleapis.com') ? new Response('', { status: 429 }) : response());
      const result = await worker.fetch(req({ ...valid, bilingual: true }), fallbackEnv);
      assert.equal(result.status, 502);
      assert.equal((await result.json()).error, 'providers_unavailable');
      assert.equal(JSON.parse(console.warn.mock.calls.at(-1).arguments[0]).error, 'invalid_response');
    });
  }
});
