# topoi-01-ingest

Status: **closed** (plan accepted 2026-10-01, accepted and squash-merged 2026-10-01) · branch `topoi-01-ingest` · opened 2026-10-01

## Goal

A video goes in, normalized turns come out. Pipeline stages 1–2 (PRD §8): submit a YouTube or TikTok URL or paste a transcript, transcribe once through ElevenLabs, and build turns with the §9.1 rules. No LLM, no Airo.

Done when an admin can submit `BUm39a7diTU` at `/admin/debates`, the video is transcribed once, and its turns are stored and visible, and when the four gold samples normalize under test.

## Slices

| # | slice | acceptance |
|---|---|---|
| 1 | **Foundations**: Oban, Cloak vault, pgvector extension, settings singletons | Oban queues `ingest` (2) and `normalize` (1) run in dev; `Topoi.Settings` reads/writes singleton rows; Cloak-encrypted binary type in place; tests use `testing: :manual` |
| 2 | **Integration settings**: ElevenLabs key in an encrypted settings row, edited at `/admin/settings` | key saved encrypted, never rendered back (masked); dev seed copies the key from `config/dev.secret.exs` once; overview shows real state from the row |
| 3 | **Schema**: `debaters` (minimal), `videos`, `video_debaters`, `transcripts`, `transcript_words`, `turns`, `participants` (raw labels only) | migrations with binary ids; unique `(platform, platform_video_id)`; one live transcript per video (partial unique index); changesets tested |
| 4 | **Canonical URLs**: `Ingest.Canonicalize` | every YouTube form (watch, youtu.be, m./music., shorts, live, embed, tracking params) and TikTok video URL maps to `(platform, id)` + canonical URL; TikTok short links resolved via one redirect (stubbed in tests); unknown URLs rejected with a message |
| 5 | **Metadata**: `Topoi.Metadata` via oEmbed | title, channel, channel URL, thumbnail stored for YouTube and TikTok; TikTok `published_at` derived from the id; Req.Test stubs, no network in tests |
| 6 | **Parsers**: ElevenLabs JSON → `transcript_words`; SRT / `[Speaker N]` paste → segments → words | parses on block start; asserts segments == speaker tags; final block kept (§9.1 rule 6); tested on the stored `BUm39a7diTU` JSON and the four samples (tests skip when local files are absent) |
| 7 | **Normalize**: `Transcripts.Normalize` writes `turns` | merge / backchannel / bridge / interrupted rules read from settings; re-measures `xh9D0oLxwQg` (settles 941 vs 942) and records the numbers in PRD §9.1 |
| 8 | **ElevenLabs client + ingest worker** | `Topoi.Transcripts.ElevenLabs` sends the §8.2 parameters incl. keyterms from expected debaters; synchronous with 10-min timeout; upstream-download 400 retried with backoff; submit is idempotent (unique index + Oban unique job): a second submit of the same video makes no call |
| 9 | **Admin ingest UI**: `/admin/debates` | submit URL with expected debaters and extra keyterms, or paste a transcript; list of videos with per-stage status (ingest, normalize); video detail shows turn counts and the first turns |
| 10 | **Close-out** | `mix precommit` green; lint clean; one real end-to-end run on `BUm39a7diTU`; PRD and this doc updated |

## Out of scope

Participant naming and Gate A (stage 3), anything that calls Airo, the `/admin/gateway` form, public debate pages, YouTube Data API.

## Risks

- ElevenLabs YouTube download fails intermittently (seen once on 2026-10-01); covered by retries in slice 8.
- Sample-based tests depend on gitignored files; they run locally and skip elsewhere.

## Close-out

**Shipped (slices 1–10).** `mix precommit` green (205 tests), `mix joby_kit.lint` clean.

| # | slice | result |
|---|---|---|
| 1 | Foundations | Oban (`ingest` 2, `normalize` 1), Cloak vault (dev key in gitignored `config/dev.secret.exs`, `CLOAK_KEY` in prod), pgvector extension, `Topoi.Settings` singletons with a database-enforced single row |
| 2 | Integration settings | ElevenLabs key encrypted at rest, write-only at `/admin/settings` (never rendered back); pipeline thresholds editable on the same page |
| 3 | Schema | debaters, videos, video_debaters, transcripts, transcript_words, turns, participants; unique `(platform, platform_video_id)`; one live transcript per video |
| 4 | Canonical URLs | 13 YouTube forms, TikTok video and short links (one redirect), plain-word rejections |
| 5 | Metadata | oEmbed title, channel, thumbnail; TikTok `published_at` from the id |
| 6 | Parsers | ElevenLabs JSON and SRT paste to one word shape; block-start parsing with the segments == tags assertion holds on all four samples |
| 7 | Normalize | rules from settings; sample measurements recorded in PRD §9.1 |
| 8 | Client + workers | §8.2 parameters with keyterms, synchronous call, transient-download retry with backoff, permanent failures stop with the message; submit is idempotent |
| 9 | Admin ingest UI | `/admin/debates` (link or paste, live status), `/admin/debates/:id` (details, counts, first turns), `/admin/debaters` |
| 10 | Close-out | end-to-end runs below |

**End-to-end runs (2026-10-01, dev).**

- `BUm39a7diTU` (89.5 min): the response paid for in the first API test was imported with `Ingest.import_elevenlabs/3`, not transcribed again. 18,216 tokens (18,196 words + 20 audio events) → 161 substantive, 122 backchannel turns, through the real Oban queue.
- `UaC-gqcT7JI` (18.6 min): one real call through `/admin/debates`' path with the expected debater's keyterms. Accepted on the first attempt (keyterms as repeated multipart fields work). 3,773 words → 61 substantive, 58 backchannel turns (the hand SRT gave 63 / 43; word-level timings change backchannel counts). "actus purus" transcribed correctly three times.

**Measurements.** The sizing probe's 941 segments were 942 (it dropped the final block); normalization gives 891 / 254 / 518 on `xh9D0oLxwQg`. The 2-turn difference from the probe is one audio-only `[laughs]` segment, which is not a turn. Full table in PRD §9.1.

**Moved / added during the sprint.**

- Added `/admin/debaters` (slice 9): expected debaters need records to choose from.
- Added `Ingest.import_elevenlabs/3` (slice 10): store a response obtained outside the app without paying for it twice.
- Review fixes after the visual pass: admin column left-aligned, expected debaters as a checkbox group (new `checkbox_group` composite), small-radius checkboxes (round ones read as radio buttons), status badge and timecode chip layout.

**Follow-ups.**

- Run `mix run priv/repo/seeds.exs` to create the admin user (no users exist yet in dev).
- Bridged-turn text filters by speaker within the word range; revisit if stage 4 needs exact spans.
- YouTube `published_at` is empty for both videos until Gate A (stage 3) or a Data API key.
- Backchannel rule needs a `?`; ASR often ends spoken questions with a full stop ("Uh, so you're an atheist." at 0:21 in `UaC-gqcT7JI`). Review against the gold set; a following reply may be a better second signal.
