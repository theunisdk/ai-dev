import { describe, expect, test } from 'claude-code/testing'

import { buildBoard, parseListing } from '../hooks/board'
import { drawBoard, groupColor } from '../hooks/svg'
import { LOCAL_ONLY, ONE_WAITING, TODAY } from './fixtures'

const draw = (listing: string, width = 380) => drawBoard(buildBoard(parseListing(listing)), width)

describe('drawBoard', () => {
  test('is one svg document of the given width', () => {
    const { source, width, height } = draw(TODAY)
    expect(source.startsWith('<svg xmlns="http://www.w3.org/2000/svg"')).toBe(true)
    expect(source.endsWith('</svg>')).toBe(true)
    expect(source).toContain(`viewBox="0 0 380 ${height}"`)
    expect(width).toBe(380)
    expect(height).toBeGreaterThan(0)
  })

  test('puts Needs you first, then a card per group titled by its PM, then Other', () => {
    const { source } = draw(TODAY)
    const at = (text: string) => source.indexOf(text)
    expect(at('NEEDS YOU')).toBeGreaterThan(-1)
    expect(at('class="title"')).toBeGreaterThan(at('NEEDS YOU'))
    expect(at('>meeting-pm-1774-security<')).toBeLessThan(at('>tektons-pm-9396-memebrdb<'))
    expect(at('>tektons-pm-9396-memebrdb<')).toBeLessThan(at('>serova-pm-5158-shane<'))
    expect(at('OTHER')).toBeGreaterThan(at('>serova-pm-5158-shane<'))
  })

  test('titles a group with no PM running by its number', () => {
    const { source } = draw(ONE_WAITING)
    expect(source).toContain('>9396<tspan class="s" dx="8">no PM running</tspan>')
  })

  test('names the PM beside a waiting worker and marks sessions on this machine', () => {
    const { source } = draw(TODAY, 480)
    expect(source).toContain('>zipauth-1774<tspan class="s" dx="10">meeting-pm-1774-security</tspan>')
    expect(draw(LOCAL_ONLY).source).toContain('>infrastructure-94<tspan class="s" dx="10">this machine</tspan>')
  })

  test('draws a status icon and pill per state', () => {
    const { source } = draw(TODAY)
    expect(source).toContain('href="#i-wait"')
    expect(source).toContain('href="#i-idle"')
    expect(source).toContain('>needs you</text>')
    expect(source).toContain('>idle</text>')
    const working = draw('  w-1234 [a1]  ·  Remote Control  ·  busy').source
    expect(working).toContain('href="#i-work"')
    expect(working).toContain('>working</text>')
  })

  test('shows an unknown state word as its pill and an unreadable row with no pill', () => {
    const unknown = draw('  w-1234 [a1]  ·  Remote Control  ·  compacting').source
    expect(unknown).toContain('href="#i-unknown"')
    expect(unknown).toContain('>compacting</text>')
    const unread = draw('  something the listing never said before').source
    expect(unread).toContain('>something the listing never said before<')
    expect(unread).not.toContain('rx="10"')
  })

  test('escapes names so they cannot break the markup', () => {
    const { source } = draw('  a<b&"c" [1]  ·  Remote Control  ·  idle')
    expect(source).toContain('a&lt;b&amp;&quot;c&quot;')
    expect(source).not.toContain('a<b')
  })

  test('cuts a name too long for the card with an ellipsis', () => {
    const long = `w-1234-${'x'.repeat(120)}`
    const { source } = draw(`  ${long} [a1]  ·  Remote Control  ·  idle`, 320)
    expect(source).not.toContain(long)
    expect(source).toContain('…')
  })

  test('colours each group card by its number, the same on every draw', () => {
    expect(groupColor('1774')).toBe(groupColor('1774'))
    expect(groupColor('1774')).not.toBe(groupColor('1775'))
    expect(draw(TODAY).source).toContain(`fill="${groupColor('1774')}"`)
  })

  test('stays under the Svg size limit with many sessions', () => {
    const rows = Array.from({ length: 150 }, (_, i) => `  worker-${i}-${1000 + (i % 7)} [a${i}]  ·  Remote Control  ·  busy`)
    expect(draw(`Peer sessions (150):\n${rows.join('\n')}`).source.length).toBeLessThan(131072)
  })
})
