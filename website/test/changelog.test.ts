import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { parseChangelog } from '../src/changelog.ts'

test('parses headings and bullets', () => {
  const r = parseChangelog('# Changelog\nintro\n## 2.10.1+30 — 2026-11-05\n- a\n- b\n\n## 1.0.0+1\n- c')
  assert.deepEqual(r, [
    { version: '2.10.1', date: '2026-11-05', items: ['a', 'b'] },
    { version: '1.0.0', date: '', items: ['c'] },
  ])
})

test('real CHANGELOG.md has releases with items', () => {
  const r = parseChangelog(readFileSync(new URL('../../CHANGELOG.md', import.meta.url), 'utf8'))
  assert.ok(r.length > 5)
  assert.ok(r.every((x) => x.items.length > 0))
})
