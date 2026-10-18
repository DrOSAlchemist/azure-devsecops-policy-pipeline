import { readFileSync, writeFileSync } from 'node:fs';

const [input, output] = process.argv.slice(2);
if (!input || !output) throw new Error('Usage: extract-plan.js TEST_EVENTS.jsonl PLAN.json');
const events = readFileSync(input, 'utf8').trim().split('\n').map((line) => JSON.parse(line));
const plans = events.filter((event) => event.type === 'test_plan').map((event) => event.test_plan);
if (plans.length !== 1 || !Array.isArray(plans[0]?.resource_changes) || !plans[0].resource_changes.length) {
  throw new Error('Expected exactly one non-empty mock-provider test plan; refusing empty policy input');
}
writeFileSync(output, JSON.stringify(plans[0], null, 2), { flag: 'wx' });
console.log(`Exported ${plans[0].resource_changes.length} mock resource changes; not a real Azure plan.`);
