import type { Board, Session } from '../types'

export type Drawing = { source: string; width: number; height: number; alt: string }

type Tone = 'amb' | 'grn' | 'gry'
type Row = { session: Session; note: string }
type Header =
  | { kind: 'heading'; text: string; tone: Tone | 'muted' }
  | { kind: 'title'; text: string; note: string; session?: Session }

const PALETTE = ['#7F77DD', '#1D9E75', '#D85A30', '#378ADD', '#D4537E']
const AMBER = '#EF9F27'
const HEAD = 44
const ROW = 30
const FOOT = 10
const GAP = 14
const NAME_PX = 7.4
const TITLE_PX = 8.2
const NOTE_PX = 6.6

const TONE: Record<Session['state'], Tone> = { 'needs-you': 'amb', working: 'grn', idle: 'gry', unknown: 'gry' }
const PILL: Record<Session['state'], string> = { 'needs-you': 'needs you', working: 'working', idle: 'idle', unknown: '' }
const ICON: Record<Session['state'], string> = { 'needs-you': 'i-wait', working: 'i-work', idle: 'i-idle', unknown: 'i-unknown' }

const FONT = 'system-ui,-apple-system,"Segoe UI",sans-serif'
const STYLE = [
  ':root{--card:#FFFFFF;--line:#E6E4DD;--t1:#1F1E1D;--t2:#6B6A65;--amb:#8A5A00;--ambbg:#FCEFD6;--grn:#2F6B10;--grnbg:#E6F2D9;--gry:#6B6A65;--grybg:#F0EFEA}',
  '@media (prefers-color-scheme:dark){:root{--card:#262624;--line:#3A3936;--t1:#ECEAE4;--t2:#A3A19A;--amb:#F2B84B;--ambbg:#4A3613;--grn:#9FD46A;--grnbg:#23381A;--gry:#A3A19A;--grybg:#33322F}}',
  '.card{fill:var(--card);stroke:var(--line)}.rule{stroke:var(--line)}',
  `.h{font:600 11px ${FONT};letter-spacing:.07em;fill:var(--t2)}.title{font:600 14px ${FONT};fill:var(--t1)}`,
  `.n{font:500 13px ${FONT};fill:var(--t1)}.s{font:400 12px ${FONT};fill:var(--t2)}.p{font:500 11px ${FONT}}`,
  '.amb{fill:var(--amb)}.ambbg{fill:var(--ambbg)}.grn{fill:var(--grn)}.grnbg{fill:var(--grnbg)}.gry{fill:var(--gry)}.grybg{fill:var(--grybg)}',
].join('')
const DEFS = [
  '<g id="i-wait"><rect width="22" height="22" rx="6" class="ambbg"/><rect x="10" y="5" width="2.4" height="8" rx="1.2" class="amb"/><circle cx="11.2" cy="16.3" r="1.4" class="amb"/></g>',
  '<g id="i-work"><rect width="22" height="22" rx="6" class="grnbg"/><path d="M8.5 6.5 L15.5 11 L8.5 15.5 Z" class="grn"/></g>',
  '<g id="i-idle"><rect width="22" height="22" rx="6" class="grybg"/><rect x="7.5" y="7" width="2.4" height="8" rx="1" class="gry"/><rect x="12.1" y="7" width="2.4" height="8" rx="1" class="gry"/></g>',
  '<g id="i-unknown"><rect width="22" height="22" rx="6" class="grybg"/><text class="p gry" x="11" y="15" text-anchor="middle">?</text></g>',
].join('')

export const groupColor = (number: string): string =>
  PALETTE[Number(number) % PALETTE.length] ?? AMBER

const escape = (text: string) =>
  text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')

const fit = (text: string, px: number, charPx: number) => {
  const max = Math.floor(px / charPx)
  if (max <= 0) return ''
  return text.length <= max ? text : `${text.slice(0, Math.max(0, max - 1))}…`
}

const where = (session: Session) => (session.kind === 'interactive' ? 'this machine' : '')

function pill(session: Session | undefined, right: number, y: number): { svg: string; width: number } {
  if (session === undefined) return { svg: '', width: 0 }
  const label = PILL[session.state] || (session.isParsed ? session.status : '')
  if (label === '') return { svg: '', width: 0 }
  const tone = TONE[session.state]
  const width = Math.max(56, Math.round(label.length * NOTE_PX) + 24)
  const x = right - width
  return {
    width,
    svg:
      `<rect class="${tone}bg" x="${x}" y="${y}" width="${width}" height="20" rx="10"/>` +
      `<text class="p ${tone}" x="${x + width / 2}" y="${y + 14}" text-anchor="middle">${escape(label)}</text>`,
  }
}

function label(cls: string, text: string, note: string, room: number, px: number, gap: number): string {
  const shown = fit(text, room, px)
  const noteRoom = room - shown.length * px - gap
  const tail = shown === text && note !== '' ? fit(note, noteRoom, NOTE_PX) : ''
  const span = tail === '' ? '' : `<tspan class="s" dx="${gap}">${escape(tail)}</tspan>`
  return `${cls}>${escape(shown)}${span}</text>`
}

function row({ session, note }: Row, y: number, width: number): string {
  const tag = pill(session, width - 14, y + 5)
  const right = (tag.width === 0 ? width - 14 : width - 14 - tag.width) - 10
  return (
    `<use href="#${ICON[session.state]}" x="16" y="${y + 4}"/>` +
    label(`<text class="n" x="48" y="${y + 19}"`, session.name, note, right - 48, NAME_PX, 10) +
    tag.svg
  )
}

function card(y: number, width: number, header: Header, rows: Row[], accent?: string): { svg: string; height: number } {
  const height = rows.length === 0 ? HEAD : HEAD + rows.length * ROW + FOOT
  const parts = [`<rect class="card" x="0.5" y="${y + 0.5}" width="${width - 1}" height="${height - 1}" rx="12"/>`]
  if (accent !== undefined) {
    parts.push(`<rect x="0.5" y="${y + 12}" width="3" height="${height - 24}" rx="1.5" fill="${accent}"/>`)
  }
  if (header.kind === 'heading') {
    const tone = header.tone === 'muted' ? '' : ` ${header.tone}`
    parts.push(`<text class="h${tone}" x="18" y="${y + 26}">${escape(header.text)}</text>`)
  } else {
    const tag = pill(header.session, width - 14, y + 12)
    const right = (tag.width === 0 ? width - 14 : width - 14 - tag.width) - 10
    parts.push(label(`<text class="title" x="18" y="${y + 27}"`, header.text, header.note, right - 18, TITLE_PX, 8))
    parts.push(tag.svg)
    if (rows.length > 0) parts.push(`<line class="rule" x1="18" y1="${y + 40.5}" x2="${width - 14}" y2="${y + 40.5}"/>`)
  }
  rows.forEach((r, i) => parts.push(row(r, y + HEAD + i * ROW, width)))
  return { svg: parts.join(''), height }
}

export function drawBoard(board: Board, width: number): Drawing {
  const cards: string[] = []
  const alt: string[] = []
  let y = 0
  const add = (drawn: { svg: string; height: number }) => {
    cards.push(drawn.svg)
    y += drawn.height + GAP
  }

  if (board.needsYou.length > 0) {
    const rows = board.needsYou.map(({ session, pmName }) => ({ session, note: pmName ?? where(session) }))
    add(card(y, width, { kind: 'heading', text: 'NEEDS YOU', tone: 'amb' }, rows, AMBER))
    alt.push(`Needs you: ${board.needsYou.map(({ session }) => session.name).join(', ')}`)
  }
  for (const group of board.groups) {
    const [pm, ...morePms] = group.pms
    const rows = [
      ...morePms.map(session => ({ session, note: 'PM' })),
      ...group.workers.map(session => ({ session, note: where(session) })),
    ]
    const header: Header =
      pm === undefined
        ? { kind: 'title', text: group.number, note: 'no PM running' }
        : { kind: 'title', text: pm.name, note: where(pm), session: pm }
    add(card(y, width, header, rows, groupColor(group.number)))
    alt.push(`${header.text}: ${rows.map(r => `${r.session.name} ${PILL[r.session.state] || r.session.status}`).join(', ') || 'no workers'}`)
  }
  if (board.other.length > 0) {
    const rows = board.other.map(session => ({ session, note: where(session) }))
    add(card(y, width, { kind: 'heading', text: 'OTHER', tone: 'muted' }, rows))
    alt.push(`Other: ${board.other.map(session => session.name).join(', ')}`)
  }

  const height = Math.max(0, y - GAP)
  const source =
    `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">` +
    `<style>${STYLE}</style><defs>${DEFS}</defs>${cards.join('')}</svg>`
  return { source, width, height, alt: alt.join('. ') }
}
