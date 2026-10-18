import { test } from 'node:test';
import assert from 'node:assert/strict';
import { request } from 'node:http';
import { makeServer, parsePort } from '../src/server.js';
import { controls } from '../src/controls.js';

async function withServer(options, run) {
  const server = makeServer(options);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    await run(`http://127.0.0.1:${server.address().port}`);
  } finally {
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
  }
}

test('health endpoint is minimal and sends security headers', async () => {
  await withServer({}, async (base) => {
    const response = await fetch(`${base}/healthz`);
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { status: 'ok' });
    assert.equal(response.headers.get('x-content-type-options'), 'nosniff');
    assert.match(response.headers.get('content-security-policy'), /frame-ancestors 'none'/);
    assert.equal(response.headers.get('cache-control'), 'no-store');
  });
});

test('home page describes boundaries, not fabricated cloud evidence', async () => {
  await withServer({}, async (base) => {
    const response = await fetch(base);
    assert.equal(response.status, 200);
    assert.match(await response.text(), /No Azure subscription/);
    const css = await fetch(`${base}/style.css`);
    assert.equal(css.status, 200);
    assert.match(css.headers.get('content-type'), /text\/css/);
  });
});

test('controls expose every implemented integration with explicit limitations', async () => {
  await withServer({}, async (base) => {
    const response = await fetch(`${base}/api/controls`);
    const data = await response.json();
    assert.equal(data.cloudDeployed, false);
    assert.equal(data.controls.length, 6);
    assert.deepEqual(data.controls, controls);
    assert.ok(data.controls.every((item) => item.boundary));
  });
});

test('HEAD and query strings work without returning a body', async () => {
  await withServer({}, async (base) => {
    const response = await fetch(`${base}/?test=1`, { method: 'HEAD' });
    assert.equal(response.status, 200);
    assert.equal(await response.text(), '');
  });
});

test('mutation methods cannot change state', async () => {
  await withServer({}, async (base) => {
    for (const method of ['POST', 'PUT', 'DELETE', 'PATCH']) {
      const response = await fetch(`${base}/api/controls`, { method });
      assert.equal(response.status, 405);
      assert.equal(response.headers.get('allow'), 'GET, HEAD');
    }
  });
});

test('unknown routes, encoded paths and raw traversal never read arbitrary files', async () => {
  await withServer({}, async (base) => {
    for (const path of ['/missing', '/%2e%2e/package.json', '/../package.json', '/src/server.js']) {
      const status = await new Promise((resolve, reject) => {
        request(base, { path }, (response) => {
          response.resume();
          response.on('end', () => resolve(response.statusCode));
        }).on('error', reject).end();
      });
      assert.equal(status, 404);
    }
  });
});

test('asset failures log the error and return a real failure', async () => {
  const errors = [];
  await withServer({ assets: new URL('file:///missing-devsecops-test-directory/'), logger: { error: (...args) => errors.push(args) } }, async (base) => {
    const response = await fetch(base);
    assert.equal(response.status, 500);
    assert.deepEqual(await response.json(), { error: 'asset unavailable' });
    assert.equal(errors.length, 1);
  });
});

test('port validation rejects malformed or out-of-range configuration', () => {
  assert.equal(parsePort(), 8080);
  assert.equal(parsePort('3000'), 3000);
  for (const value of ['0', '-1', '65536', '8080oops', '', '1.5']) {
    assert.throws(() => parsePort(value), /PORT/);
  }
});
