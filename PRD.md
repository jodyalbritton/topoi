# Topoi — PRD

Status: draft v0.4 · 2026-10-01 · owner: Jody

v0.4 consolidates v0.1–v0.3 (written across several sessions under the working title "Debate Dossier") into one current-state spec. Part I is the spec. Part II is the research log: tooling surveys, measurements, and superseded options, kept with their dates. When Part I and Part II disagree, Part I wins.

---

# Part I — Spec

## 1. Summary

Topoi is a **public atlas of how public debaters argue**. It ingests recorded public debates (YouTube, TikTok lives, pasted transcripts), tags every turn with a small closed move vocabulary, and publishes, per debater, the habitual moves: what they open with, how they counter, what pushback they avoid, and where every formulation of their argument ends up. Every published sentence cites a timestamped span of a public performance.

Behind the public site sits an admin layer for Jody: ingest, three human review gates, and a private counter library (short-circuits authored against a debater's arguments).

Public host: `topoi.gg`. Mix app `topoi`, OTP app `:topoi`, root module `Topoi`, web module `TopoiWeb`, repo `~/Work/topoi` (GitHub `jodyalbritton/topoi`).

## 2. Problem

Individual debaters run highly repetitive toolboxes (e.g. a Thomist who consistently sets the bar at the outset with the five ways). Counter-debaters who spot such a pattern and short-circuit it up front are noticeably more successful. Human memory tracks only the pushbacks one remembers giving; it cannot enumerate everything an opponent was ever offered and what happened next. No existing tool does this (Appendix A).

## 3. Scope

- **IS** a public, cited record of individual debaters' recurring habits, organized as an atlas: debaters, debates, topics (arguments), tags (moves and tactics), schools (traditions); see §3.1.
- **IS** a private prep layer: counters authored by Jody, attached to findings, admin-only (§13.2 item 9).
- **IS NOT** an opposition simulator — no persona simulation of Debater X.
- **IS NOT** a debate-outcome adjudicator — pattern-spotting, not win/loss scoring.
- **IS NOT** primarily a tactic taxonomy. The unit of analysis is the individual debater. Topic, tag, and school pages are cross-references over individual records; school-level patterns supply priors and stock counters.
- **Scope rule:** the record covers **public debate performances** only, and a page may state only what is observable in a cited performance. How a debater presents ideas is in scope — interruptions, deferrals, tone policing, replaying an opponent's word, status attacks — because it is on the record with a timestamp. Anything not sourced from a performance is out: appearance, private life, biography, and character verdicts ("is a liar") as opposed to observed conduct ("asserted X at 21:25, contradicted at 48:06"). **No biometrics:** no voice prints, speaker embeddings, or speaker-library matching of debaters, because debaters have not consented; identity comes only from what is said and shown on the record, confirmed by a human at Gate A. Enforcement is mechanical, not editorial: a statement with no span citation cannot be published (§6, §13.3).

### 3.1 Taxonomy: debaters, topics, tags, schools, positions

Each section answers one question, and a term lives in exactly one section: the one whose question it answers. Other forms of the word are aliases that resolve to it.

| section | answers | contains | examples |
|---|---|---|---|
| Debaters | What does this person do? | people, by handle | a debater's handle |
| Topics | What has been argued about this, by whom, and how did it go? | **what** is argued about: arguments, evidence and events, figures, texts | act and potency, the Five Ways, Fatima, Ayn Rand, Matthew 16, problem of evil |
| Tags | Who debates this way? | **how** someone debates: one-word, neutral style descriptors, each backed by counts | Socratic, syllogistic, citational, definitional, evidential, scriptural, deferring, interruptive, reframing, prepared, concessive |
| Schools | What does this tradition typically run, and what are its stock questions? | traditions a debater argues from | Thomism, materialism, naturalism, objectivism |
| Positions | (a filter, not a page) | the side a participant takes in one debate | theist, atheist, agnostic |

Rules:

- **Positions are not schools.** "Atheism" and "theism" are stances on a resolution, not traditions with a shared toolbox: an atheist may argue as a materialist, a naturalist, or an objectivist. Pooling all atheists into one school would make its base rates (§4) noise. A position is recorded **per participant per debate**, because a debater's side depends on the resolution. Positions filter lists; they have no pages.
- **Schools are traditions.** A debater may belong to several (a materialist is usually also a naturalist). Membership is suggested only from **self-identification on the record** ("I'm a Thomist", with its quote and timecode) and confirmed by a human, who confirms the citation, not the label (§6).
- **Tags are earned per performance; debates carry topics.** A tag is assigned to a participant's performance in one debate, from that performance's counts. A debater's tags are the roll-up across their confirmed performances, always shown with the count ("deferring in 3 of 4 debates"). A debate itself has no tags: it has the topics discussed in it, and each participant's performance tags appear in that participant's analysis on the debate page.
- **Tags are computed, never hand-assigned.** No one adds, removes, or edits a tag on a performance or a debater; that is where bias would enter. A human influences tags only by correcting the evidence (relabeling a move at Gate B, after which tags recompute) or by changing a tag's rule or threshold, which is logged and re-applied to every debater at once. Gate C publishes whatever the rules produce; it does not pick tags.
- **Tags are not moves.** Moves (§9.3: open, develop, challenge, defer, reframe, …) and tactics (burden-scope, knowledge check, …) are the analysis vocabulary: every turn is tagged with them and they appear inside debater and debate pages as evidence, not as a section. Tags are the public, one-word layer computed from them.
- **Tags are neutral and evidenced.** Descriptive words only, never verdicts ("reframing", not "evasive"; no "dishonest", "combative", "smug"; §3 scope rule). A tag is assigned only when its underlying rate crosses a threshold, and the tag shows the counts and timecodes behind it. The tag list is curated; the LLM never invents tags.
- **Tags describe how, never what or where.** "Thomist" is school membership (shown as a link to the school; as a search term, an alias for Thomism), "atheist" is a position, "Fatima" is a topic. None of them is a tag.
- **A figure can be a topic while their tradition is a school.** "Ayn Rand" (topic: debates about or citing her) and "Objectivism" (school: the tradition a debater argues from) are separate pages that link to each other.
- **One slug namespace, plus aliases.** Debater, topic, tag, and school slugs are unique across all four (and against the reserved slugs, §13.2). An `aliases` table maps other names and spellings (`thomist`, `thomists`) to the one canonical page; search and redirects use it. A term cannot be created in a second section because its slug or alias is already taken.

## 4. Claim types

Four claim types, each a distinct detector:

1. **Openings** — "Debater X more often than not opens with these arguments." Positional frequency over turn index.
2. **Counters** — "Debater X will counter you like this." Pairs (trigger move offered → reply), cross-tabbed over the corpus; interesting rows are recurring trigger → reply pairs.
3. **Avoidances** — "Debater X avoids this pushback." A negative observation: what the challenged participant does over the next K turns and before the video ends. Labeled with the pushback rubric (§9.5). The four avoidance behaviors each need a different counter:
   - concede-and-move-on → bank it, escalate elsewhere
   - reframe/redefine → name the reframe
   - pivot to another argument → hold the line, force the answer
   - silence (never returns) → hold and force the answer
   Hardest, most valuable, easiest to destroy by sloppy labeling.
4. **Destination** — the invariant terminal of every formulation of a debater's argument, and the premise the debater relocates to under pressure (§11.2). Found in Milestone 1; not in the original three.

**Rates.** Each entry shows the debater's own rate with numerator and denominator. Where the debater belongs to a school and the school has at least two debaters with confirmed videos, the school's base rate is shown beside it (partial pooling: the interesting cell is the delta; own data overrides the prior as evidence accumulates). Before that threshold the school column is omitted, not estimated.

## 5. Inputs

All inputs are first-class records, entered in the admin UI:

- **YouTube or TikTok URL** — starts the ingest pipeline (§8) as background jobs; the UI shows per-stage status. The submit form also takes the **expected debaters** (prefilled from title/channel matches against debater aliases) and optional extra **keyterms**; both are sent to ElevenLabs with the URL (§8.2).
- **Pasted transcript** — raw text, optional `[Speaker N]` labels, optional source URL. SRT-style pastes go through the same parser as the provider export.
- **Debater record** ("define the opponent") — canonical name, aliases/handles (feeds identity merge, §6), schools (§3.1). Can be created at any time; the debater-page gate (§13.1) governs publication, not record creation.
- **Notes** — free-text annotations on a debater, a video, or a span. Admin-only.
- **Counters** — authored short-circuits attached to an `argument` or a `finding`. Admin-only.

Corpus size is small by design: one debater ≈ 10–60 videos. Rates are shown as counts, never as statistics.

## 6. Evidence rules

- **Every tag cites its span** (word-index range, rendered as a seek to the timestamp). No unsourced classifications.
- **The move vocabulary is a small closed set grown from the corpus** (target ≤ 15 types), not Walton's full scheme catalog — fine-grained classification into large taxonomies drifts (cf. NAACL 2025 label-variation work). Walton argumentation-scheme names label known moves and supply stock critical questions (= pre-existing short-circuits) at the school level.
- **Count all offers, not just instances.** "Avoids X" only means something against a census of every time X was offered.
- **Perceived winner is out of scope as ground truth.** Comment analysis is deferred (§15, Appendix E) until a de-biasing scheme is tested; it never feeds pattern claims before then.
- **Identity merge** — the same debater across channels and handle variants, and diarization labels → people — is a launch-blocking correctness concern. Detectors run only over human-confirmed participant maps (Gate A).
- **Suggest, then confirm; never author.** Every label in the record (speaker names and merges, positions, schools, topics, moves, tags, opponent clusters) is suggested by the system with its evidence (a quote and a timecode, or the counts behind it), and a human confirms or rejects it. A rejection is logged with its reason. No one types a label from scratch, because that is where bias enters. Two consequences: a debater who never states a school on the record has no school, however obvious it seems; and the only authored content is the private counter library (§5), which is never published.
- **The LLM proposes, the code counts, a human confirms.** No published sentence is LLM prose; every row is a query result with span citations, and prose is generated last from rows, each sentence bound to its row.

## 7. Stack

Standard JobyCorp Phoenix app: Phoenix 1.8 / LiveView 1.2, JobyKit 0.3 + daisyUI, Postgres 17 + pgvector, Oban queues, Req behind client modules, singleton settings rows edited in the admin UI (no env-var config; keys Cloak-encrypted), phx.gen.auth username login as in incogito. Bootstrapped with `mix joby_kit.new topoi` with binary ids.

Integrations, each behind a wrapper that returns `{:error, :not_configured}` when its settings row is empty:

| module | service | used for |
|---|---|---|
| `Topoi.Transcripts.ElevenLabs` | ElevenLabs Scribe v2 | diarized transcript from a YouTube/TikTok URL (§8 stage 1) |
| `Topoi.Metadata` | oEmbed (YouTube, TikTok), keyless; YouTube Data API v3 later | v1 is keyless: oEmbed gives title, channel name and URL, thumbnail; ElevenLabs gives duration (`audio_duration_secs`); TikTok `published_at` is derived from the video id. YouTube `published_at`, description, and channel id are missing until a Data API key is added (`videos.list`, 1 unit/video); until then `published_at` is entered at Gate A. Comments later (Appendix E). |
| `Topoi.AI.Gateway` | Airo via `airo_client` | `chat/2` (participant map, move tagging, pushback judge, prose), `embeddings/2` (cross-video line linking, destination clustering) |
| `Topoi.Search` | SearXNG | find more debates for a debater; locate web transcripts |

- `airo_client`: `{:airo_client, git: "git@github.com:JobyCorp/airo_client.git", branch: "main"}` (no Hex release; `main` is prod). Settings singleton holds base_url `https://llm.local.joby.gg` (without `/v1`), encrypted key, and model aliases, edited at **`/admin/gateway`**. Reference implementation: `media_assist/lib/media_assist/ai/gateway.ex`. Local Qwen models get `chat_template_kwargs: {enable_thinking: false}` or `content` comes back nil (mem_pal lesson).
- `Topoi.Search`: copy incogito's provider-behaviour version (`Incogito.Search` + `Search.Providers.SearXNG`); base URL `searxng.local.joby.gg`, stored in a settings row.
- **No Python service in v1.** ElevenLabs is the only ingest path. The self-hosted chain (yt-dlp → WhisperX → Speaches) is a documented, deferred fallback for cost control, private videos, or loss of ElevenLabs URL support (Appendix C).
- Tests stub HTTP via `Req.Test` plugs in `req_options`; Oban `testing: :manual`.

## 8. Pipeline

Rule for the whole pipeline: **the LLM proposes, the code counts, a human confirms at three gates.**

| # | stage | module | kind | queue | done when |
|---|---|---|---|---|---|
| 1 | **Ingest** | `Ingest.Submit` canonicalizes the URL and finds or creates the `video` (§8.1); for a new video it fetches metadata (§7 `Topoi.Metadata`), builds keyterms from the expected debaters (§8.2), and posts the canonical URL as `source_url` to ElevenLabs — only when the video has no live transcript. The raw JSON and the exact request parameters are stored on the `transcripts` row. The paste path parses SRT/`[Speaker N]` into the same `transcript_words`. | code | `ingest` (conc. 2) | `transcript.status = received`, word count > 0 |
| 2 | **Normalize** | `Transcripts.Normalize` applies the turn rules (§9.1) from the settings row; writes `turns`; asserts segment count = speaker-tag count | code | `normalize` | `turns` written; assertion passed |
| 3 | **Participants** | `Participants.Propose`: LLM over the first 5 min of turns + metadata → `{raw_label, role, likely_name, evidence_quote, merge_with?}`; `Participants.MergeHints` flags labels whose turns continue another label's sentence or share a closing; matches `likely_name` to debater aliases. **Gate A.** | LLM + code + **human** | `participants` | every raw label confirmed |
| 4 | **Tag moves** | `Moves.Tag`: windows of 20 substantive turns, 5 overlap, closed vocabulary (§9.3), participant map, open lines carried forward, `json_schema` output (§10) | LLM + code | `tag` (conc. 4) | every substantive turn has ≥1 move or an explicit `none` |
| 5 | **Pair pushbacks** | `Pushbacks.Pair`: candidate = next ≤ K turns by the challenged participant after a `challenge` or question; `Pushbacks.Judge` labels the reply per the rubric (§9.5). **Runs after the last turn is tagged**, never streaming: a `defer` at 5:49 in v1 is `silence` by the end. | code + LLM | `pair` | every `challenge` has a pushback row |
| 6 | **Lines** | `Lines.Build`: group a video's moves into lines by `line_ref`; `Lines.Link`: cross-video unification by embedding + LLM naming into a debater-level `argument`, each distinct premise set recorded as a `formulation` | code + LLM | `lines` | every move belongs to a line; every line links to ≤ 1 argument |
| 7 | **Per-video dossier** | `Dossier.Video.render/1`: pure query over `moves`, `pushbacks`, `lines`; tagging log from `contested`, `confidence < τ`, exclusions | code | — | renders with no LLM call |
| 8 | **Debater aggregate** | `Dossier.Debater.render/1`: computed `findings` (§11.1) over all confirmed videos; prose generated last from rows | code (+ LLM prose) | `aggregate` | every sentence has a row id and ≥ 1 span |
| 9 | **Destination** | `Findings.Destination` (§11.2) | code + LLM | `aggregate` | row present when ≥ 3 videos |
| 10 | **Graph index** | `Graph.Rebuild`: regenerates `graph_entities`/`graph_edges` for the debater from relational rows (§12.2) | code | `aggregate` | index matches rows |
| 11 | **Review** | **Gate B** (§13) | **human** | — | queue empty for the video |
| 12 | **Publish** | **Gate C** (§13): writes `published_pages` snapshots | code + **human** | — | `published_at` set |

Stages 1–10 are Oban jobs chained per video, not per debater; 8–10 re-run for the debater after every confirmed video. Stage 5 depends on stage 3 (the challenged participant must be known).

### 8.1 Canonical videos

A video is ingested and transcribed **once**, however many debaters appear in it and however many times its URL is submitted. ElevenLabs is billed per transcription, and every participant's analysis must cite the same `transcript_words`.

- **Identity is `(platform, platform_video_id)`**, never the submitted URL string. `Ingest.Canonicalize` maps every URL form to it before any lookup:
  - YouTube: `watch?v=`, `youtu.be/`, `m.` and `music.` hosts, `/shorts/`, `/live/`, `/embed/`; tracking and position params (`t`, `si`, `feature`, `list`, `pp`, …) dropped. Canonical URL `https://www.youtube.com/watch?v=<id>`.
  - TikTok: `/@handle/video/<id>` and `/@handle/live/…`; short links (`vm.tiktok.com`, `vt.tiktok.com`) are resolved by following the redirect once, before lookup. Canonical URL `https://www.tiktok.com/@<handle>/video/<id>`.
  - An unrecognized URL is rejected with a message, not stored.
- **Submit is idempotent.** If the video exists, `Ingest.Submit` returns it and starts nothing; the admin UI shows its pipeline status. The unique index on `(platform, platform_video_id)` plus an Oban unique job keyed on the same pair make two concurrent submits produce one video and one ElevenLabs call.
- **Debaters attach to videos through `participants`** (§9.2), never by re-submitting. "This video also features debater Y" is a Gate A edit on the existing video; re-running stages 3–10 for it costs LLM calls, never a transcription.
- **Re-transcription is an explicit admin action** (e.g. a provider upgrade or a failed job). It creates a new `transcripts` row with `supersedes_id`; the old row and its words are kept so existing spans still resolve.
- **Pasted transcripts** with a source URL go through the same canonicalization: a paste for a video that already has a live transcript is stored as a superseding transcript only when the admin chooses to replace it; otherwise it is rejected as a duplicate. A paste with no source URL creates a `videos` row with `platform = none` and no uniqueness guarantee.

### 8.2 ElevenLabs request

`Topoi.Transcripts.ElevenLabs` sends `POST /v1/speech-to-text` (multipart) with:

| parameter | value | why |
|---|---|---|
| `model_id` | `scribe_v2` | `no_verbatim` and current accuracy need v2 |
| `source_url` | the canonical URL (§8.1) | |
| `diarize` | `true` | |
| `timestamps_granularity` | `word` | spans cite word indexes (§9) |
| `tag_audio_events` | `true` | laughter, applause, music become `audio_event` tokens; kept out of turns, available for context |
| `no_verbatim` | `false`, fixed | fillers and false starts are evidence (interruptions, restarts) and are stripped only for display (§9.1 rule 5) |
| `num_speakers` | expected participant count when known (expected debaters + host/moderator), else unset | helps diarization; never fewer than the expected debaters |
| `keyterms` | built per video, below | names and terms are the words ASR gets wrong |
| `use_speaker_library` | `false`, fixed | voice matching of debaters is out of scope (§3, no biometrics) |
| `seed` | fixed setting | best-effort determinism for re-transcription comparisons |

Not used: `additional_formats` (turns are built from words, not SRT), `detect_speaker_roles` (agent/customer roles; +10%), `entity_detection` (+30%), `webhook` (see below).

**Keyterms.** Assembled at submit time, deduplicated, and stored with the request:

1. Each expected debater's canonical name, aliases, and handles (e.g. the handle "Jesus and Whatnot" plus the name the debater gives on the record).
2. Each expected debater's own term list and their schools' term lists (e.g. "actus purus", "Thomist", "Fatima").
3. The channel name and name-like fragments of the title (e.g. "Redeemed Zoomer").
4. Free terms typed on the submit form.

Limits enforced before sending: ≤ 1000 terms, each < 50 characters and ≤ 5 words; over-length terms are dropped with a warning in the ingest UI. Keyterms add a **20% surcharge** to the transcription; a video with no expected debaters and no terms is sent without them.

Why: the first API test (Appendix D) transcribed the other speaker's handle "Redeemed Zoomer" as a similar-sounding personal name in the opening line, the line participant naming (§9.2) depends on.

**Synchronous by default.** The test call returned 89.5 min of audio in 82 s. The Oban worker makes the call synchronously with a 10-minute receive timeout; `webhook: true` (with `webhook_metadata` carrying the `video_id`) is the fallback for videos where that timeout is hit. Dev therefore needs no public webhook endpoint.

**Retries.** "Failed to download the file from the provided URL (upstream status 400)" is transient: the first API test failed with it and the identical request succeeded on retry. The worker retries it with exponential backoff (5 attempts); other 4xx errors fail immediately and show in the ingest UI. A failed download is not billed.

## 9. Normalization and tagging rules

Provider output passes through additive layers. Raw data is never rewritten; each layer references the one below by word index, so a span citation survives re-normalization.

| layer | unit | produced by | stored as |
|---|---|---|---|
| 0 | provider payload | ElevenLabs JSON or parsed paste | `transcripts` + `transcript_words` |
| 1 | segment | provider chunking | not stored; derivable |
| 2 | turn | deterministic rules (§9.1) | `turns` |
| 3 | participant | per-video label map (§9.2), Gate A | `participants` |
| 4 | move + line | LLM with closed vocabulary (§9.3) | `moves`, `lines` |

### 9.1 Turn rules

Sized on `docs/samples/xh9D0oLxwQg.elevenlabs.srt.txt` (56 min, 2 speakers). Thresholds live in a settings row and are re-derived as samples accumulate; they are not constants in code.

1. **Merge** consecutive same-speaker segments when the gap ≤ 4 s. A turn ends only when the other speaker holds the floor. Sample: 941 segments → 893 turns. *(The file has 942 speaker tags; the sizing probe probably dropped one block — see rule 6. Re-measure in M2.)*
2. **Backchannel**: duration < 2 s, ≤ 6 words, no `?`. Flagged, kept, never a move. Sample: 256 of 893.
3. **Bridge**: if speaker A's turn is followed only by B backchannels and then A again within 8 s, that is one A turn. Sample: 893 → 518 substantive turns (258 vs 260, talk time within 7%).
4. **Interrupted**: a segment starting with `...` or ending mid-word or with `-` marks the turn `interrupted: true`. Diarization is least reliable in overlap, so interrupted turns carry lower default confidence into tagging.
5. **Fillers** (`um`, `uh`, repeated starts; 2.5% of words): stripped for display and for the classifier prompt, never from `transcript_words`. Stripping is a view, not a mutation.
6. **Final block.** The last block of an SRT-style export has no trailing blank line; a parser that requires one drops it silently (found on video 3, where the dropped block held the only stage-2 completion in the corpus). Parse on block start, not block end, and assert `segments == count of speaker tags`.

Sample distribution: median turn 15 words / 3.3 s, 12 turns over 80 words, max 68 s; argument content starts at 55 s (first turn > 40 words).

### 9.2 Speaker labels and participants

- Provider labels are **per video and arbitrary** (`Speaker 0` is the host in one video, the guest in the next). They are stored as `raw_label` and never renamed in place.
- **One person may receive several raw labels in one video** (cPVtaKPLC9Q: the affirmative's six-minute closing statement landed on a fifth label in a four-person debate, with no crosstalk). Many `participants` rows may share one `participant_id`; talk time and move counts aggregate over the participant, never the label.
- **Resolution order:** (a) LLM over the first 5 min + title/description/channel → proposed map with evidence quotes; (b) match `likely_name` against debater aliases; (c) Gate A: Jody confirms, corrects, or merges ("same person as") in the ingest UI.
- The dossier joins through `participants.debater_id`, never through the label.
- **No voice prints** (§3). When content gives no name, the label stays unnamed until a human names it at Gate A; a debater who cannot be identified from the record is not attributed.

### 9.3 Move vocabulary (seed)

A **line** is a claim or argument introduced by one participant plus every move made on it afterwards, until it is dropped or resolved. Seed vocabulary, each drawn from the samples:

- `open` — introduces a line
- `develop` — continues own line
- `challenge` — attacks the other side's line
- `defer` — declines to answer now, promises later
- `meta` — talks about the conversation instead of the line
- `reframe`, `concede`, `pivot` — avoidance behaviors (§4)
- `interject` — substantive but interrupting (< 15 words, mid-opponent-turn, not backchannel)

`silence` is not a move type: it is the absence of a move, assigned by code in stage 5 (§9.5). Moves also carry a free-text `tactic` (e.g. `knowledge-check`, `burden-scope`); tactics feed tag assignment (§3.1) and appear as evidence on pages, not as pages of their own.

### 9.4 Extraction checks

- Every move quotes a substring of its turn; rows whose quote is not found are rejected (the cheapest hallucination check).
- `move_type` ∉ vocabulary → row rejected.
- No moves on backchannel turns.
- `opponent_present` comes from the participant map, not the model.
- A merge pass unifies `line_ref` across windows by label similarity and closes lines untouched for N turns.

**Why this matters.** Before normalization, four "let me finish" deferrals in v1 (195 s, 287 s, 353 s, 360 s) were separate 1–3 s segments interleaved with backchannels and read as noise. After it, they are a countable counter row ("challenge → defer"). Every sample must pass this test: a pattern a human spots in one viewing survives the layers as a countable row.

### 9.5 Pushback rubric

Applied to every `challenge` (and every question) aimed at a participant. K is a setting (default 6 substantive turns).

- **answered** — the reply addresses the trigger's content and the trigger is not re-raised in the same form within K turns.
- **answered-from-own-frame** — the reply resolves the trigger only inside the debater's framework (v4 anthropomorphization; v2 B-theory). Counted as answered in the census, labeled so the reader can weigh it.
- **defer** — explicit promise to return. Becomes **silence** if no `develop` or answer on that line follows before the video ends.
- **reframe** — the reply changes what the question is about (scope, definition, fallacy label). `contested` when the reframe is arguably legitimate under the resolution (v4 "existence, not effects").
- **pivot** — the reply moves to a different line without resolving this one.
- **concede** — partial or full grant; may co-occur with `reframe`.
- **silence** — no reply on the line by the challenged participant within K turns and none later. **Assigned by code**, not by the judge: the judge only sees replies that exist.

Each pushback row also carries `completed: yes | no | contested`. `contested` always enters Gate B.

## 10. LLM prompts

All via `AiroClient.chat/2` with `response_format: json_schema`; `model` and `prompt_version` stored on every row.

1. **Participant map.** In: first 5 min of turns, title, channel, description. Out: per raw label `{role, likely_name, evidence_quote, merge_with?}`. Check: `evidence_quote` appears in the turns.
2. **Move window.** In: 20 turns, participant map, vocabulary with one-line definitions, lines open from the previous window, format. Out: `[{turn_idx, line_ref, move_type, tactic?, target_turn_idx?, quote, confidence, contested_reason?}]`. Checks: §9.4.
3. **Pushback judge.** In: the trigger turn, the K following turns, the challenged participant. Out: `{behavior, completed, quote, reason}`. Check: `quote` ⊂ one of the K turns.
4. **Argument naming** (cheap, advisory): names cross-video arguments; a human can rename.

## 11. Findings

### 11.1 Debater aggregate

Each row is a query over confirmed videos, not a judgment:

- **Stable**: a move, tactic, or argument present in ≥ 75% of confirmed videos where the format allowed it.
- **Adaptive**: a move whose rate differs across opponent clusters or formats beyond a settings threshold (deferral count varies; deferral *rate per interruption* does not). Opponent clusters (`hostile-host`, `engager`, `formal-opponent`) are computed from the opponents' own move profiles, suggested per participant, and confirmed at review; never assigned by hand.
- **Census**: for each pushback class (cross-video `arguments` on the opponent side), offered-in, behavior distribution, completed ratio.
- **Base-vs-downstream split**: pushback classes partitioned by whether they target a premise of the debater's own argument (`formulations.premises`) or something downstream; completed ratio per partition.
- **Floor dependence**: for the debater's terminal claim, completion rate split by `opponent_present` and format.
- **Unknowns**: arguments or pushback classes with `n_total < 2`, formats never seen, `channel_of_record` distribution, chronology gaps. Published as "still unknown"; it is the honesty signal and recommends which video to ingest next.

### 11.2 Destination

1. For each video, the terminal claim of the debater's primary line (the last `develop` before the line closes or the video ends), embedded.
2. Cluster terminals across videos; a cluster covering ≥ 75% of videos is the **destination**.
3. For each `pivot` and `reframe` by the debater, record the line it moved to; the most frequent target premise is the **gate**.
4. Report the base-vs-downstream split beside it.

Output row: *"Across N formulations the argument terminates at X; under challenge the debater relocates to Y (k of m relocations); pushback at Y is completed j of n times."*

## 12. Data model

### 12.1 Relational tables (source of truth)

- `debaters`: canonical name, `slug`, handles, `keyterms` (terms the debater uses; fed to §8.2). School membership via `school_memberships` (many-to-many, cited and confirmed, §3.1).
- `video_debaters`: expected debaters chosen at submit (`video_id`, `debater_id`); a hint for keyterms and Gate A, not a confirmation.
- `videos`: `platform` (`youtube | tiktok | none`), `platform_video_id`, `canonical_url`, **unique on `(platform, platform_video_id)` where `platform <> none`** (§8.1), `format` (`tiktok_live | youtube_live | moderated_formal | podcast | monologue`), `channel_of_record` (`debater | opponent | third_party | unknown`), `published_at`, duration, title, channel.
- `transcripts`: `video_id`, `provider` (`elevenlabs | paste | …`), `provider_job_id`, `status`, `request_params jsonb` (model, keyterms, num_speakers, seed — exactly what was sent), `raw_payload jsonb`, `supersedes_id`. At most one live (not failed, not superseded) transcript per video, enforced by a partial unique index.
- `transcript_words`: `transcript_id`, `idx`, `text`, `start_ms`, `end_ms`, `raw_label`, `logprob`.
- `turns`: `video_id`, `idx`, `raw_label`, `first_word_idx`, `last_word_idx`, `kind` (`substantive | backchannel`), `interrupted`.
- `participants`: `(video_id, raw_label)` rows; `participant_id` (shared by merged labels), `role` (`host | guest | moderator | opponent`), `position` (the side taken in this debate, from the `positions` vocabulary; suggested from the resolution side or a stated stance with its quote, confirmed at Gate A; §3.1), `debater_id` nullable, `confidence`, `evidence_quote`, `confirmed_by_user`.
- `lines`: per video; `label`, `opened_by` participant, `first_turn`, `last_turn`.
- `moves`: `turn_id`, `line_id`, `move_type`, `tactic`, `target_move_id` nullable, word-index span, `opponent_present`, `contested`, `confidence`, `model`, `prompt_version`, `reviewed_by`, `supersedes_id`.
- `pushbacks`: `trigger_move_id`, `reply_move_id` nullable, `behavior`, `completed` (`yes | no | contested`), `window_turns`, `quote`, `judged_by` (`model | code | human`).
- `topics`: curated, cross-debater (`slug`, name, one-paragraph definition). `arguments`: per debater, each linked to ≤ 1 topic (`topic_id`); a topic page aggregates the arguments linked to it. `formulations`: child of argument, one per distinct premise set; `line_links`: `line_id → argument_id, formulation_id`.
- `findings`: `kind` (`stable | adaptive | census | destination | unknown`), `statement`, `support` (video ids), `spans[]`, `n_videos`, `n_total`. Regenerated, never edited; edits happen upstream.
- `schools`: `slug`, name, stock critical questions, `keyterms` (school vocabulary; fed to §8.2). Traditions only, never positions (§3.1).
- `tags`: curated one-word style descriptors (`slug`, name, one-line definition, the rule that assigns it: which move/tactic rate, which threshold). `tag_rule_changes`: who changed which rule, when, old and new values; every change triggers a full recompute. `performance_tags`: one row per (participant, debate, tag), computed from that performance's move and tactic counts, with the supporting counts and spans. Debater tags are a query over `performance_tags`, not stored. `debate_topics`: the topics discussed in each debate, derived only from its lines' linked arguments; a reviewer can correct a wrong argument → topic link but cannot add a topic directly. `school_memberships`: (debater, school, quote, span, confirmed_by, confirmed_at); a membership with no citation cannot exist.
- `positions`: small curated vocabulary (`theist`, `atheist`, `agnostic`, …), extended per resolution type.
- `aliases`: `(alias, target_type, target_id)`; alias unique, normalized lowercase; covers every slug namespace (§3.1).
- `counters`: authored short-circuits, `attached_to` an `argument` or `finding`; admin-only.
- `notes`: attached to a debater, video, or span; admin-only.
- `gold_tags`: human-accepted moves and pushbacks keyed by `(video_id, turn_idx)`; the grading set for §14.
- `published_pages`: Gate C snapshots served to public routes.
- Settings singletons: normalization thresholds, K, τ, debater-page gate N, and one row per integration.

Re-tagging corrections use `supersedes_id` + `dedup_key` (mem_pal pattern).

### 12.2 Graph index (derived)

`graph_entities(type, name, metadata)` + `graph_edges(edge_type, source_id, target_id, weight, confidence, metadata)`, the incogito `Incogito.Graph` shape: unique on `(source, target, type)`, `no_self_edges` check, `WITH RECURSIVE` traversal via `Ecto.Query.with_cte` + `recursive_ctes(true)`. Plain Ecto tables, no Apache AGE (Appendix F).

- **Derived, never written directly.** Stage 10 rebuilds a debater's subgraph from relational rows. Edges carry `finding_id` or `move_id` in metadata, so every edge resolves to cited spans.
- **Used for atlas cross-links and traversals**, not for pipeline state: debater ↔ debate ↔ topic ↔ tag ↔ school, and questions like "which debaters run arguments this counter short-circuits".
- Node types: `debater`, `video`, `argument`, `tactic`, `school`, `counter`. Edge types: `participated_in` (debater → video), `opposed` (debater ↔ debater per video), `runs` (debater → argument), `uses` (debater → tactic), `belongs_to` (debater → school), `short_circuits` (counter → argument).
- Per-video dossier queries stay as fixed-hop joins over the relational tables.

## 13. Gates and publishing

Only three human gates. Everything else runs unattended.

- **Gate A — participant map** (≈ 30 s per video): the one place diarization errors are caught. Also where `published_at` is entered for YouTube videos while no Data API key exists (§7).
- **Gate B — review queue**: `contested`, `confidence < τ`, and every `silence`; expected 5–15 items per hour of video. Accepted items become `gold_tags`. The first video of every new debater is reviewed in full. If volume stays above ~20 items/hour after ten videos, the vocabulary or the rubric is wrong, not the reviewer.
- **Gate C — publish**: debater-page gate, span check, scope rule, reviewer sign-off. Nothing publishes on a timer.

### 13.1 Debater-page gate

A debater's public page is published only when the debater has N confirmed public performances (N is a setting, default 3). Debater records, ingest, and tagging are not gated.

### 13.2 Public pages

Debaters are the index; arguments and debates are the content. **The full transcript is never published**; public pages show short quoted spans with seek links. Transcripts stay internal to the pipeline and the review UI.

**Routes**

| route | page | notes |
|---|---|---|
| `/` | front page: what Topoi is, an example finding, the four ways into the library | |
| `/debaters`, `/debates`, `/topics`, `/tags`, `/schools` | index of each section | |
| `/search?q=` | search across debaters, topics, tags | a GET URL so searches are shareable |
| `/:debater` | debater page (e.g. `/jesus-and-what-not`) | only past the debater-page gate; the shareable URL |
| `/:debater/debates` | the debater's debate list, filter by format / opponent / topic | links to the scoped debate route |
| `/debates/:debate` | debate page, canonical: all participants equal | a debate is not owned by any participant |
| `/debates/:debate/:debater` | the same debate page with this debater's side foregrounded | 302 to `/debates/:debate` when the debater is not a participant or has no published page |
| `/topics/:topic` | one topic: every debater's argument linked to it, across debates (the atlas layer) | |
| `/tags/:tag` | one style descriptor: the debaters it applies to, each with "n of m debates" and the performances behind it | |
| `/schools/:school` | a tradition: stock critical questions, base rates, member debaters | positions (theist, atheist) are filters, not school pages (§3.1) |
| `/request` | request a debater (name, links to ≥ 3 public performances) | feeds the ingest queue; nothing auto-publishes |
| `/admin` | admin overview: setup state, debates in the pipeline | admins only (`users.admin`); signed-in non-admins are turned away |
| `/admin/gateway` | Airo gateway settings: base URL, encrypted key, model aliases, connection test | authenticated |
| `/admin/**` | ingest, Gates A/B/C, counters, notes, other integration settings | admins only |
| `/users/log-in`, `/users/settings` | username + password sign-in; account settings | no public registration; accounts come from seeds or an admin |

**Slugs.** `:debater` from the handle; `:debate` = title-slug + platform video id suffix (`does-the-christian-god-exist-cPVtaKPLC9Q`), so the id resolves even if the title changes; `:topic` and `:tag` are curated names. Debater slugs live at the root so a debater page is shareable as `topoi.gg/<handle>`; so every first path segment used by the app (`about`, `debaters`, `debates`, `topics`, `tags`, `schools`, `search`, `request`, `admin`, `users`, `design`, `custom-designs`, `design.json`, `dev`, `assets`, …) is a **reserved slug**, enforced by a validation on `debaters.slug` and listed in one module.

**Debater page** (`/:debater`), in order, all rows from `findings` with spans:

1. Header: handle, display name as used on the record, schools (linked), confirmed video count, format mix, channel-of-record mix (the corpus bias). No photo, no bio.
2. Style: `stable` findings, each with its rate and up to three span chips.
3. Positions: `arguments` with their `formulations` as children, each naming the debate it appeared in.
4. Destination: the §11.2 row.
5. Under pressure: the census table (pushback class → offered in → behavior → completed); `contested` rows shown as contested, with the reason.
6. Adaptive by opponent/format.
7. Debates: cards with player poster, format, opponent, date, the topics discussed, and the tags this debater earned in it.
8. Still unknown.
9. Counters: the school's stock critical questions per argument. Jody's authored counters are **not** shown (admin-only by default; see §15).

**Debate page** (`/debates/:debate` and the debater-scoped `/debates/:debate/:debater`):

1. Player: YouTube IFrame embed with the Player API, so every span chip calls `seekTo`; opens at the first substantive turn. TikTok: oEmbed when embeddable, otherwise a link-out card with the seek times listed. Media is never hosted or re-uploaded.
2. Facts: format, date, channel of record, participants with their position in this debate (links where the debater has a published page, plain name otherwise), moderators, resolution, length.
3. What happened: `lines` as horizontal bands over the duration, one lane per participant, colored by move type; clicking a band seeks.
4. Analysis per participant (the scoped debater's side first on the scoped route): the tags earned in this performance, openings, counters, avoidances, video-scoped findings.
5. Pushbacks: the full table, filterable by behavior and by who was challenged.
6. Topics discussed, linking out. (The debate has no tags of its own; tags belong to each participant's performance, item 4.)
7. Tagging log: contested rows, confidence summary, exclusions by rule, diarization merges applied.

**Topic page**: curated one-paragraph definition, school critical questions, formulations seen, debaters who run it with their rates, debates with seek chips, pushback census across debaters. **Tag page**: one-line definition, examples across debaters with spans, rate per debater.

### 13.3 Rendering rules

- Every public sentence carries a `finding_id` or `move_id` and ≥ 1 span; the renderer refuses to emit a sentence without one.
- Quotes ≤ 25 words; longer evidence is a seek, not a quote.
- Rates show numerator and denominator ("completed 0 of 2"), never a percentage alone.
- Opponents without a published debater page are named as they name themselves on the record and are not linked; their analysis appears only inside the debate page, never aggregated.
- Public routes are unauthenticated and cacheable and read only `published_pages` snapshots; a public hit never queries pipeline tables.
- JobyKit: public pages are LiveViews under `TopoiWeb.Public.*`; chips, timeline bands, and census tables are domain composites registered in `TopoiWeb.DesignManifest`; no raw primitives in `.heex`.

## 14. Acceptance tests (gold set #1)

Gold set #1 is the four hand-tagged videos of one debater (local only, gitignored: `docs/dossiers/` and `docs/samples/*.srt.txt`). The pipeline is accepted when, with the human participant map confirmed, it reproduces:

| test | target | tolerance |
|---|---|---|
| v1 deferrals by the Thomist | 14 | ±2 |
| v1 "theory / vehicle" reframes by the host | 10 | ±2 |
| v2 deferrals | 2 | ±1 |
| v4 `burden-scope` reframes | ~12 | ±3 |
| v4 participant merge | 5 labels → 4 people, S4 ⊂ Thomist | exact |
| v1 "finger is not God" | `defer` → `silence` | exact, and only after end of video |
| v2 stage-2 pushback (40:25) | `pivot`, `completed: no` | exact |
| v4 composition (8:11) | `silence` | exact |
| v4 differentiation demand | `reframe`, `completed: contested` | exact |
| stage-2 floor dependence | 2/2 unopposed, 0/2 challenged | exact |
| cross-video argument linking | four formulations → one `argument` | exact |
| destination row | terminal = actus purus; gate = potency | present, human-verified wording |
| scope rule | zero published sentences without a span; the v2 medical aside and v4 soda talk excluded | exact |

Regressions on any exact row block merge (`mix precommit`); tolerance rows are reported. Because the gold files are not in git, these tests are tagged and skipped when the files are absent.

## 15. Milestones

| | scope | exit |
|---|---|---|
| **M1 — done** | one debater, four videos, tagged by hand in markdown | gold set #1; four pipeline defects found (label flip, label split, final block, channel bias) |
| **M2 — pipeline reproduces gold** | stages 1–10 on the four videos | §14 table green; Gate B volume measured |
| **M3 — second and third debaters** | 8–12 videos each, pipeline in the loop, full Gate B on video 1 of each | three debater aggregates; vocabulary still ≤ 15 types; school base rates possible |
| **M4 — admin and review UI** | LiveView: per-video view with span seek, debater view with findings and counters, review queue | Jody uses it instead of markdown |
| **M5 — public atlas** | Gate C, `published_pages`, debater / debate / topic / tag / school pages, `/request` | first public debater page on topoi.gg |

Deferred past M5: comment and sentiment analysis (needs a tested de-biasing scheme), the self-hosted transcription fallback, public counters. Not planned at all: voice prints or any speaker biometrics (§3).

## 16. Open questions

- **Counters:** stay admin-only (current default), or become public? Public counters turn a debater page into a playbook against a named person — a different product and a different exposure.
- **Opponents on debater pages:** show opponents' aggregate behavior against a debater ("hostile hosts share four moves")? Default: show it on the `hostile-host` school page, not the debater page, because it aggregates people without published pages.
- **Move vocabulary:** how small is stable? Target ≤ 15 types.
- **K and τ:** set from gold set #1, re-fit at M3.
- **Counter drafting:** authored only, or LLM-drafted from the scheme's critical questions and then curated?
- **Corpus bias:** We watch debates where our side does well, and debaters upload the debates they do well in. What entry hygiene counters this? (`channel_of_record` makes it visible; it does not fix it.)
- **ElevenLabs confidence:** can word-level `speaker_id` confidence pre-flag Gate A merges?
- **Keyterm surcharge:** accept 20% on every video with known debaters (current plan), or only when the first pass mis-hears a name?
- **Chronology:** `published_at` is required for formulation-drift findings; backfill for the four gold videos.
- **YouTube Data API key:** not used in v1. Add before M3, when chronology findings need `published_at` at volume. Which Google Cloud project?
- **Mailer:** the bootstrap generated `Topoi.Mailer` (Swoosh). Keep it for phx.gen.auth emails, or remove it (the v0.2 plan said `--no-mailer`)?

---

# Part II — Research log

Dated findings that informed Part I. Kept for provenance; not normative.

## Appendix A. Landscape (verified 2026-10-01 against GitHub/arXiv/Wikipedia APIs; search-engine endpoints were bot-walled)

- **Nothing ships this.** Closest: `Zing302/Debate_LD_Prep` — "Opponent Scout" with loss-pattern analysis, but 0★, dormant (last push 2026-04-11), and confined to competitive HS debate where cases are *disclosed* on OpenCaselist (public record; no improvisation to mine). Public intellectuals don't disclose — the pattern is realer here and the software absent.
- `latent-variable/FallacyScoreboard` (29★, dormant 2024-08): YouTube → WhisperX + diarization → LLM fallacy tags → scoreboard overlay. A scoreboard, not a scout: per-utterance, no memory across videos. The ingestion pipeline is largely solved prior art.
- `latent-variable/Real_time_fallacy_detection` (119★): live per-segment fallacy classification. Same limitation.
- Map tools (Kialo, debate-map.app, Argdown, Rationale, CmapTools): graphs you draw yourself; no opponent model, no counters.
- Counterargument research (PTCG persona-guided counterargument trees, arXiv 2609.07120; Conch competitive-debate clash-point visualization, 2025-07; PAKT perspectivized argumentation KG, 2024-04): generates or visualizes; none tracks an individual's habits over real transcripts with an avoidance detector.
- Multi-agent-debate boom (`llm_multiagent_debate`, ChatEval, etc.): about improving answers, not modeling an adversary.
- Academic ancestry to steal from: Walton argumentation schemes + critical questions (names & stock short-circuits); pragma-dialectics discussion stages (opening-stage moves — *when* a counter must fire); intelligence-analysis ACH (hypothesis × evidence matrix); security attack-graph countermeasure selection (set-cover: which single short-circuit kills most of a school's lines).

Prior art worth reading before coding:

- `NotJoeMartinez/yt-fts` (1.8k★) — yt-dlp subs → FTS + embeddings; best transcript storage model.
- `0xCaFeBEef/free-youtube-transcript-mcp` — documents a tried-in-order caption cascade (InnerTube clients → watch page → transcript panel → yt-dlp).
- `thenavidm/youtube-mcp-cli` — comments via Data API, transcripts via yt-dlp.
- `gunn4r/earwig` (2★, beta) — YouTube URL → yt-dlp → WhisperX → LLM names speakers → Markdown; exactly this pipeline; read, don't depend.

## Appendix B. YouTube captions (2026-10-01) — superseded as primary by Appendix D

Nothing in the fleet handled YouTube at the time (grep of incogito, helm, media_assist, vox, bardo; YouTubePilot is script notes, not code).

| Option | Status (2026-10-01) | Verdict at the time |
|---|---|---|
| yt-dlp `--skip-download --write-subs --write-auto-subs --sub-langs en --sub-format json3` | 194k★, release 2026.08.19, pushed 2026-09-27 | Was primary; now part of the deferred fallback chain. `System.cmd` from an Oban worker, concurrency 1, cached by video id; `uv tool install yt-dlp`; weekly `yt-dlp -U`. |
| youtube-transcript-api (Python) | 8.4k★, v1.2.4; cookie auth officially disabled; `PoTokenRequired` (issue #592) has no workaround; ~30 fetches from a home IP before `IpBlocked` | Fallback only. |
| Hex `youtube_captions` 0.1.0 (2023), `youtex` 0.2.0 (2021) | Pre-date the 2025–26 PO-token changes | Assume broken. |
| Hex `exyt_dlp` 0.1.6 | 3★ thin `System.cmd` wrapper | Write our own ~30-line module instead. |
| Data API v3 `captions.download` | Needs owner OAuth on the video, 200 units | Useless for third-party videos. |

YouTube captions never carry speaker labels (auto captions: none; `>>` markers in human captions are an unenforced broadcaster convention), which is why captions alone cannot feed this pipeline.

**Bot-walling.** Datacenter IPs are blocked on reputation before cookies are checked; PO tokens are per-video and manual extraction is discouraged. The target VM sits on a residential line, which sidesteps the IP block. Remaining risks: per-IP rate limiting (tens of fetches per burst), `PoTokenRequired` caption tracks, 429s on auto-*translated* subs. Mitigations: single-concurrency queue, `--sleep-requests`, per-video cache, keep yt-dlp current, never ship `--cookies-from-browser`. Add `bgutil-ytdlp-pot-provider` (v2.0.0, 2026-09-08, Node ≥ 22 sidecar on :4416) only if empty subtitle bodies appear.

**ASR options** (no captions): `yt-dlp -x` audio → ffmpeg 16 kHz PCM → `AiroClient.transcribe/3` with alias `"whisper"` (Airo fronts Speaches at `POST /v1/audio/transcriptions`; Orchester's registry listed no Speaches service on 2026-10-01 — verify before relying on it), or `whisper_cpp` 0.5.0 / `whisper_ct2` 0.7.0 Hex NIFs (rubas, 2026-09-23, 0★, Elixir 1.19; segments + word timestamps, no diarization), or Bumblebee 0.8.0 `speech_to_text_whisper` (mature, slower, no diarization).

## Appendix C. Diarization (verified 2026-10-01) — the deferred self-hosted fallback

Every working tool is the same pipeline: `yt-dlp -x` → Whisper → diarization model → word/segment labels.

| Tool | Status | Emits | Elixir call | Caveat |
|---|---|---|---|---|
| **WhisperX** (m-bain) | 24.3k★, pushed 2026-09-26, PyPI 3.8.6 | segment + word `SPEAKER_xx` with timestamps | CLI only | gated pyannote model, HF token, < 8 GB VRAM |
| **whisper-asr-webservice** (ahmetoner) | 3.3k★, 2026-08-09 | same, as JSON | `POST /asr?diarize=true&min_speakers=2&max_speakers=3&output=json` (multipart) with `ASR_ENGINE=whisperx`, `HF_TOKEN` | easiest Req target |
| **Speaches** (already behind Airo) | 3.7k★, 2026-09-29 | `/v1/audio/diarization` → `{start,end,speaker}` segments; accepts `known_speaker_names[]` + `known_speaker_references[]` | separate from `/v1/audio/transcriptions`; merge in Elixir | endpoint exists in code, undocumented |
| **NVIDIA Nemotron-3-Diarization** | released 2026-09-23, not gated, ≤ 8 speakers, 99M params | timestamps + labels, no text | library; needs thin FastAPI | best DER (AMI 9.25% vs community-1 17.0%); Ampere+ GPU |
| **WhisperLiveKit** | 11.1k★, 2026-10-01 | realtime ASR + Sortformer diarization | WS + OpenAI-compat REST | realtime-oriented |
| **whisper-diarization** (MahmoudAshraf97) | 5.7k★, 2026-08-15 | SRT/TXT with speakers, NeMo-based, no HF gate | CLI | ≥ 10 GB VRAM |

Hosted alternatives: AssemblyAI (`speaker_labels`, $0.17/hr all-in, 10 h max, content-based speaker naming), Deepgram (`diarize=true`, ~$0.26/hr), OpenAI `gpt-4o-transcribe-diarize` (`response_format=diarized_json`, ≤ 4 reference clips for known speakers, 25 MB/file), Mistral Voxtral (`diarize=True`, ~$0.18/hr, 3 h/request), Gemini (accepts YouTube URLs but speaker labels only via prompting). All except ElevenLabs and Gemini need yt-dlp first. Nothing Elixir-native exists for diarization (hex.pm: no hits for diarization/pyannote/speechbrain).

**Fallback chain, if ever needed:** yt-dlp → whisper-asr-webservice (WhisperX) on an NVIDIA box → Speaches diarization (without `known_speaker_references`) → LLM names speakers from content. This is the only path that adds a Python service.

**Labels → names.** (1) LLM attribution from content (introductions, address-by-name): near free, fails on silent moderators and short turns. This is the only method used. (2) *Rejected 2026-10-01 — debaters have not consented to biometric matching (§3).* Voice-print enrollment for cross-video identity, as surveyed: one enrolled clip per debater → mean embedding per label → cosine match. Open models: `speechbrain/spkrec-ecapa-voxceleb`, `pyannote/wespeaker-voxceleb-resnet34-LM` (both ungated). Ready-made: Speaches `known_speaker_references[]`, OpenAI, pyannoteAI hosted voiceprints. ECAPA ONNX could run in-BEAM via `ortex` 0.1.10 (DIY).

**Accuracy limit.** Published DER, no collar, overlap scored: pyannote 3.1 11.3% on VoxConverse (YouTube talk shows/debates), 18.8% AMI; community-1 17.0% AMI; Nemotron-3 9.25% AMI / 12.73% DIHARD. Expect ~10–15% of debate audio mis-attributed, concentrated in crosstalk; errors are dominated by missed speech, then speaker confusion; word-to-speaker merge adds error at turn boundaries. Two-speaker debates do materially better than 3 + moderator. A mis-attributed interruption can turn an avoidance into a reply — hence Gate A, Gate B on every `silence`, and lower confidence on interrupted turns.

## Appendix D. ElevenLabs Scribe v2 (decision 2026-10-01)

Jody ran https://www.youtube.com/watch?v=xh9D0oLxwQg through ElevenLabs on 2026-10-01 and got a diarized transcript from the URL alone (`docs/samples/xh9D0oLxwQg.elevenlabs.srt.txt`, local only). ElevenLabs was the only verified API taking a YouTube URL directly with diarization.

| | |
|---|---|
| Format | SRT-style: `HH:MM:SS,mmm --> HH:MM:SS,mmm [Speaker N]`, then text, blank line |
| Duration | 56 min |
| Segments | 942, mean 3.1 s |
| Speakers | 2, balanced (467 / 475 segments) |
| Short segments (< 1.5 s) | 356 (38%): interjections and crosstalk are kept as their own segments |

API shape (verified against the speech-to-text docs): `POST` with `source_url` (accepts YouTube and TikTok URLs directly; `cloud_storage_url` is deprecated), `model_id`, `diarize: true`, `num_speakers` (≤ 32), `timestamps_granularity: word | character`, `webhook: true` for async, `additional_formats` (e.g. SRT). Response words carry `text`, `type` (`word | spacing | audio_event`), `start`, `end`, `speaker_id`, `logprob`. Limits: 2 GB via URL, 5 GB upload.

Consequences recorded at the time: ingest v1 is one Req call; the transcript schema stays provider-neutral so a fallback lands in the same tables; pasted SRT goes through the same turn builder; speaker naming is still required (labels are `Speaker 0/1`); short-turn hygiene (§9.1) is mandatory before any avoidance detection.

**First API test (2026-10-01).** `BUm39a7diTU` ("Redeemed Zoomer + JesusandWhatnot", 89.5 min), `scribe_v2`, `source_url`, `diarize`, word timestamps, no keyterms. Attempt 1: 400, "Failed to download the file from the provided URL (upstream status 400)", returned in 0 s. Attempt 2, identical: 200 in 82 s, synchronous. 18,196 words, 2 speakers (10,521 / 7,675 words), 20 audio events, `eng` p = 0.99, `transcription_id` `gpMmyvnowJ2sXf1pvP1Z`. The opening line names both participants, but the handle of the other speaker, Redeemed Zoomer (`speaker_0`, who opens the video), came back as a similar-sounding personal name. Jesus and Whatnot is `speaker_1`. The API key is restricted: `GET /v1/models` returns `missing_permissions`; speech-to-text is permitted. Raw JSON kept locally at `tmp/elevenlabs/BUm39a7diTU.json` (gitignored).

The web app's YouTube tab exposes the same options as the API: tag audio events (`tag_audio_events`), include subtitles (`additional_formats`), no verbatim (`no_verbatim`), assign speakers from library (`use_speaker_library`; not used, §3), keyterms (`keyterms`).

Other samples measured later the same day: `RwoZn83IHgo` (590 segments, 3 labels, one used once), `UaC-gqcT7JI` (155 segments, 2 labels), `cPVtaKPLC9Q` (804 segments, 5 labels for 4 people).

`docs/samples/normalize_probe.py` is the throwaway script used to size §9.1; it is not app code. It is a reference only: it records how the manual pass was done.

## Appendix E. Comments and sentiment (2026-10-01) — deferred past M5

**Comments.** Primary: Data API v3 `commentThreads.list` (`part=snippet,replies`, 100/page, `order=relevance|time`), 1 unit/call, 10,000 units/day default (~1M comments/day); public comments need only an API key. Replies capped at 5 per thread inline; `comments.list?parentId=` for the rest. Fallback: `youtube-comment-downloader` (Python, 1.3k★, keyless InnerTube scraping). Do not add Hex `google_api_you_tube` 0.54.0 (repo archived 2026-06-30) or `yt_potion` 1.0.0 (no `commentThreads`).

**Sentiment and stance, tiered:**

0. `afinn` 0.3.0 (the only maintained Elixir lexicon) — triage spam/emoji/neutral before spending tokens. `veritaserum` (2020) and `sentient` (2015) are dead.
1. 3-way polarity on every comment: Airo `classify` against an Infinity deployment of `cardiffnlp/twitter-roberta-base-sentiment-latest` (preferred; needs a classify deployment added in Airo admin), or in-process Bumblebee 0.8.0 + EXLA 1.0 CPU (~20–40 comments/s on 4 vCPU, ~1 GB RAM).
2. Stance + tactic call-outs via `AiroClient.chat/2`, ~25 comments per prompt: `{comment_id, stance: pro_A|pro_B|neutral|unclear, tactic_tags, quoted_span, confidence}`. ~80 calls per 2k-comment video; ≈ $0.03/video on a gpt-4.1-nano-class model.

Off-the-shelf stance models (TweetEval stance, xstance, targeted-sentiment) are trained on fixed targets and do not know our debaters.

**Why deferred.** Comments are useful for (a) crowd-flagged tactic call-outs with quotes and timestamps and (b) clip/shorts density as "the moment viewers thought decided it". Known biases: comment sentiment tracks prior allegiance; a home-channel crowd skews to the host. Nothing from comments may feed a pattern claim until a de-biasing scheme is tested.

## Appendix F. Graph store (2026-10-01)

Apache AGE rejected: for PG17 it is at 1.7.0-rc0 (2026-02-11); 1.8.0 has not reached PG17; no Ecto adapter (`agex` dead since 2020, `ash_age` is Ash-only); every connection needs `LOAD 'age'`; agtype parsing is hand-rolled. The extension lifecycle is tied to PG majors and buys only Cypher syntax not needed at tens of thousands of edges. The incogito `Incogito.Graph` shape is shared by media_assist and orchester. For in-memory analysis: `libgraph` 0.16.0 or OTP `:digraph`.

## Appendix G. Decision log

| date | decision |
|---|---|
| 2026-10-01 | Name: **Topoi** (Aristotle's catalog of argument patterns; names the atlas, not the person). Collision pass: Hex package `topoi` free; GitHub `JobyCorp/topoi` free (user `topoi` exists; two 2★ humanities repos share the name; no software product found); `topoi.app/.io/.dev/.ai/.com` registered by others; `topoi.so` inconclusive; `topoi.gg` unregistered at the check and **registered by jody on 2026-10-01**. Public host via Cloudflare Tunnel like joby.gg and incogi.to (to be confirmed in this repo's `## Prod`). |
| 2026-10-01 | Transcription: ElevenLabs Scribe v2 primary; no Python service in v1; self-hosted WhisperX chain deferred (Appendix C, D). |
| 2026-10-01 | Graph: plain Ecto tables, no Apache AGE (Appendix F). |
| 2026-10-01 | M1 executed by hand for one debater and four videos instead of three debaters × 8–12 videos. All three original claim types were substantiated at n = 4; the design finding was a fourth claim type, the destination row. The remaining two debaters move to M3 with the pipeline in the loop. |
| 2026-10-01 | Repo created at `~/Work/topoi`, published as `jodyalbritton/topoi`; the `debate-dossier/` working directory is superseded. Sample transcripts and hand-built dossiers stay local (gitignored). |
| 2026-10-01 | v0.4: product framed as a public atlas with a private prep layer; data model is relational tables plus a derived graph index; PRD restructured into spec + research log. |
| 2026-10-01 | Routes: "persona" renamed to "debater" everywhere; debater pages stay at the root (`topoi.gg/<handle>`) behind the reserved-slug rule; the debater-scoped debate page moves from `/:persona/debates/:debate` to `/debates/:debate/:debater`, so each debate has one canonical URL tree. |
| 2026-10-01 | Taxonomy (§3.1): topics = what is argued, tags = how, schools = traditions (many per debater, human-set), positions (theist, atheist, …) = per-debate participant attribute and filter, not a school. One slug namespace with an aliases table; no free-form tags. Topics become a cross-debater table; per-debater arguments link to them. |
| 2026-10-01 | Tags are one-word neutral style descriptors (Socratic, citational, deferring, …) computed from move and tactic rates, curated, never verdicts. Moves and tactics are the internal analysis vocabulary, not a section. Topics cover anything argued about, including figures (Ayn Rand) and events (Fatima); a figure's tradition is a school (Objectivism). The "Tags → Moves" rename is dropped. |
| 2026-10-01 | Tags are earned per performance (participant in one debate) and roll up to the debater as "n of m debates". Debates carry topics, not tags. |
| 2026-10-01 | Tags are computed only. Humans change tags only through evidence corrections (Gate B) or logged rule changes applied to everyone; no per-debater hand edits, to avoid bias. |
| 2026-10-01 | General rule "suggest, then confirm; never author" (§6) for every label: speaker map, positions (from resolution side or stated stance), schools (only from on-record self-identification), topics (only via linked arguments), moves, tags, opponent clusters (computed from move profiles). The private counter library is the only authored content. |
| 2026-10-01 | Videos are canonical: identity is `(platform, platform_video_id)`, submit is idempotent, and a video is sent to ElevenLabs once regardless of how many debaters appear in it (§8.1). |
| 2026-10-01 | ElevenLabs API verified on `BUm39a7diTU`. Requests carry keyterms built from expected debaters' names, aliases, and terms plus school vocabulary; `no_verbatim` fixed off; synchronous call by default, webhook as fallback; transient upstream-download 400s retried (§8.2). |
| 2026-10-01 | No voice prints or speaker biometrics of any kind (enrollment, embeddings, ElevenLabs speaker library, Speaches known speakers): debaters have not consented. Identity comes from the record plus Gate A (§3, §9.2). Personal names are kept out of this document; they may appear in transcripts. |
| 2026-10-01 | Start without a YouTube Data API key: metadata from oEmbed + ElevenLabs; YouTube `published_at` entered at Gate A until a key is added before M3 (§7). |
