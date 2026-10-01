# Topoi (working title until 2026-10-01: Debate Dossier) — PRD

Status: draft v0.3 · 2026-10-01 · owner: Jody

## 1. One-liner

A prep tool that ingests a debater's public debates (YouTube/web transcripts) and builds a per-debater dossier of their habitual moves — what they open with, what they dodge, how they counter — with short-circuits prepared for each.

## 2. Problem

Jody consumes a lot of debate content and observes that individual debaters run highly repetitive toolboxes (e.g. a Thomist who consistently sets the bar at the outset with the five ways). Counter-debaters who spot such a pattern and short-circuit it up front are noticeably more successful. Human memory tracks only the pushbacks *he remembers giving*; it cannot enumerate everything an opponent was ever offered and what happened next. No existing tool does this (see §8).

## 3. What this is / is not

- **IS** a scout: an indexed record of one opponent's recurring habits, for preparation.
- **IS NOT** an opposition simulator — no persona simulation of Debater X.
- **IS NOT** a debate-outcome adjudicator — pattern-spotting, not win/loss scoring.
- **Scope rule (2026-10-01):** the record covers **public debate performances** only, and a dossier may state only what is observable in a cited performance. How a debater presents ideas is in scope — interruptions, deferrals, tone policing, replaying an opponent's word, status attacks — because it is on the record with a timestamp. Anything not sourced from a performance is out: appearance, private life, biography, and character verdicts ("is a liar") as opposed to observed conduct ("asserted X at 21:25, contradicted at 48:06"). Enforcement is mechanical, not editorial: a statement with no span citation cannot be published (§6).
- **IS NOT** primarily a tactic taxonomy — school-level patterns (Thomist, etc.) are a secondary lookup providing priors and known stock counters; the unit of analysis is the individual debater.

## 4. Primary artifact: the dossier

Three claim types, each a distinct detector:

1. **Openings** — "Debater X more often than not opens with these arguments." Positional frequency over turn index. Easy.
2. **Counters** — "Debater X will counter you like this." Requires pairing: (trigger move offered → their reply type), cross-tabbed over the corpus; interesting rows are recurring trigger→response pairs. Medium.
3. **Avoidances** — "Debater X always avoids this pushback." Avoidance is a negative observation: what follows the pushback over N turns. Must distinguish ≥4 behaviors, because each needs a different counter:
   - concede-and-move-on → bank it, escalate elsewhere
   - reframe/redefine → name the reframe
   - pivot to another argument → hold the line, force the answer
   - silence (never returns) → hold and force the answer
   Hard, most valuable, easiest to destroy by sloppy labeling.

Each dossier entry shows **both rates side by side**: the individual's own frequency and the school's base rate (partial pooling — the interesting cell is the delta; own-data overrides the prior only as evidence accumulates).

## 5. Inputs

- YouTube debate videos (transcript via ASR; captions where available).
- Web transcripts / pasted text.
- Multiple debates per debater, across various opponents.
- Small-n by design: one debater ≈ 10–60 videos. This is a personal prep tool, not a statistics product.

## 6. Signal & evidence rules

- **Every tag cites its utterance span** (jump to timestamp). No unsourced classifications.
- **Move vocabulary is a small closed set grown from the corpus**, not Walton's full scheme catalog (fine-grained classification into large taxonomies drifts — cf. NAACL 2025 label-variation work). Walton/argumentation-scheme names are used as labels for known moves and as a source of stock critical questions (= pre-existing short-circuits) at the school level.
- **Count all offers, not just instances.** "He avoids X" only means something against a census of every time X was offered.
- **Perceived winner: out of scope as ground truth.** Comments read for (a) crowd-flagged tactic callouts with quotes/timestamps (free annotation), (b) cautiously, clip/shorts density as "moment viewers thought decided it." Known biases: comment sentiment tracks prior allegiance; home-channel crowd skews to the host. Never fed into pattern claims without a tested de-biasing scheme.
- **Identity merge** (same debater across channels/handle variants, and diarization "Speaker 2" → name) is a launch-blocking correctness concern, not a v2 nicety.

## 7. Architecture sketch (pipeline)

1. Ingest: download / fetch transcript or text
2. Diarize + timestamp (proven prior art: WhisperX)
3. Merge pass: multiple ASR passes → canonical text (cf. multi-source transcript merging)
4. Segment into moves/turns; classify into closed move vocabulary with span citations
5. Store: debater ⇄ move ⇄ trigger ⇄ opponent ⇄ video graph (the "graph" from the original idea — a record, not the product)
6. Dossier view per debater: openings / counters / avoidances with individual-vs-school rates
7. Counter library: short-circuits keyed to move types; school-level stock counters (critical questions) pre-seeded, personal counters authored by Jody and attached to findings.

## 8. Landscape (verified 2026-10-01 against GitHub/arXiv/Wikipedia APIs; search-engine endpoints were bot-walled)

- **Nothing ships this.** Closest: `Zing302/Debate_LD_Prep` — "Opponent Scout" with loss-pattern analysis, but 0★, dormant (last push 2026-04-11), and confined to competitive HS debate where cases are *disclosed* on OpenCaselist (public record; no improvisation to mine). Public intellectuals don't disclose — the pattern is realer here and the software absent.
- `latent-variable/FallacyScoreboard` (29★, dormant 2024-08): YouTube → WhisperX + diarization → LLM fallacy tags → scoreboard overlay. A scoreboard, not a scout: per-utterance, no memory across videos. The ingestion pipeline is largely solved prior art.
- `latent-variable/Real_time_fallacy_detection` (119★): live per-segment fallacy classification. Same limitation.
- Map tools (Kialo, debate-map.app, Argdown, Rationale, CmapTools): graphs you draw yourself; no opponent model, no counters.
- Counterargument research (PTCG persona-guided counterargument trees, arXiv 2609.07120; Conch competitive-debate clash-point visualization, 2025-07; PAKT perspectivized argumentation KG, 2024-04): generates or visualizes; none tracks an individual's habits over real transcripts with an avoidance detector.
- Multi-agent-debate boom (`llm_multiagent_debate`, ChatEval, etc.): about improving answers, not modeling an adversary.
- Academic ancestry to steal from: Walton argumentation schemes + critical questions (names & stock short-circuits); pragma-dialectics discussion stages (opening-stage moves — *when* a counter must fire); intelligence-analysis ACH (hypothesis × evidence matrix); security attack-graph countermeasure selection (set-cover: which single short-circuit kills most of a school's lines).

## 9. Milestone 1 (no UI, no model — the falsification pass)

Pick 3 debaters Jody has genuinely watched, 8–12 videos each. **Hand-build the dossiers** with a self-invented move vocabulary. Output: three dossiers + a tagging log.
Purpose: discover which of the three claim types cannot actually be substantiated from the record as understood — that one is the real design finding — and produce a gold set to grade any later classifier against. If the pattern claim is real, 24–36 videos will show it.

**Status 2026-10-01:** executed by hand for **one debater, four videos** (`docs/dossiers/`), not three debaters. All three claim types were substantiated at n=4, so the design finding was not a missing claim type but a fourth one: the **destination row** (§14.8), the invariant terminal of every formulation and the premise the debater relocates to under pressure. The four per-video dossiers plus `docs/dossiers/thomist.md` are gold set #1. The remaining two debaters move to Milestone 3 (§14.10) and are tagged with the pipeline in the loop, not by hand.

## 10. Open questions

- Move vocabulary: how small is stable? (target ≤ ~15 types for v1)
- Avoidance over how many turns counts as "avoided"?
- Identity merge policy and manual confirmation UX
- School assignment: manual tag per debater? multiple schools?
- Counters: authored only, or LLM-drafted from the scheme's critical questions and then curated?
- Bias rule for the uneven corpus (we watch debates where our side does well) — what entry hygiene counters retrospective pattern-finding?
- ~~Name collision check done for "Debate Dossier"?~~ **Resolved 2026-10-01: the app is `topoi`** (Aristotle's catalog of argument patterns; names the atlas, not the person). Collision pass same day: Hex package `topoi` free; GitHub `JobyCorp/topoi` free (user `topoi` exists; two 2★ humanities repos share the name; no software product found by web search, results are dominated by the mathematical "topos"); domains `topoi.app/.io/.dev/.ai/.com` registered by others, `topoi.gg` was unregistered at the check and **jody registered it on 2026-10-01**; `topoi.so` inconclusive. Public host: `topoi.gg` (Cloudflare Tunnel like joby.gg and incogi.to; no Traefik, no `joby.gg` subdomain — to be confirmed in this repo's `## Prod` when the app exists). Mix app `topoi`, OTP app `:topoi`, root module `Topoi`, repo `~/Work/topoi`. The repo was created at `~/Work/topoi` on 2026-10-01; the `debate-dossier/` working directory is superseded.

---

## 11. Product surface addendum (v0.2 · 2026-10-01)

Elevator pitch: *paste transcripts, paste YouTube URLs, add notes, define the opponent; the app collects and analyzes the sources, spots patterns, reviews comments and sentiment, and gives feedback about the debater's arguments and how they are presented, from the cited record.*

User-facing inputs (all first-class records, not one-offs):

- **Paste a transcript** — raw text, optional speaker labels, optional source URL.
- **Paste a YouTube URL** — triggers the ingest pipeline (§12.1–12.2) as background jobs; the UI shows per-stage status.
- **Add notes** — free-text annotations attached to a debater, a video, or an utterance span.
- **Define the opponent** — a debater record: canonical name, aliases/handles (feeds identity merge, §6), school tag(s), and the counter library entries authored against them.

Outputs: the dossier (§4), a per-video comment/sentiment review (§12.3), and a feedback summary of the debater's arguments and presentation, drafted by the LLM from tagged spans only and curated by Jody. Persona gate: a debater record is created only when the pipeline holds N public debate performances (N is a setting, default 3); every video carries a `format` attribute (tiktok_live, youtube_debate, moderated_formal, podcast) so rates split by platform.

## 12. Tooling research (verified 2026-10-01 against hex.pm, GitHub API, fleet repos)

Built as a standard JobyCorp Phoenix app: Phoenix 1.8 / LiveView 1.2, JobyKit 0.3 + daisyUI, Postgres 17 + pgvector, Oban queues, Req behind a client module, singleton settings rows edited in the admin UI (no env-var config), phx.gen.auth username login as in incogito. Bootstrap with `mix joby_kit.new topoi --binary-id --no-mailer`.

### 12.1 YouTube transcripts

Nothing in the fleet handles YouTube today (grep of incogito, helm, media_assist, vox, bardo; YouTubePilot is script notes, not code).

| Option | Status (2026-10-01) | Verdict |
|---|---|---|
| **yt-dlp** `--skip-download --write-subs --write-auto-subs --sub-langs en --sub-format json3` | 194k★, release 2026.08.19, pushed 2026-09-27 | **Primary.** Called via `System.cmd` from an Oban worker, concurrency 1, cached by video id. Install with `uv tool install yt-dlp`; weekly `yt-dlp -U` (YouTube breaks old versions within weeks). |
| youtube-transcript-api (Python) | 8.4k★, v1.2.4; cookie auth officially disabled; `PoTokenRequired` (issue #592) has no workaround; ~30 fetches from a home IP before `IpBlocked` | Fallback only, via Pythonx or `System.cmd`. |
| Hex: `youtube_captions` 0.1.0 (2023), `youtex` 0.2.0 (2021) | Pre-date the 2025–26 PO-token changes | Assume broken. Skip. |
| Hex: `exyt_dlp` 0.1.6 | 3★ thin `System.cmd` wrapper | Write our own ~30-line module instead. |
| Data API v3 `captions.download` | Needs owner OAuth on the video, 200 units | Useless for third-party videos. |

**ASR fallback** (no captions, or caption track returns empty body): `yt-dlp -x` audio → ffmpeg 16 kHz PCM → one of:

- `AiroClient.transcribe/3` with model alias `"whisper"` — Airo already fronts Speaches (faster-whisper) at `POST /v1/audio/transcriptions`. **Verify a Speaches deployment is live first**: Orchester's service registry lists no Speaches service as of 2026-10-01.
- `whisper_cpp` 0.5.0 / `whisper_ct2` 0.7.0 Hex NIFs (rubas, hex 2026-09-23, 0★, needs Elixir 1.19) — in-process, Metal/CUDA, segments + word timestamps, **no diarization**.
- Bumblebee 0.8.0 `speech_to_text_whisper` — mature, slower, no diarization.

**Diarization gap.** PRD §7 assumes WhisperX. Neither YouTube captions nor any Elixir-native ASR path produces speaker labels; WhisperX (24k★, pyannote, needs HF token) is a Python sidecar. For 2–3 speaker debates the cheaper first attempt is LLM speaker attribution over the timestamped transcript (names are known from the "define the opponent" record). Promote to a WhisperX sidecar only if Milestone 1 shows text-only attribution fails. This decides whether the app has a Python service at all.

### 12.2 YouTube comments

| Option | Status | Verdict |
|---|---|---|
| **Data API v3 `commentThreads.list`** (`part=snippet,replies`, 100/page, `order=relevance\|time`) | 1 unit/call, 10,000 units/day default → ~1M comments/day; public comments need only an API key (Cloud Console → enable YouTube Data API v3 → Credentials → API key, no OAuth) | **Primary.** ~40-line Req module. Replies capped at 5 per thread inline; `comments.list?parentId=` for the rest. Key stored encrypted in a settings row. |
| youtube-comment-downloader (Python) | 1.3k★, pushed 2026-07-30, 0 open issues, keyless InnerTube scraping | Fallback for quota exhaustion or comments-disabled errors. |
| Hex `google_api_you_tube` 0.54.0 | Repo **archived 2026-06-30** | Works today, dead. Do not add. |
| Hex `yt_potion` 1.0.0 (2026-07) | Read-only search/videos/channels, no `commentThreads` | Skip. |

### 12.3 Sentiment and stance

No Bumblebee/EXLA/sentiment code exists in the fleet; classification currently goes through Airo `POST /v1/classify` (Infinity). Polarity alone does not answer the PRD's question (§6: who does the commenter side with, which tactic do they call out). Tiered plan:

0. **`afinn` 0.3.0** (hex 2025-11-25, the only maintained Elixir lexicon) — triage spam/emoji/neutral before spending tokens. `veritaserum` (2020) and `sentient` (2015) are dead.
1. **3-way polarity on every comment**, either Airo `classify` against an Infinity deployment of `cardiffnlp/twitter-roberta-base-sentiment-latest` (preferred, zero new deps; the Infinity embed server on pve2gpu exists, a classify deployment would need adding in Airo admin), or in-process Bumblebee 0.8.0 + EXLA 1.0 CPU serving (~20–40 comments/s on a 4-vCPU VM, ~1 GB RAM).
2. **Stance + tactic call-outs via `AiroClient.chat/2`** with `response_format: json_schema`, batched ~25 comments per prompt with the debater list and move vocabulary injected: `{comment_id, stance: pro_A|pro_B|neutral|unclear, tactic_tags, quoted_span, confidence}`. ~80 calls per 2k-comment video; negligible cost on local models, ≈$0.03/video on a gpt-4.1-nano-class model. Send `chat_template_kwargs: {enable_thinking: false}` on local Qwen models (mem_pal lesson) or `content` comes back nil. This tier is the one that feeds §6(a) crowd-flagged tactic callouts.

Off-the-shelf stance models (TweetEval stance, xstance, targeted-sentiment) are trained on fixed targets and do not know our debaters; not worth integrating.

### 12.4 Graph in Postgres

Decision: **plain Ecto node/edge tables, no Apache AGE.**

- Apache AGE for PG17 is at 1.7.0-rc0 (2026-02-11); 1.8.0 has not reached PG17; no Ecto adapter (`agex` dead since 2020, `ash_age` is Ash-only); every connection needs `LOAD 'age'`; agtype parsing is hand-rolled. The extension lifecycle is tied to PG majors and buys only Cypher syntax we do not need at tens of thousands of edges.
- Reuse the fleet pattern: incogito `Incogito.Graph` (`graph_entities(type, name, metadata)` + `graph_edges(edge_type, source_id, target_id, weight, confidence, metadata)`, unique on `(source, target, type)`, `no_self_edges` check, `WITH RECURSIVE` traversal via `Ecto.Query.with_cte` + `recursive_ctes(true)`). media_assist and orchester carry the same shape.
- Node types: `debater`, `video`, `utterance_span`, `move`, `trigger`, `school`, `counter`, `note`. Edge types: `spoke` (debater→span), `opened_with`, `countered_with` (trigger span→reply span), `avoided` (trigger span→behavior label), `opposed` (debater↔debater per video), `belongs_to` (debater→school), `short_circuits` (counter→move). Every tagging edge carries `span_start_ms`/`span_end_ms` in metadata (§6 citation rule).
- Dossier queries are 1–4 fixed hops → joins, not recursion. Borrow mem_pal's `supersedes_id` + `dedup_key` for re-tagging corrections.
- In-memory analysis when needed: `libgraph` 0.16.0 (stable, 571★) or OTP `:digraph`.

### 12.5 Airo integration

- Dep: `{:airo_client, git: "git@github.com:JobyCorp/airo_client.git", branch: "main"}` (no Hex release; `main` is prod). Consumers: incogito, orchester, mem_pal, joby, media_assist.
- House pattern: a `GatewaySettings` singleton (base_url `https://llm.local.joby.gg` without `/v1`, Cloak-encrypted key, model aliases `chat`, `chat-deep`, `embed-fast`, `classify`, `whisper`) behind a `Topoi.AI.Gateway` wrapper that returns `{:error, :not_configured}` when unset. Cleanest reference: `media_assist/lib/media_assist/ai/gateway.ex`.
- Calls used here: `chat/2` (move classification with span citations, stance tier, feedback summary draft), `embeddings/2` (span similarity for "this trigger was offered before"), `classify/2` (polarity), `transcribe/3` (ASR fallback).
- Tests stub via `Req.Test` plug in `req_options`; Oban `testing: :manual`.

### 12.6 Web search (SearXNG)

Exists three times already (incogito `Incogito.Search` + `Search.Providers.SearXNG`, helm `Helm.Search`, orchester `Orchester.Search`), each a small Req client: `GET {base_url}/search?q=…&format=json`, normalized to `%{title, url, snippet}`. Base URL `searxng.local.joby.gg` (Traefik on pve2gpu), stored per app in a settings row. Copy incogito's provider-behaviour version. Use: find more debates for a debater (seed the corpus), locate web transcripts for pasted URLs.

### 12.7 Bot-walling note

Datacenter IPs are blocked on reputation before cookies are checked; PO tokens are per-video and manual extraction is discouraged. The target VM sits on a residential line, which sidesteps the IP block. Remaining risks: per-IP rate limiting (tens of fetches per burst), `PoTokenRequired` caption tracks, 429s on auto-*translated* subs. Mitigations: single-concurrency Oban queue, `--sleep-requests`, per-video cache, keep yt-dlp current, never ship `--cookies-from-browser`. Add `bgutil-ytdlp-pot-provider` (v2.0.0, 2026-09-08, Node ≥22 sidecar on :4416) only if empty subtitle bodies appear.

### 12.8 Prior art worth reading before coding

- `NotJoeMartinez/yt-fts` (1.8k★) — yt-dlp subs → FTS + embeddings; best transcript storage model.
- `0xCaFeBEef/free-youtube-transcript-mcp` — documents a tried-in-order caption cascade (InnerTube clients → watch page → transcript panel → yt-dlp); copy the cascade.
- `thenavidm/youtube-mcp-cli` — comments via Data API, transcripts via yt-dlp; same split as above.
- `latent-variable/FallacyScoreboard` (§8) — ingestion pipeline prior art.

### 12.9 Decisions still open from this pass

- ~~Diarization: LLM attribution first, or WhisperX sidecar from day one?~~ Resolved 2026-10-01: ElevenLabs Scribe v2 primary, self-hosted chain fallback (§12.11). No Python service in v1.
- Is a Speaches deployment live behind Airo's `whisper` alias? Not in Orchester's registry. Fallback-only after §12.11.
- YouTube Data API key: create under which Google Cloud project?

### 12.10 Speaker-labeled transcripts (diarization), verified 2026-10-01

Every working tool is the same pipeline: `yt-dlp -x` → Whisper → diarization model → word/segment labels. YouTube captions never carry speaker labels (auto captions: none; `>>` markers in human captions are an unenforced broadcaster convention).

| Tool | Status | Emits | Elixir call | Caveat |
|---|---|---|---|---|
| **WhisperX** (m-bain) | 24.3k★, pushed 2026-09-26, PyPI 3.8.6 | segment + word `SPEAKER_xx` with timestamps | CLI only | gated pyannote model, HF token, <8 GB VRAM |
| **whisper-asr-webservice** (ahmetoner) | 3.3k★, 2026-08-09 | same, as JSON | `POST /asr?diarize=true&min_speakers=2&max_speakers=3&output=json` (multipart) with `ASR_ENGINE=whisperx`, `HF_TOKEN` | **easiest Req target; recommended** |
| **Speaches** (already behind Airo) | 3.7k★, 2026-09-29 | `/v1/audio/diarization` → `{start,end,speaker}` segments; accepts `known_speaker_names[]` + `known_speaker_references[]` | separate from `/v1/audio/transcriptions`; merge in Elixir | endpoint exists in code, undocumented |
| **NVIDIA Nemotron-3-Diarization** | released 2026-09-23, not gated, ≤8 speakers, 99M params | timestamps + labels, no text | library; needs thin FastAPI | best DER (AMI 9.25% vs community-1 17.0%); Ampere+ GPU |
| **WhisperLiveKit** | 11.1k★, 2026-10-01 | realtime ASR + Sortformer diarization | WS + OpenAI-compat REST | realtime-oriented |
| **whisper-diarization** (MahmoudAshraf97) | 5.7k★, 2026-08-15 | SRT/TXT with speakers, NeMo-based, no HF gate | CLI | ≥10 GB VRAM |
| **earwig** (gunn4r) | 2★, beta | YouTube URL → yt-dlp → WhisperX → LLM names speakers → Markdown | CLI | exactly this pipeline; read, don't depend |

Hosted: **ElevenLabs Scribe v2** is the only verified API taking a YouTube URL directly with diarization (`source_url`, `diarize=true`). AssemblyAI (`speaker_labels`, $0.17/hr all-in, 10 h max, content-based speaker naming), Deepgram (`diarize=true`, ~$0.26/hr), OpenAI `gpt-4o-transcribe-diarize` (`response_format=diarized_json`, ≤4 reference clips for known speakers, 25 MB/file), Mistral Voxtral (`diarize=True`, ~$0.18/hr, 3 h/request), Gemini (accepts YouTube URLs but speaker labels only via prompting). All except ElevenLabs/Gemini need yt-dlp first.

**Labels → names.** Diarization yields `SPEAKER_00`, not a debater. Two layers, use both:
1. LLM attribution from transcript content (introductions, address-by-name). Near free; fails on silent moderators/short turns.
2. Voice-print enrollment for cross-video identity (§6 identity merge): one enrolled clip per debater → mean embedding per `SPEAKER_xx` → cosine match. Open models: `speechbrain/spkrec-ecapa-voxceleb` (not gated), `pyannote/wespeaker-voxceleb-resnet34-LM` (not gated). Ready-made: Speaches `known_speaker_references[]`, OpenAI same, pyannoteAI hosted voiceprints. Could run ECAPA ONNX in-BEAM via `ortex` 0.1.10, but that is DIY.

**Accuracy limit (thesis-relevant).** Published DER, no collar, overlap scored: pyannote 3.1 11.3% on VoxConverse (YouTube talk shows/debates), 18.8% AMI; community-1 17.0% AMI; Nemotron-3 9.25% AMI / 12.73% DIHARD. Expect ~10–15% of debate audio mis-attributed, concentrated in crosstalk; errors are dominated by missed speech then speaker confusion; word-to-speaker merge adds error at turn boundaries. Two-speaker debates do materially better than 3 + moderator. **Consequence for §4 Avoidances:** a mis-attributed interruption can turn an avoidance into a reply. Milestone 1 needs a human-review step on contested turns, and the detector should ignore turns below a minimum duration.

**Decision for §12.9:** self-hosted path = yt-dlp (Elixir `System.cmd`) → whisper-asr-webservice (WhisperX) on an NVIDIA box → Speaches diarization with enrolled clips for naming → LLM names the remainder. Nothing Elixir-native exists for diarization (hex.pm: no hits for diarization/pyannote/speechbrain). The app will have a Python service; the only choice is which one.

### 12.11 Decision 2026-10-01: ElevenLabs Scribe v2 is the primary YouTube → transcript path

Jody ran https://www.youtube.com/watch?v=xh9D0oLxwQg through ElevenLabs on 2026-10-01 and got a diarized transcript from the URL alone. Sample saved at `docs/samples/xh9D0oLxwQg.elevenlabs.srt.txt`.

What the sample looks like (measured):

| | |
|---|---|
| Format | SRT-style: `HH:MM:SS,mmm --> HH:MM:SS,mmm [Speaker N]` then text, blank line |
| Duration | 56 min |
| Segments | 942, mean 3.1 s |
| Speakers | 2, balanced (467 / 475 segments) |
| Short segments (<1.5 s) | 356, i.e. interjections and crosstalk are kept as their own turns |

API shape (verified against the speech-to-text docs): `POST` with `source_url` (accepts YouTube and TikTok URLs directly; `cloud_storage_url` is deprecated), `model_id`, `diarize: true`, `num_speakers` (≤32), `timestamps_granularity: word|character`, `webhook: true` for async, `additional_formats` (e.g. SRT). Response words carry `text`, `type` (`word|spacing|audio_event`), `start`, `end`, `speaker_id`, `logprob`. Limits: 2 GB via URL, 5 GB upload.

Consequences:

- **Ingest v1 = one Req call.** `Topoi.Transcripts.ElevenLabs` posts `source_url` + `diarize` + `webhook`, stores the raw JSON, and derives turns from word-level `speaker_id` runs. No yt-dlp, no Python, no GPU box for the happy path. Key lives in an encrypted settings row like the other integrations.
- **The self-hosted chain (§12.10: yt-dlp → WhisperX → Speaches) becomes the fallback**, for cost control, private/unlisted videos, or if the `source_url` YouTube support is throttled or withdrawn. Keep the transcript schema provider-neutral (`provider`, `provider_job_id`, raw payload, normalized words/turns) so both paths land in the same tables.
- **Pasted SRT/`[Speaker N]` text** (the elevator-pitch "paste a transcript" input) parses with the same turn-builder as the ElevenLabs export, so a user who runs ElevenLabs manually and pastes the result hits the identical pipeline.
- **Speaker naming is still required.** The export says `Speaker 0/1`, not names. The LLM attribution layer from §12.10 stays; in this sample it is trivial (one speaker introduces himself as the guest within the first minute, the other is the host). Voice-print enrollment for cross-video identity is deferred until Milestone 1 shows content-based naming failing.
- **Short-turn hygiene.** 38% of segments are under 1.5 s. The move classifier (§7 step 4) should merge consecutive same-speaker segments into turns and treat sub-threshold interjections as `backchannel`, not moves, before any avoidance detection runs.
- §12.9 open item on Speaches/Airo transcription is now fallback-only, not launch-blocking.

## 13. Normalization and argument-line extraction (v0.2 · 2026-10-01)

The dossier's unit is a **line of argumentation**, not a caption segment. Provider output must pass through four layers before any detector (§4) runs. Every layer is additive: raw data is never rewritten, each layer references the one below by word index, so a span citation (§6) survives re-normalization.

### 13.1 Layers

| Layer | Unit | Produced by | Stored as |
|---|---|---|---|
| 0 | provider payload | ElevenLabs JSON (words with `speaker_id`, `start`, `end`, `logprob`, `type`), or parsed SRT/`[Speaker N]` paste | `transcripts` (provider, job id, raw jsonb) + `transcript_words` (idx, text, start_ms, end_ms, raw_speaker, logprob) |
| 1 | segment | provider's chunking | not stored separately; derivable |
| 2 | turn | deterministic merge rules (§13.2) | `turns` (video, idx, raw_speaker, first_word_idx, last_word_idx, kind: substantive\|backchannel, interrupted: bool) |
| 3 | participant → debater | per-video speaker map (§13.3) | `participants` (video, raw_speaker, role: host\|guest\|moderator, debater_id nullable, confidence, confirmed_by_user) |
| 4 | argument line + move | LLM pass with closed vocabulary (§13.4) | `argument_lines` (video, label, opened_by participant, first_turn, last_turn) and `moves` (turn, line, move_type, target_move nullable, span word range, confidence, model, prompt_version) |

### 13.2 Turn rules (sized on `docs/samples/xh9D0oLxwQg.elevenlabs.srt.txt`, 56 min, 2 speakers)

1. **Merge** consecutive same-speaker segments when the gap ≤ 4 s. A turn ends only when the other speaker holds the floor. 941 segments → 893 turns.
2. **Backchannel**: duration < 2 s, ≤ 6 words, no `?`. Flagged, kept, never a move. 256 of 893.
3. **Bridge**: if speaker A's turn is followed only by B backchannels and then A again within 8 s, that is one A turn. 893 → 518 substantive turns (258 vs 260, talk time within 7%).
4. **Interrupted**: a segment starting with `...` or ending mid-word/with `-` marks the turn `interrupted: true`. Overlap is where diarization is least reliable (§12.10), so interrupted turns carry lower default confidence into §13.4.
5. **Fillers** (`um`, `uh`, repeated starts) are 2.5% of words. Strip for display and for the classifier prompt; never from `transcript_words`. Spans cite word indexes, so stripping is a view, not a mutation.
6. **Final block.** The last caption block of an SRT-style export has no trailing blank line; a parser that requires one drops it silently. Found 2026-10-01 on video 3, where the dropped block held the only stage-2 completion in the corpus. Parse on block start, not block end, and assert `segments == count of speaker tags`.

Resulting distribution: median turn 15 words / 3.3 s, 12 turns over 80 words, max 68 s. Argument content starts at 55 s (first turn > 40 words). Thresholds live in a settings row and are re-derived as samples accumulate; they are not constants in code.

### 13.3 Speaker labels

- Provider labels are **per video and arbitrary** (`Speaker 0` is the host in this sample; the next video may invert it). They are stored as `raw_speaker` and never renamed in place.
- **Participant resolution**, in order: (a) LLM over the first 5 min of turns plus video title/description/channel → `{raw_speaker, role, likely_name, evidence_quote}`; (b) match `likely_name` against debater aliases (§6 identity merge); (c) show the proposed map in the ingest UI with the evidence quote; Jody confirms or corrects, which sets `confirmed_by_user`. Detectors only run over confirmed maps.
- In this sample (a) is trivial: one speaker self-identifies as a Thomist and names his channel's purpose inside the first four minutes; the other refers to "my panel" and "my channel". Voice-print enrollment (§12.10) is the fallback when content gives no name.
- A debater may appear under different `raw_speaker` values across videos; the dossier joins through `participants.debater_id`, never through the label.
- **One person may receive several raw labels within one video.** Observed 2026-10-01 on cPVtaKPLC9Q: the affirmative speaker's six-minute closing statement was split onto a fifth label in a four-person debate, with no crosstalk. `participants` is therefore many raw labels → one participant per video; talk-time and move counts aggregate over the participant, never the label. The ingest UI must offer "same person as" merging alongside naming.

### 13.4 Lines of argumentation

**Definition.** A line is a claim or argument introduced by one participant plus every move made on it afterwards, until it is dropped or resolved. Moves are the closed vocabulary from §6 (target ≤ 15). Seed set, drawn from what the sample actually exhibits:

- `open` — introduces a line (55 s: announces the Thomist framework, then the five ways / act-potency argument)
- `develop` — continues own line (121 s, 258 s, 287 s: long turns of 70–180 words)
- `challenge` — attacks the other side's line (181 s and 186 s: "you have to prove it's God that's doing it"; 350 s: the "finger is not God" demand)
- `defer` — declines to answer now, promises later (195 s, 287 s, 353 s, 360 s: four "let me finish" deferrals in three minutes)
- `meta` — talks about the conversation instead of the line (198–246 s: channel, debates vs conversations, "what your goal is")
- `reframe`, `concede`, `pivot`, `silence` — the §4 avoidance behaviors; `silence` is detected structurally (a `challenge` with no `develop`/`concede`/`reframe` on that line within N turns), not by the LLM
- `interject` — substantive but interrupting (<15 words, mid-opponent-turn, not backchannel)

**Extraction.** Oban job per video after §13.3 is confirmed. Windows of 20 substantive turns, 5-turn overlap, each sent through `AiroClient.chat/2` with `response_format: json_schema` returning `[{turn_idx, line_ref, move_type, target_turn_idx?, quote}]`. Prompt carries: the move vocabulary with one-line definitions, the participant map, the lines already open from the previous window (so `line_ref` is stable across windows), and a stopping instruction. A merge pass unifies `line_ref` across windows by label similarity and closes lines not touched for N turns. Every move must quote a substring of its turn; moves whose quote is not found in the turn text are rejected, which is the cheapest hallucination check.

**Why the deferral matters.** The four deferrals above are each a short turn. Before §13.2 they were separate 1–3 s segments interleaved with backchannels and read as noise. After normalization they are a recurring counter type ("challenge → defer-to-completion"), i.e. exactly the §4 Counters claim, visible from one video. That is the test the pipeline must pass on every sample: does a pattern a human spots on one viewing survive the layers as a countable row.

### 13.5 Milestone 1 update

The hand-built dossiers (§9) use layers 0–3 from the app and tag layer 4 by hand in a LiveView, producing the gold set. `docs/samples/normalize_probe.py` is the throwaway script used to size §13.2; it is not app code. It is a reference only: it records how the manual pass was done.

## 14. The pipeline: making the manual pass repeatable (v0.3 · 2026-10-01)

What was exercised by hand on four videos, stage by stage, and what each stage becomes in the app. Rule for the whole section: **the LLM proposes, the code counts, a human confirms at three gates.** No dossier sentence is LLM prose; every row is a query result with span citations, and prose is generated last from the rows.

### 14.1 Stage map

| # | stage | manual version (what we did) | automated version | kind | queue | done when |
|---|---|---|---|---|---|---|
| 1 | **Ingest** | pasted a YouTube URL into ElevenLabs; saved the SRT export | `Ingest.Submit` creates `video`, fetches metadata (title, channel, `published_at`, duration) via YouTube Data API `videos.list` (key already planned §12.2), posts `source_url` to ElevenLabs with `diarize`, `webhook`, `timestamps_granularity: word`; webhook stores raw JSON. Paste path parses SRT/`[Speaker N]` into the same `transcript_words`. | code | `ingest` (conc. 2) | `transcript.status = received`, word count > 0 |
| 2 | **Normalize** | `docs/samples/normalize_probe.py`: merge, backchannel, bridge, interrupted, final-block assertion | `Transcripts.Normalize` applies §13.2 rules from the settings row; writes `turns`; asserts segment count = speaker-tag count | code | `normalize` | `turns` written; assertion passed |
| 3 | **Participants** | read the first minutes, inferred host/guest/moderator, noticed S1↔S0 flips and the S4 split, merged by hand | `Participants.Propose`: LLM over first 5 min + metadata → `{raw_label, role, likely_name, evidence_quote}`; `Participants.MergeHints`: flags labels whose turns continue another label's sentence or share a closing (the v4 S4 case); matches `likely_name` to debater aliases. **Gate A: human confirms the map in the ingest UI.** | LLM + code + **human** | `participants` | `participants.confirmed_by_user` for every raw label |
| 4 | **Tag moves** | read every turn, assigned `open/develop/challenge/defer/reframe/concede/pivot/meta/interject` with a tactic label and a quote | `Moves.Tag`: windows of 20 substantive turns, 5 overlap, closed vocabulary, participant map, open lines carried forward, `response_format: json_schema`; every move must quote a substring of its turn (reject otherwise); `opponent_present: false` for monologue; `confidence`; `contested` when the model reports a scoping judgment (the v4 "existence, not effects" case) | LLM + code | `tag` (conc. 4) | every substantive turn has ≥1 move or an explicit `none` |
| 5 | **Pair pushbacks** | for each opponent challenge, found what the debater did next and whether it completed | `Pushbacks.Pair`: deterministic candidate = next ≤K turns by the challenged participant after a `challenge`/question; `Pushbacks.Judge` (LLM, rubric §14.4) labels the reply `answered / answered-from-own-frame / defer / reframe / pivot / concede / silence` and `completed: yes/no/contested` with a quote. **Runs after the last turn**, never streaming (§13.4: 5:49 in v1 was `defer` at the time and `silence` by the end). | code + LLM | `pair` | every `challenge` has a pushback row |
| 6 | **Lines** | grouped moves into "First Way", "Fatima", "existence vs effects" etc.; noticed the same line under four skins | `Lines.Build`: cluster a video's moves into lines by `line_ref`; `Lines.Link`: cross-video unification by embedding (`AiroClient.embeddings`) + LLM naming into a debater-level `argument` ("act/potency core", "miracle evidence"); formulation recorded as a child (motion / efficient causality / existence / parts) | code + LLM | `lines` | every move belongs to a line; every line links to ≤1 debater-level argument |
| 7 | **Per-video dossier** | wrote openings / counters / avoidances / notes | `Dossier.Video.render/1`: pure query over `moves`, `pushbacks`, `lines`; the tagging-log section is generated from `contested`, `confidence < τ`, exclusions | code | — | renders with no LLM call |
| 8 | **Debater aggregate** | rewrote `docs/dossiers/thomist.md` at n=2, 3, 4 | `Dossier.Debater.render/1`: computed rows (§14.5) over all confirmed videos of the debater; prose generated **last** from rows, each sentence bound to its row | code (+LLM for prose) | `aggregate` | every sentence has a row id and ≥1 span |
| 9 | **Destination analysis** | the "vibe check": one terminal across four formulations, potency as the gate | `Findings.Destination`: §14.8 | code + LLM | `aggregate` | row present when ≥3 videos |
| 10 | **Review** | re-read, flagged "contested", excluded personal content | **Gate B**: review queue of `contested`, low-confidence, and every `silence` verdict; reviewer accepts / relabels / excludes; accepted items join the gold set | **human** | — | queue empty for the video |
| 11 | **Publish** | n/a | **Gate C**: persona gate (§11), span check (no span → no sentence), scope rule (§3), reviewer sign-off; publishes the computed dossier, never a draft | code + **human** | — | `dossier.published_at` |

Stages 1–9 are Oban jobs chained per video; 8–9 re-run for the debater after every confirmed video. Stage 5 depends on 3 (the challenged participant must be known) and runs only after the full transcript is tagged.

### 14.2 Data model (adds to §12.4 and §13.1)

- `videos`: `+format` (`tiktok_live | youtube_live | moderated_formal | podcast | monologue`), `+channel_of_record` (`debater | opponent | third_party | unknown`), `+published_at`, `+provider`, `+provider_job_id`, `+raw_payload jsonb`.
- `participants`: `(video_id, raw_label)` rows; **many rows may share one `participant_id`** (v4 S1+S4); `role`, `debater_id`, `confidence`, `evidence_quote`, `confirmed_by_user`.
- `moves`: `+tactic` (free text, e.g. `knowledge-check`, `burden-scope`), `+opponent_present`, `+contested`, `+confidence`, `+model`, `+prompt_version`, `+reviewed_by`.
- `pushbacks` (new): `trigger_move_id`, `reply_move_id nullable`, `behavior`, `completed` (`yes | no | contested`), `window_turns`, `quote`, `judged_by` (`model | human`).
- `lines`: per video; `arguments` (new): per debater; `formulations` (new): child of argument, one per distinct premise set; `line_links` (`line_id → argument_id`, `formulation_id`).
- `findings` (new): computed rows for the aggregate — `kind` (`stable | adaptive | census | destination | unknown`), `statement`, `support` (video ids), `spans[]`, `n_videos`, `n_total`. Regenerated, never edited; edits happen upstream.
- `counters` (§7 step 7): authored short-circuits, `attached_to` an `argument` or `finding`, author = Jody.
- `gold_tags`: human-accepted moves and pushbacks, keyed by `(video_id, turn_idx)`; the grading set for §14.6.

### 14.3 The three LLM prompts (all via `AiroClient.chat/2`, `json_schema`, `prompt_version` stored on every row)

1. **Participant map.** In: first 5 min of turns, title, channel, description. Out: per raw label `{role, likely_name, evidence_quote, merge_with?}`. Check: `evidence_quote` must appear in the turns.
2. **Move window.** In: 20 turns, participant map, move vocabulary with one-line definitions, lines open from the previous window, format. Out: `[{turn_idx, line_ref, move_type, tactic?, target_turn_idx?, quote, confidence, contested_reason?}]`. Checks: quote ⊂ turn text; `move_type` ∈ vocabulary (else reject the row); no move on `backchannel` turns; `opponent_present` from the participant map, not the model.
3. **Pushback judge.** In: the trigger turn, the K following turns, the debater's participant id, the rubric (§14.4). Out: `{behavior, completed, quote, reason}`. Check: `quote` ⊂ one of the K turns or `behavior = silence`.

Local Qwen models get `chat_template_kwargs: {enable_thinking: false}` (mem_pal lesson). A fourth, cheap call names cross-video arguments; it is advisory and a human can rename.

### 14.4 Rubric for `completed` (what we applied by hand)

- **answered**: the reply addresses the trigger's content and the trigger is not re-raised in the same form within K turns.
- **answered-from-own-frame**: the reply resolves the trigger only inside the debater's framework (v4 anthropomorphization; v2 B-theory). Counted as answered in the census, labeled so the reader can weigh it.
- **defer**: explicit promise to return. Becomes **silence** if no `develop`/`answered` on that line follows before the video ends.
- **reframe**: reply changes what the question is about (scope, definition, fallacy label). `contested` when the reframe is arguably legitimate under the resolution (v4 "existence, not effects").
- **pivot**: reply moves to a different line without resolving this one.
- **concede**: partial or full grant; may co-occur with `reframe` ("small portion … still believed").
- **silence**: no reply on the line by the challenged participant within K turns and none later.

K is a setting (default 6 substantive turns). `completed = contested` always enters Gate B.

### 14.5 Computed rows for the debater aggregate (`findings`)

Each is a query, not a judgment:

- **Stable**: a move/tactic/argument present in ≥ 75% of confirmed videos where the format allowed it (question-first opening: 3/3 where allowed; handheld illustration 4/4).
- **Adaptive**: a move whose rate differs across opponent clusters or formats beyond a settings threshold (deferral count varies; deferral *rate per interruption* does not). Opponent clusters come from the opponent participants' own move profiles (`hostile-host`, `engager`, `formal-opponent`), seeded manually, learned later.
- **Census** (§6): for each pushback class, offered-in, behavior distribution, completed ratio. Pushback classes are the cross-video `arguments` on the opponent side (composition, potency realism, stage 2, differentiation, textual contradiction, miracle evidence, moral evil).
- **Base-vs-downstream split**: pushback classes partitioned by whether they target a premise of the debater's own argument (`formulations.premises`) or something downstream; report completed ratio per partition (n=4: base 0/5, downstream answered).
- **Floor dependence**: for the debater's terminal claim, completion rate split by `opponent_present` and format (stage 2: 2/2 unopposed, 0/2 challenged).
- **Unknowns**: arguments or pushback classes with `n_total < 2`, formats never seen, `channel_of_record` distribution, chronology gaps. Rendered as the "still unknown" list; this is what tells Jody which video to ingest next.

### 14.6 Acceptance tests (from gold set #1)

The pipeline is accepted when, on the four tagged videos with the human map confirmed, it reproduces:

| test | target | tolerance |
|---|---|---|
| v1 deferrals by the Thomist | 14 | ±2 |
| v1 "theory / vehicle" reframes by the host | 10 | ±2 |
| v2 deferrals | 2 | ±1 |
| v4 `burden-scope` reframes | ~12 | ±3 |
| v4 participant merge | 5 labels → 4 people, S4 ⊂ Thomist | exact |
| v1 "finger is not God" | `defer` → `silence` | exact, and only after end-of-video |
| v2 stage-2 pushback (40:25) | `pivot`, `completed: no` | exact |
| v4 composition (8:11) | `silence` | exact |
| v4 differentiation demand | `reframe`, `completed: contested` | exact |
| stage-2 floor dependence | 2/2 unopposed, 0/2 challenged | exact |
| cross-video argument linking | four formulations → one `argument` | exact |
| destination row | terminal = actus purus; gate = potency | present, human-verified wording |
| scope rule | zero published sentences without a span; the v2 medical aside and v4 soda talk excluded | exact |

Regressions on any exact row block merge (code track, `mix precommit`); tolerance rows are reported.

### 14.7 Human gates, deliberately only three

- **Gate A (participant map)**: 30 seconds per video; the one place diarization errors are caught.
- **Gate B (review queue)**: `contested`, `confidence < τ`, every `silence`; typically 5–15 items per hour of video. Accepted items become `gold_tags`.
- **Gate C (publish)**: persona gate, span check, scope rule, sign-off. Nothing publishes on a timer.

Everything else runs unattended. If Gate B volume stays above ~20 items/hour after the first ten videos, the vocabulary or the rubric is wrong, not the reviewer.

### 14.8 Destination analysis (the fourth claim type)

Observed by hand at n=4: four formulations, one terminal (actus purus → attributes), one premise defended by relocation (potency). Computed as:

1. For each video, the debater's primary `line`'s terminal claim (the last `develop` before the line closes or the video ends), embedded.
2. Cluster terminals across videos; a cluster covering ≥ 75% of videos is the **destination**.
3. For each `pivot` and `reframe` by the debater, record the line it moved *to*; the most frequent target premise is the **gate** ("our main contention is going to be potency", v2 41:49).
4. Report the base-vs-downstream census split (§14.5) beside it.

Output row: *"Across N formulations the argument terminates at X; under challenge the debater relocates to Y (k of m relocations); pushback at Y is completed j of n times."* The short-circuit authored against it is a `counter` attached to the `argument`, not to a video.

### 14.9 What stays manual in v1

- Authoring short-circuits (`counters`): Jody writes them; the system only attaches evidence.
- Seeding school priors (§4 partial pooling): manual tag per debater, stock critical questions entered once per school.
- The first video of any new debater is tagged with Gate B set to review **everything**, producing that debater's gold anchor.
- Choosing which video to ingest next: the "unknowns" list recommends; a human picks.

### 14.10 Milestones, revised

| | scope | exit |
|---|---|---|
| **M1 — done** | one debater, four videos, by hand | `docs/dossiers/` + `docs/dossiers/thomist.md`; four pipeline defects found (label flip, label split, final block, channel bias) |
| **M2 — pipeline reproduces gold** | stages 1–9 on the four videos | §14.6 table green; Gate B volume measured |
| **M3 — second and third debaters** | 8–12 videos each, pipeline in the loop, Gate B on everything for video 1 of each | three debater aggregates; vocabulary still ≤ 15 types |
| **M4 — dossier UI** | LiveView: per-video view with span jump, debater view with findings and counters, review queue | Jody uses it instead of markdown |
| **M5 — publish** | Gate C, persona pages, "request a persona" | first public dossier |

### 14.11 Open after this pass

- K (pushback window) and τ (review threshold): set from gold set #1, re-fit at M3.
- Whether opponent clustering is stable enough to be automatic or stays a manual tag per participant.
- Where ElevenLabs' `speaker_id` word-level confidence can pre-flag Gate A merges.
- Chronology: `published_at` is required for the formulation-drift finding; backfill for the four gold videos.

## 15. Public structure (v0.3 · 2026-10-01)

Personas are the index; arguments and debates are the content. Every public sentence is a `findings`/`moves`/`pushbacks` row with a span, rendered with a seek link into the embedded player (§6 "jump to timestamp"). **The full transcript is never published**; the public page shows short quoted spans (a clause, not a paragraph) with timestamps. Transcripts stay internal to the pipeline and the review UI.

### 15.1 Routes

| route | page | notes |
|---|---|---|
| `/` | personas index + latest debates + "request a persona" | |
| `/:persona` | **persona page** (e.g. `/jesus-and-what-not`) | exists only past the persona gate (§11, N ≥ 3 confirmed videos) |
| `/:persona/debates` | that persona's debate list, filter by format / opponent / topic | |
| `/:persona/debates/:debate` | **debate page, persona-scoped**: same debate page with this persona's side foregrounded | 302 to the canonical page when the persona is not a participant |
| `/debates/:debate` | **debate page, canonical**: both sides equal | a debate has two participants; it is not owned by either |
| `/topics/:topic` | **topic page**: one `argument` across personas and debates (e.g. `/topics/act-and-potency`, `/topics/fatima`) | the atlas layer from the product discussion; personas are cross-references here |
| `/tags/:tag` | **tag page**: one move or tactic across the corpus (e.g. `/tags/burden-scope`, `/tags/defer`) | |
| `/schools/:school` | school page: stock critical questions, base rates, member personas | §4 partial pooling, public face |
| `/request` | request a persona (name, links to ≥3 public performances) | feeds the ingest queue; nothing auto-publishes |
| `/admin/**` | ingest, Gate A/B/C, counters authoring | authenticated (phx.gen.auth, username login per house style) |

Slugs: `:persona` from the handle (`jesus-and-what-not`); `:debate` = title-slug plus the provider video id suffix (`does-the-christian-god-exist-cPVtaKPLC9Q`), so the slug is readable and the id resolves even if the title changes. `:topic` and `:tag` from the `arguments` and tactic vocabulary, curated names.

### 15.2 Persona page (`/:persona`)

In order, all rows from `findings` with spans:

1. **Header**: handle, display name as used on the record, school tag(s), confirmed video count, format mix, channel-of-record mix (so the reader sees the corpus bias, §10). No photo, no bio (§3 scope rule).
2. **Style** = `stable` findings: the moves present in ≥75% of videos (question-first opening, handheld illustration, compressed form, floor control rate, classify-opponent, authority outsourcing, civility frame with its valences). Each line: rate, then up to three span chips that seek into the embedded players.
3. **Positions** = `arguments` with their `formulations` as children: *act/potency core* (motion · efficient causality · existence/contingency · parts), *miracle evidence* (Fatima · Padre Pio · Eucharistic), *existence vs effects*, *moral grounding*. Each formulation names the debate it appeared in.
4. **Destination** = the §14.8 row, rendered once: terminal, gate, base-vs-downstream split.
5. **Under pressure** = the census (§14.5): pushback class → offered in → behavior → completed, as a table. `contested` rows are shown as contested, with the reason.
6. **Adaptive by opponent/format** = the `adaptive` findings table.
7. **Debates**: cards with embedded player poster, format, opponent, date, three top tags.
8. **Still unknown**: the gaps list. Published on purpose; it is the honesty signal and the "request a video" hook.
9. **Counters**: **decision needed.** Default: Jody-authored short-circuits are **private** (admin only); the public page shows the school's stock critical questions (§6, Walton) attached to each argument. Public counters would turn the page into a playbook against a named person, which is a different product and a different exposure.

### 15.3 Debate page (`/debates/:debate`, and the persona-scoped twin)

1. **Player**: YouTube IFrame embed with the IFrame Player API loaded, so every span chip calls `seekTo(start_ms)`; the page opens at the first substantive turn. TikTok lives: oEmbed when the video is embeddable, otherwise a link-out card with the same seek times listed. Never host or re-upload media.
2. **Facts**: format, date, channel of record, participants (persona links where a persona exists; plain name otherwise), moderators, resolution if any, length.
3. **What happened**: a timeline of `lines` as horizontal bands over the video duration, one lane per participant, colored by move type. Clicking a band seeks the player. This is the §13.4 structure drawn, and it is where a reader sees "25 minutes of Fatima, then metaphysics" in one glance.
4. **Analysis, per participant** (both sides, persona side first on the scoped route): openings table, counters table (trigger → reply), avoidances table (pushback → behavior → completed), tactical notes as `findings` scoped to this video. Timestamps are seek chips.
5. **Pushbacks**: the full `pushbacks` table for the debate, filterable by behavior and by who was challenged.
6. **Topics**: `arguments` touched in this debate, linking to `/topics/:topic`.
7. **Tags**: moves and tactics present, with counts, linking to `/tags/:tag`.
8. **Tagging log**: contested rows, confidence summary, exclusions by rule (e.g. "2 segments excluded under §3"), diarization merges applied. Public, short. It tells the reader what the system was unsure about.
9. **Comments and sentiment** (§12.3): deferred until the de-biasing rule in §6 exists; the section renders only when the video has a comment analysis.

### 15.4 Topic and tag pages

- **Topic** (`/topics/act-and-potency`): definition in one paragraph (curated), school-level critical questions, formulations seen, personas who run it with their rates, debates where it appears with seek chips to each opening, and the pushback census for that topic across all personas. This is the atlas.
- **Tag** (`/tags/burden-scope`): one-line definition from the vocabulary, examples across personas with spans, rate per persona.

### 15.5 Rendering rules

- Every sentence on a public page carries a `finding_id` or `move_id` and ≥1 span; the renderer refuses to emit a sentence without one (Gate C, §14.1 row 11). This is the §3 scope rule enforced at the view layer.
- Quotes are ≤ 25 words. Longer evidence is a seek, not a quote.
- Rates show numerator and denominator ("completed 0 of 2"), never a percentage alone, because n is small by design (§5).
- Opponents without a persona are named as they name themselves on the record (handle or first name as spoken) and are not linked. Their analysis is published only inside the debate page, never aggregated.
- JobyKit: pages are LiveViews under `TopoiWeb.Public.*`; chips, timeline bands, and census tables are `:domain` composites registered in the design manifest; no raw primitives in .heex (house rule).
- Public routes are unauthenticated and cacheable; everything is computed at publish time (Gate C) into `published_pages` snapshots so a public hit never runs a query against the pipeline tables.

### 15.6 Decisions still open

- Counters public or private (default private).
- Whether the persona page shows opponents' aggregate behavior against this persona ("hostile hosts share four moves") — useful, but it aggregates people who have no persona. Default: show it on the school page for `hostile-host` as a school, not on the persona page.
- Comments section: not until §6's de-biasing scheme is tested.
