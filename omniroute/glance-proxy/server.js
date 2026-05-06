#!/usr/bin/env node
'use strict';

const http = require('http');
const crypto = require('crypto');
const fs = require('fs');

const PORT = Number(process.env.PORT || process.env.OMNIROUTE_GLANCE_PROXY_PORT || 20129);
const HOST = process.env.HOST || process.env.OMNIROUTE_GLANCE_PROXY_HOST || '0.0.0.0';
const OMNIROUTE_URL = (process.env.OMNIROUTE_URL || 'http://127.0.0.1:20128').replace(/\/$/, '');
const SERVER_ENV = process.env.OMNIROUTE_SERVER_ENV || '/app/omniroute-data/server.env';
const GLANCE_TOKEN = process.env.OMNIROUTE_GLANCE_TOKEN || '';
const CACHE_SECONDS = Number(process.env.CACHE_SECONDS || process.env.OMNIROUTE_GLANCE_PROXY_CACHE_SECONDS || 60);
const TIMEOUT_MS = Number(process.env.TIMEOUT_MS || process.env.OMNIROUTE_GLANCE_PROXY_TIMEOUT_MS || 10000);

let cache = { expires: 0, body: null };

function json(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  });
  res.end(payload);
}

function readServerEnv(path) {
  const env = {};
  const text = fs.readFileSync(path, 'utf8');
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#') || !line.includes('=')) continue;
    const idx = line.indexOf('=');
    env[line.slice(0, idx)] = line.slice(idx + 1);
  }
  return env;
}

function b64url(value) {
  const input = Buffer.isBuffer(value) ? value : Buffer.from(JSON.stringify(value));
  return input.toString('base64url');
}

function makeDashboardJwt() {
  const secret = readServerEnv(SERVER_ENV).JWT_SECRET;
  if (!secret) throw new Error(`JWT_SECRET missing from ${SERVER_ENV}`);
  const now = Math.floor(Date.now() / 1000);
  const payload = { authenticated: true, iat: now, exp: now + 300 };
  const data = `${b64url({ alg: 'HS256', typ: 'JWT' })}.${b64url(payload)}`;
  const sig = crypto.createHmac('sha256', secret.trim()).update(data).digest('base64url');
  return `${data}.${sig}`;
}

function checkAuth(req) {
  if (!GLANCE_TOKEN) return true;
  const auth = req.headers.authorization || '';
  if (auth === `Bearer ${GLANCE_TOKEN}`) return true;
  if (req.headers['x-omniroute-glance-token'] === GLANCE_TOKEN) return true;
  return false;
}

async function fetchJson(url, headers = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const response = await fetch(url, { headers, signal: controller.signal });
    const text = await response.text();
    let body;
    try { body = text ? JSON.parse(text) : {}; } catch { body = { raw: text }; }
    if (!response.ok) {
      const message = body?.error?.message || body?.message || response.statusText;
      const error = new Error(message);
      error.status = response.status;
      error.body = body;
      throw error;
    }
    return body;
  } finally {
    clearTimeout(timer);
  }
}

function percent(numerator, denominator) {
  if (!denominator) return 0;
  return Number(((numerator / denominator) * 100).toFixed(2));
}

function simplifyAnalytics(analytics) {
  const s = analytics.summary || {};
  const promptTokens = Number(s.promptTokens || 0);
  const completionTokens = Number(s.completionTokens || 0);
  const cacheReadTokens = Number(s.cacheReadTokens || 0);
  const cacheCreationTokens = Number(s.cacheCreationTokens || 0);
  const totalTokens = Number(s.totalTokens || promptTokens + completionTokens || 0);
  const cacheHitRatePct = Number(s.cacheHitRatePct ?? percent(cacheReadTokens, promptTokens + cacheReadTokens));

  return {
    status: 'ok',
    range: analytics.range || null,
    summary: {
      totalRequests: Number(s.totalRequests || 0),
      promptTokens,
      completionTokens,
      totalTokens,
      cacheReadTokens,
      cacheCreationTokens,
      cacheHitRatePct,
      uniqueModels: Number(s.uniqueModels || 0),
      uniqueAccounts: Number(s.uniqueAccounts || 0),
      uniqueApiKeys: Number(s.uniqueApiKeys || 0),
      successfulRequests: Number(s.successfulRequests || 0),
      successRatePct: Number(s.successRatePct || 0),
      avgLatencyMs: Number(s.avgLatencyMs || 0),
      totalCost: Number(s.totalCost || 0),
      fallbackCount: Number(s.fallbackCount || 0),
      fallbackRatePct: Number(s.fallbackRatePct || 0),
      requestedModelCoveragePct: Number(s.requestedModelCoveragePct || 0),
      firstRequest: s.firstRequest || '',
      lastRequest: s.lastRequest || '',
      streak: Number(s.streak || 0),
    },
    topModels: analytics.topModels || analytics.models || [],
    dailyTrend: analytics.dailyTrend || [],
    updatedAt: new Date().toISOString(),
  };
}

async function getSummary(reqUrl) {
  const now = Date.now();
  if (cache.body && cache.expires > now) return cache.body;
  const range = new URL(reqUrl, 'http://local').searchParams.get('range') || '7d';
  const jwt = makeDashboardJwt();
  const analytics = await fetchJson(`${OMNIROUTE_URL}/api/usage/analytics?range=${encodeURIComponent(range)}`, {
    cookie: `auth_token=${jwt}`,
    accept: 'application/json',
  });
  const body = simplifyAnalytics(analytics);
  cache = { expires: now + CACHE_SECONDS * 1000, body };
  return body;
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

    if (url.pathname === '/health') return json(res, 200, { status: 'ok' });

    if (!checkAuth(req)) {
      return json(res, 401, { status: 'error', error: 'unauthorized' });
    }

    if (url.pathname === '/summary') {
      const body = await getSummary(req.url);
      return json(res, 200, body);
    }

    return json(res, 404, { status: 'error', error: 'not_found' });
  } catch (error) {
    console.error(`[proxy] ${error.message}`);
    return json(res, error.status || 500, {
      status: 'error',
      error: error.status ? 'omniroute_request_failed' : 'proxy_error',
      message: error.message,
    });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`[proxy] listening on ${HOST}:${PORT}; upstream=${OMNIROUTE_URL}; serverEnv=${SERVER_ENV}`);
});
