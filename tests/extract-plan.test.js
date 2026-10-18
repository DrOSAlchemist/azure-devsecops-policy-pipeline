import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const script = new URL('../scripts/extract-plan.js', import.meta.url);
const plan = { resource_changes: [{ address: 'mock.example' }] };
const event = JSON.stringify({ type: 'test_plan', test_plan: plan });

function extract(text, { existing = false } = {}) {
  const directory = mkdtempSync(join(tmpdir(), 'devsecops-plan-test-'));
  const input = join(directory, 'events.jsonl');
  const output = join(directory, 'plan.json');
  try {
    writeFileSync(input, text);
    if (existing) writeFileSync(output, 'existing evidence');
    const result = spawnSync(process.execPath, [script.pathname, input, output], { encoding: 'utf8' });
    return { ...result, output: result.status === 0 || existing ? readFileSync(output, 'utf8') : null };
  } finally {
    rmSync(directory, { recursive: true });
  }
}

test('extracts exactly one nonempty mock plan from the event stream', () => {
  const result = extract(`${JSON.stringify({ type: 'test_summary' })}\n${event}\n`);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.output), plan);
});

test('rejects missing, duplicate, malformed and empty plans', () => {
  for (const input of [
    '', 'not json', '{}', `${event}\n${event}`,
    JSON.stringify({ type: 'test_plan', test_plan: {} }),
    JSON.stringify({ type: 'test_plan', test_plan: { resource_changes: [] } }),
  ]) {
    const result = extract(input);
    assert.notEqual(result.status, 0);
    assert.ok(result.stderr);
    assert.equal(result.output, null);
  }
});

test('refuses to overwrite prior evidence', () => {
  const result = extract(event, { existing: true });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /EEXIST/);
  assert.equal(result.output, 'existing evidence');
});
