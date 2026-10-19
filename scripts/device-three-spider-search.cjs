// One-suit Spider search using the exposed ranks; hidden ranks remain unknown.
const fs = require('node:fs');
const initial = JSON.parse(fs.readFileSync(process.argv[2]));
const key = piles => piles.map(p => p.join(',')).sort().join('|');
const states = [], queue = [], seen = new Set();
function add(piles, parent, move, depth, reveal, completed) {
  const hash = key(piles); if (seen.has(hash)) return; seen.add(hash);
  let breaks = 0;
  for (const p of piles) for (let i = 1; i < p.length; i++) if (p[i] >= 0 && p[i - 1] >= 0 && p[i - 1] !== p[i] + 1) breaks++;
  const score = breaks * 3 - piles.filter(p => !p.length).length * 4 + depth * .3;
  const index = states.push({ piles, parent, move, depth, reveal, completed, score }) - 1;
  queue.push(index); let pos = queue.length - 1;
  while (pos) { const p = (pos - 1) >> 1; if (states[queue[p]].score <= score) break; queue[pos] = queue[p]; pos = p; } queue[pos] = index;
}
function pop() {
  const head = queue[0], tail = queue.pop();
  if (queue.length) { let pos = 0; while (pos * 2 + 1 < queue.length) { let j = pos * 2 + 1; if (j + 1 < queue.length && states[queue[j + 1]].score < states[queue[j]].score) j++; if (states[tail].score <= states[queue[j]].score) break; queue[pos] = queue[j]; pos = j; } queue[pos] = tail; }
  return head;
}
add(initial.piles, -1, null, 0, false, false); let goal = -1;
while (queue.length && states.length < 180000) {
  const parent = pop(), node = states[parent], piles = node.piles;
  if (node.reveal || node.completed || piles.every(p => !p.length)) { goal = parent; break; }
  for (let from = 0; from < 10; from++) {
    const pile = piles[from];
    for (let pos = pile.length - 1; pos >= 0 && pile[pos] >= 0; pos--) {
      if (pos < pile.length - 1 && pile[pos] !== pile[pos + 1] + 1) break;
      let emptyUsed = false;
      for (let to = 0; to < 10; to++) if (to !== from) {
        const dest = piles[to];
        if (!dest.length) { if (emptyUsed || !pos) continue; emptyUsed = true; }
        else if (dest.at(-1) !== pile[pos] + 1) continue;
        const next = piles.map(p => p.slice()); next[to].push(...next[from].splice(pos));
        let reveal = next[from].at(-1) === -1, completed = false;
        for (const p of next) if (p.length >= 13 && p.slice(-13).every((rank, i) => rank === 12 - i)) {
          p.splice(-13); completed = true; reveal ||= p.at(-1) === -1;
        }
        // Keep enough cards to fill ten columns before the next stock deal.
        if (initial.stock > 0 && next.reduce((n, pile) => n + pile.length, 0) < 10) continue;
        add(next, parent, { from, pos, to, rank: pile[pos] }, node.depth + 1, reveal, completed);
      }
    }
  }
}
const moves = [];
if (goal >= 0) for (let i = goal; states[i].parent >= 0; i = states[i].parent) moves.unshift(states[i].move);
process.stdout.write(JSON.stringify({ solved: goal >= 0, explored: states.length, moves, final: goal >= 0 ? states[goal].piles : null }));
