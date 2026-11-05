export type Release = { version: string; date: string; items: string[] }

// Parses "## 2.10.1+30 — 2026-11-05" headings and their "- " bullets.
export function parseChangelog(md: string): Release[] {
  const releases: Release[] = []
  for (const line of md.split(/\r?\n/)) {
    const h = line.match(/^##\s+([\d.]+)(?:\+\d+)?\s*[—-]?\s*(.*)$/)
    if (h) releases.push({ version: h[1], date: h[2].trim(), items: [] })
    else if (line.startsWith('- ') && releases.length) releases.at(-1)!.items.push(line.slice(2).trim())
  }
  return releases
}
