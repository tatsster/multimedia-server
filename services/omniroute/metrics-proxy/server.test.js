'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  dropPrivileges,
  loadJwtSecret,
  makeDashboardJwt,
  prepareRuntime,
} = require('./server');

test('loads and trims JWT_SECRET before runtime starts', () => {
  const secret = loadJwtSecret('/secret.env', () => 'OTHER=x\nJWT_SECRET=  secret-value  \n');
  assert.equal(secret, 'secret-value');
});

test('fails when secret file cannot be read', () => {
  const denied = Object.assign(new Error('permission denied'), { code: 'EACCES' });
  assert.throws(() => loadJwtSecret('/secret.env', () => { throw denied; }), /EACCES.*\/secret\.env/);
});

test('fails when JWT_SECRET is missing', () => {
  assert.throws(() => loadJwtSecret('/secret.env', () => 'OTHER=x\n'), /JWT_SECRET missing/);
});

test('reads secret before dropping privileges', () => {
  const calls = [];
  const secret = prepareRuntime({
    loadSecret: () => { calls.push('read'); return 'secret'; },
    drop: () => calls.push('drop'),
  });
  assert.equal(secret, 'secret');
  assert.deepEqual(calls, ['read', 'drop']);
});

test('drops supplementary groups, group, then user and verifies ids', () => {
  const calls = [];
  let uid = 0;
  let gid = 0;
  const proc = {
    getuid: () => uid,
    getgid: () => gid,
    setgroups: (value) => calls.push(`groups:${value.join(',')}`),
    setgid: (value) => { calls.push(`gid:${value}`); gid = value; },
    setuid: (value) => { calls.push(`uid:${value}`); uid = value; },
  };
  dropPrivileges(proc, 1000, 1000);
  assert.deepEqual(calls, ['groups:', 'gid:1000', 'uid:1000']);
  assert.equal(proc.getuid(), 1000);
  assert.equal(proc.getgid(), 1000);
});

test('creates HS256 JWT from preloaded secret', () => {
  const token = makeDashboardJwt('secret-value');
  const parts = token.split('.');
  assert.equal(parts.length, 3);
  const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
  assert.equal(payload.authenticated, true);
  assert.ok(payload.exp > payload.iat);
});
