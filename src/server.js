import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { controls } from './controls.js';

const headers = {
  'Content-Security-Policy': "default-src 'none'; style-src 'self'; img-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'",
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
  'X-Frame-Options': 'DENY',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
  'Cache-Control': 'no-store',
};
const routes = new Map([
  ['/', ['index.html', 'text/html; charset=utf-8']],
  ['/style.css', ['style.css', 'text/css; charset=utf-8']],
]);

export function makeServer({ assets = new URL('../public/', import.meta.url), logger = console } = {}) {
  const server = createServer(async (request, response) => {
    const send = (status, body, contentType, extra = {}) => {
      response.writeHead(status, { ...headers, 'Content-Type': contentType, ...extra });
      response.end(request.method === 'HEAD' ? undefined : body);
    };
    if (!['GET', 'HEAD'].includes(request.method)) {
      request.resume();
      send(405, '{"error":"method not allowed"}', 'application/json', { Allow: 'GET, HEAD' });
      return;
    }
    // Exact allowlist: no decoding or user-controlled filesystem paths.
    const path = request.url?.split('?')[0];
    if (path === '/healthz') {
      send(200, '{"status":"ok"}', 'application/json');
    } else if (path === '/api/controls') {
      send(200, JSON.stringify({ mode: 'reference-implementation', cloudDeployed: false, controls }), 'application/json');
    } else if (routes.has(path)) {
      const [file, type] = routes.get(path);
      try {
        send(200, await readFile(new URL(file, assets)), type);
      } catch (error) {
        logger.error('Static asset read failed', { code: error.code });
        send(500, '{"error":"asset unavailable"}', 'application/json');
      }
    } else {
      send(404, '{"error":"not found"}', 'application/json');
    }
  });
  server.requestTimeout = 10_000;
  server.headersTimeout = 5_000;
  server.keepAliveTimeout = 5_000;
  server.maxHeadersCount = 50;
  return server;
}

export function parsePort(value = '8080') {
  if (!/^\d+$/.test(value) || Number(value) < 1 || Number(value) > 65535) {
    throw new Error('PORT must be an integer from 1 through 65535');
  }
  return Number(value);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const server = makeServer();
  server.on('error', (error) => {
    console.error('Server failed', { code: error.code });
    process.exitCode = 1;
  });
  server.listen(parsePort(process.env.PORT), '0.0.0.0', () => console.log('DevSecOps demo listening'));
  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.once(signal, () => {
      server.close();
      server.closeIdleConnections();
      const timer = setTimeout(() => process.exit(1), 10_000);
      timer.unref();
    });
  }
}
