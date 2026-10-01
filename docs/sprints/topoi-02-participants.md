# topoi-02-participants

Status: **closed** (plan accepted 2026-10-01; accepted and squash-merged 2026-10-01) · branch `topoi-02-participants` · opened 2026-10-01

## Goal

Speakers get names, through suggest-then-confirm. Pipeline stage 3 and Gate A (PRD §8, §9.2, §10.1, §13): the first LLM work. After normalization, the system suggests who each raw speaker label is, their role and position, and which labels are one person, each with a quoted, timed piece of evidence. An admin confirms or rejects every suggestion; nothing is typed from scratch (§6).

Done when the three debates in the library can be taken through Gate A in the admin UI, and the formal debate `cPVtaKPLC9Q` (from the local sample) comes out as 5 labels → 4 people with the fifth label merged into the Thomist (PRD §14).

## Slices

| # | slice | acceptance |
|---|---|---|
| 1 | **AI gateway**: `airo_client` dep, gateway settings row (base URL, encrypted key, chat and embedding model aliases), `/admin/gateway` form with a connection test | key write-only like ElevenLabs'; "Test connection" lists the gateway's models or shows the error in plain words; `Topoi.AI.Gateway.chat/2` returns `{:error, :not_configured}` when unset; overview shows real state |
| 2 | **LLM call log**: every gateway call recorded (`llm_calls`: purpose, prompt version, model, request, response, latency, outcome) | each suggestion links to the call that produced it; JSON-schema responses validated before use; failures stored, not raised |
| 3 | **Suggestions and decisions schema**: `participant_suggestions` (raw label, role, name as stated, matched debater, position, merge-with label, evidence quote, evidence time, call id) and confirm/reject records with reason, actor, time | a suggestion is never edited; a decision references it; a participant's confirmed values point back to the suggestion they came from |
| 4 | **Positions vocabulary**: curated `positions` (theist, atheist, agnostic, deist, …) | seeded list; suggestions outside it are rejected by code |
| 5 | **Propose** (`Participants.Propose`, prompt §10.1): first 5 minutes of turns + title and channel → per-label suggestions | Oban `participants` queue chained after normalize; quote must appear in that label's turns (else dropped and logged); stated names matched to debater names and handles by code, not by the model; `enable_thinking: false` for local Qwen |
| 6 | **Merge hints** (code): labels whose turns continue another label's cut-off sentence, a label with very few turns inside another's monologue, a label that only appears in a closing | hints shown beside the model's `merge_with`; on `cPVtaKPLC9Q` the fifth label is flagged as part of the Thomist |
| 7 | **Video facts by suggestion**: format and channel of record suggested (channel of record by matching the channel to debater handles in code); `published_at` entered at Gate A while there is no YouTube key | each fact confirmable with its evidence; the date is the one typed field, because no source exists yet (PRD §7) |
| 8 | **Gate A screen**: `/admin/debates/:id/speakers` | per label: suggestion, evidence quote with timecode, a few sample turns; confirm, reject with reason, confirm a merge; the video moves to "Speakers confirmed" only when every label is decided |
| 9 | **Pipeline status**: new statuses (speakers suggested, speakers confirmed); "Needs review" count on the overview and debates list | statuses update live; rejected suggestions can be re-proposed |
| 10 | **Close-out**: real runs on the three library debates and `cPVtaKPLC9Q` | `mix precommit` green, lint clean; §14 merge row met; Gate B-style notes on what the model got wrong; PRD and this doc updated |

## Out of scope

Move tagging (stage 4), pushbacks, lines, school membership suggestions (needs self-identification across turns beyond the first 5 minutes; stage 4 or later), voice of any kind (PRD §3: no biometrics), public pages.

## Needs from Jody

- An Airo client key, entered at `/admin/gateway` once slice 1 lands.
- Which model sits behind the chat alias for this work (local Qwen or hosted). The prompt is built for JSON-schema output either way.

## Risks

- Model quality on short turns and silent moderators (PRD Appendix C): the evidence-quote check and Gate A catch it; the close-out records how often.
- `cPVtaKPLC9Q` exists only as a hand SRT; it is imported as a paste for the merge test, so its word timings are interpolated.

## Close-out

**Shipped.** `mix precommit` green (238 tests), `mix joby_kit.lint` clean.

| # | slice | result |
|---|---|---|
| 1 | AI gateway | `airo_client` dep; encrypted, write-only key at `/admin/gateway`; connection test lists models by capability; `Topoi.AI.Gateway.chat/2` (strict JSON schema, thinking off) |
| 2 | LLM call log | `llm_calls`: purpose, prompt version, request, answer, served model, latency, outcome; failures logged, never raised |
| 3 | Suggestions and decisions | one `suggestions` table (identity, position, merge, format, channel of record) + `suggestion_decisions`; only a confirmation changes the record; a rejection needs a reason; Gate A completes when nothing is pending and every label has a confirmed identity or merge |
| 4 | Positions | seeded: theist, atheist, agnostic, deist, undeclared |
| 5 | Propose | prompt `participants-v4`; every quote checked against the turns or the title/channel lines; names linked to debaters by code; the model never sees debater records |
| 6 | Merge hints | rule: a label that picks up another's cut-off sentence while that one is silent; finds exactly the `cPVtaKPLC9Q` split and nothing in the other three samples |
| 7 | Video facts | candidate debater links from expected debaters and the channel name; channel of record from the channel; publish date typed at Gate A |
| 8 | Gate A screen | `/admin/debates/:id/speakers`: suggestion cards with evidence (model quotes in quotation marks, rule reasons as plain text), confirm, reject with reason, suggest again |
| 9 | Pipeline status | "Speakers to review" / "Speakers confirmed"; overview lists debates that need review; live updates |
| 10 | Close-out | real runs below; Gate A decisions are Jody's |

**Real runs (2026-10-01, `participants-v4`, chat alias → Qwen3.8-Flash-Next, ~5 s per debate).**

| debate | result |
|---|---|
| `BUm39a7diTU` | Both speakers right. The guest is linked to Jesus and Whatnot from "AKA Jesusandwhatnot". The host's handle was misheard by ASR ("Nadeem Zumer"); the rule's candidate link (expected debater) offers Redeemed Zoomer. |
| `UaC-gqcT7JI` | Nobody states Jesus and Whatnot's name in the opening; the rule offers him for both labels (expected debater + his channel). Host/guest is ambiguous in the transcript (his upload of someone else's live). |
| `cPVtaKPLC9Q` (hand SRT, imported as a paste) | All five labels covered. Rule and model both find speaker_4 = speaker_1 (PRD §14 merge row). The model also proposes a wrong merge (speaker_0 → speaker_3, two different moderators) for Gate A to reject. |

**What the model got wrong, and what changed because of it.**

- v1 dropped every claim on `UaC-gqcT7JI`: quotes stitched with "…" and "Channel:" evidence did not match → v2 checks each excerpt and the header lines.
- v2 named a speaker "Proud atheist" → v3 defines a name as a proper name or handle.
- v3 linked a moderator to a debater because the moderator's quote mentioned the handle → v4 links from a quote only when the model claims a name for that speaker.
- v3 never saw speakers who start after five minutes (formal opponent, timekeeper) → v4 adds their first lines.
- Format: "podcast" for two live debates; "moderated formal" right for the formal debate. Left to Gate A.

**Gate A redesign (after use).** The suggestion-card flow (confirm or reject each suggestion) proved unclear in use: no instructions, no sense of what a rejection did, conflicting confirmations possible, merged labels still asking for their own identity. Gate A is now a form: one block per speaker (who, role, side) pre-filled from suggestions with a one-line reason, typed names for people without a debater record, "Same person as …", "Can't tell", the debate's facts, and one "Confirm speakers" that checks the form and says what to fix. PRD §6 records speaker labels as the one exception to suggest-then-confirm. Supporting changes kept: one answer per slot, merges settle a label, start over keeps history (suggestion level).

**Gate A results (Jody, 2026-10-01).** All three debates have speakers confirmed. `cPVtaKPLC9Q`: 5 labels → 4 people, but grouped differently from the gold dossier — speaker_3 confirmed as the same moderator as speaker_0, speaker_4 left as "can't tell". speaker_4 holds two people: the Thomist's closing (1:19:14) and moderator-style lines (1:24:55). A label-to-person map cannot express that; per-turn reassignment is a follow-up.

**Added during the sprint.** Candidate debater links (slice 7 grew to cover what the model cannot see: expected debaters and the channel). `quiet_link` and `suggestion_card` components.

**Follow-ups.**

- Per-turn speaker reassignment for labels that hold two people (`cPVtaKPLC9Q` speaker_4).

- Restart the dev server so the new `participants` Oban queue runs (until then, "Suggest again" queues jobs that wait; the real runs above called the proposal directly).
- `airo_client` fix for the Req 0.7 `decode_json` warning is on branch `fix-req-decode-json-deprecation` in that repo, unpushed, awaiting Jody.
- Debater record for Nate.FM does not exist; his label is suggested without a link.
- School membership suggestions (self-identification across the whole debate) move to the tagging sprint.
