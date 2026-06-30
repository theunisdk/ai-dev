---
name: humanize-writing
description: >-
  Edit existing prose to remove the stylistic tells that make text read as
  AI-generated — corporate verbs, em-dash overuse, formulaic structures, hollow
  balance, repetition, and absent voice — by judging each instance in context
  and fixing it appropriately rather than deleting it blindly. Use this whenever
  someone wants to make AI-written content sound more human, asks to remove "AI
  tells"/"AI slop"/"ChatGPT voice", wants to check whether a draft reads as
  machine-written, or asks to humanize, de-robotify, or revise any piece of
  writing. Trigger even when they just paste text and ask "does this sound like
  AI?" or "make this not sound like AI wrote it."
---

# Humanize Writing

This skill edits a piece of writing to strip the patterns that make it read as AI-generated, while keeping the author's meaning, argument, and intent intact.

## The one rule that governs everything

**Diagnose, don't delete.** Every tell below is a *flag to inspect*, never a thing to remove on sight. The same feature can be a tic in one piece and the correct choice in another. An em-dash is fine; an em-dash in every third sentence is a tell. "Leverage" is filler in a blog post and literal in a finance memo.

So for each flagged element, reach one of three verdicts:

1. **Keep it.** It genuinely serves the sentence here. Leave it alone.
2. **Swap it.** A direct substitution fixes it — different punctuation, a plainer word.
3. **Rewrite it.** The cleanest fix is to recast the sentence so the problem dissolves rather than gets patched.

A skill that only ever picks option 2 produces *scrubbed* text — mechanically de-tic'd, which reads as its own kind of robotic. The judgment between the three is the whole job.

## Hard guardrails — do not cross these

- **Never invent.** Do not add facts, statistics, quotes, names, dates, anecdotes, or personal experience to manufacture "voice" or "depth." If the piece is thin because it lacks real specifics, **flag that for the author** — don't paper over it with fabrication.
- **Never change the meaning.** Claims, conclusions, numbers, and the author's stance stay exactly as they are. If a more human rewrite would shift the meaning, pick the smaller fix or flag it instead.
- **Never fake humanity.** Do not insert deliberate typos, grammatical errors, or forced slang to "look human." That fools no one and degrades the writing.
- **Never trade one fancy word for another.** "Utilize" → "leverage" is not a fix. Get to the plain word that means the actual thing.

## Order of operations

Work top-down, because high-level fixes dissolve low-level ones for free. Restructuring a formulaic paragraph often removes three vocabulary and punctuation tells at once, so do it before hunting individual words.

1. **Profile the piece** (below) — you can't judge a tell without knowing the register.
2. **Structure and rhythm** — the formulaic scaffolding.
3. **Sentences** — repetition, sameness of length, hollow balance.
4. **Vocabulary** — the corporate/AI word list.
5. **Punctuation** — em-dashes and friends.
6. **Formatting** — gratuitous lists and subheads.
7. **Depth and voice** — the judgment-heavy assessment.
8. **Overcorrection check** — make sure you didn't create a new uniformity.
9. **Output** — revised text plus a short change log.

---

## Step 1 — Profile the piece before touching it

Read the whole thing and answer these privately. They decide what counts as a tell versus a legitimate choice:

- **Register and audience.** Technical doc, casual blog, marketing copy, academic, personal essay? A word that's filler in one is precise in another.
- **The author's actual voice.** Is there any signal of how this person writes — sentence rhythm, vocabulary, attitude? Preserve and amplify it. Where there's no signal, aim for plain, direct, slightly varied human prose. Do **not** impose a generic "breezy casual" voice; that's just a different AI default.
- **The real argument.** What is the piece actually trying to say, underneath the scaffolding? Often the fix is to strip the connective tissue and let that argument stand on its own.

## Step 2 — Structure and rhythm (the biggest lever)

These are the patterns readers clock fastest. Fix by cutting the scaffolding or restructuring — rarely by word-swap.

- **The fake-out turn:** "But here's the thing," "Here's the kicker," "And that's where it gets interesting." Usually the sentence works better with the throat-clearing deleted.
- **The lone "So" opener,** especially launching a near-the-end paragraph. Cut it or fold the sentence into the flow.
- **The "It's not [just] about X, it's about Y" construction.** A signature tell. Recast as a direct statement of what it *is* about.
- **Strawman-then-deny:** [introduce idea] → [raise a weak objection] → [knock it down]. If the objection isn't real, delete the whole detour and state the point.
- **Rhetorical question then answer:** "The result? More people are…" / "Why does this matter?" Turn it into a plain declarative sentence.
- **The tidy tricolon** — three parallel items, every time, often three adjectives. Vary it: drop to two, expand to a real clause, break the parallelism.
- **"In a world where…" / "In today's fast-paced…"** openers. Cut and start with something concrete.
- **The summary "So," "Ultimately," or "At the end of the day" closer** that restates what was already said. Often deletable.

## Step 3 — Sentences

- **Repetition of the same idea.** AI restates a point in fresh words a paragraph later, believing it's adding. Find these and consolidate to the single best phrasing.
- **Uniform sentence length.** A string of medium, evenly-built sentences reads mechanical. Vary deliberately — a short punchy one, then a longer one that earns its length. This single move does a lot of the "sounds human" work.
- **Hollow balance.** "While there are challenges, there are also opportunities." Over-hedged, both-sides-of-everything mush that commits to nothing. Where the piece clearly *has* a position, let it take the position. Where genuine balance is warranted, keep it — but make it specific, not reflexive.

## Step 4 — Vocabulary

The list below is a starting set of words AI over-reaches for. **They are flags, not banned words.** When one appears, ask: is it carrying precise, literal, or technical meaning here? If yes, keep it. If it's vague reach-for-impressive filler, find the plain word for what the sentence actually means.

Flag words (extend this list freely — the author is building their own):

> leverage, empower, facilitate, enable, enhance, drive, harness, showcase, incorporate, integrate, seamless, pivotal, navigate, delve, underscore, amplify, elevate, utilize, robust, foster, streamline, unlock, spearhead, cutting-edge, game-changer, testament, realm

Worn phrases and clichés to flag the same way:

> "delve into," "dive into," "a glimpse into," "stark," "in the realm of," "it's worth noting," "it's important to note," "that being said," "when it comes to," "the fact that," "navigate the complexities of," "in conclusion," "needless to say," "a wide range of," "plays a crucial role"

**How to fix:** replace with direct language, or cut entirely. The plain version is almost always shorter.

- "leverage our existing infrastructure to drive engagement" → "use what we've already built to get people more involved"
- *but* "the fund uses 3x leverage" → **keep** — that's the literal financial term.
- "this delves into the stark realities of…" → "this looks at the hard truth about…"

## Step 5 — Punctuation (em-dashes especially)

The em-dash itself is not the problem — plenty of strong human writers use it. The tell is **frequency and uniformity**: AI reaches for the em-dash as its default way to attach an aside, so they pile up at a density and rhythm no person sustains.

So don't strip them all (that's the scrubbed look again). Count them, assess the density, and resolve the surplus **one at a time**, choosing the option that fits each sentence:

- A **comma** if the aside is mild and flows.
- **Parentheses** if it's a genuine aside the sentence could skip.
- A **colon** if the second half explains or delivers the first.
- A **full stop / two sentences** if both halves can stand alone (often the strongest fix — it varies sentence length too).
- **Keep the em-dash** for the one or two places it genuinely lands hardest.

The goal is natural *variety*, not zero em-dashes.

**Example** — same sentence, three valid resolutions; pick by fit:
- Original: "The launch was delayed — the team needed more time — but nobody complained."
- Comma: "The launch was delayed, since the team needed more time, but nobody complained."
- Split: "The launch was delayed; the team needed more time. Nobody complained."
- Parens: "The launch was delayed (the team needed more time) but nobody complained."

Apply the same density check to other AI-favored punctuation: the **rhetorical-question-then-colon**, semicolon overuse, and chains of ellipses.

## Step 6 — Formatting

AI defaults to bullet lists and subheads even when prose is the right vessel. If the original is genuinely a sequence of discrete items, a list is correct — keep it. But where bullets are just chopped-up prose, or subheads are sprinkled over what is really one flowing argument, **collapse them back into paragraphs.** Connected reasoning reads more human as prose than as fragments.

## Step 7 — Depth and voice (the hard part — judgment required)

These can't be regexed, and they're where "sounds like AI" really lives:

- **Too perfect / surface-level.** The piece glides over everything at the same shallow altitude, with no concrete example, no specific number, no named thing, no actual tension. Where you *can* sharpen with specifics already implied by the text, do it. Where real depth would require knowledge the text doesn't contain — a genuine example, a lived detail, an actual data point — **flag it for the author** ("this paragraph stays general; a concrete example here would land it") rather than inventing one.
- **No voice / no stance.** Add a point of view where the piece is clearly hedging into neutrality but the author obviously has one. Commit to the claim. (Never manufacture an *opinion the author didn't express* — surface the one that's already implied, or flag the gap.)
- **No emotion or texture.** Vary rhythm, let a sentence be blunt, allow a slightly imperfect-but-natural turn of phrase. Subtle roughness is human; forced quirk is not.

## Step 8 — Overcorrection check

A piece scrubbed of *every* tell — zero em-dashes, every fancy word swapped, quirks bolted on — becomes its own tell: it reads as "someone trying very hard not to sound like AI." Re-read the result with fresh eyes:

- Did you leave the good sentences alone? You should have.
- Is the variety natural, or did you over-engineer it?
- Does it still sound like *this author* (or like plausible human prose), or like a new template?

Restraint is part of the craft. Change what's flagged; don't reflexively touch what already works.

## Step 9 — Output

Return two things:

**1. The revised text.** Clean, ready to use.

**2. A short change log** — for the author's control, not a wall of text. Cover:
- The main categories of change you made and why (e.g. "thinned out em-dashes, recast two 'it's not X it's Y' sentences, replaced corporate verbs in the intro").
- **Flagged for your judgment** — a brief list of things you deliberately did *not* fix because they need a human: paragraphs that are thin on real specifics, places a genuine example would help, claims you couldn't verify, anywhere a stance would strengthen the piece but you won't invent one.

Keep the change log itself plain and direct — don't let the explanation become the thing it's meant to fix.

---

## Worked mini-example

**Before:**
> In today's fast-paced digital landscape, leveraging AI to enhance your workflow isn't just about saving time — it's about unlocking your team's full potential. The result? More businesses are seamlessly integrating these powerful tools. But here's the thing: adoption requires careful planning.

**After:**
> AI can speed up your team's work, and it can do more than save time — handled well, it changes what a small team is able to take on. More businesses are adopting these tools, but doing it properly takes planning.

What changed and why: cut the "in today's fast-paced" opener and the "isn't just about X, it's about Y" frame; replaced "leveraging/enhance/unlocking/seamlessly integrating/powerful" with plain verbs; turned "The result?" into a declarative; deleted "But here's the thing"; kept a single em-dash where it earns the pause. Flagged for the author: the claim is still generic — one real before/after example from an actual team would give it the specificity it's missing.
