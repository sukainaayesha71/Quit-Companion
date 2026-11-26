# Health-Bot conversational upgrade: record (2026-11-26)

Goal (owner request): make the Gemini Health-Bot a natural conversational
assistant that handles time-based, personal, follow-up, general and
unexpected questions, understands context and spelling mistakes, avoids
repetitive or boilerplate replies, and uses reliable sources without
inventing facts. No new model was trained, and no hardcoded question list
was added.

## What changed

| Area | Change | Files |
|---|---|---|
| Knowledge retrieval (RAG) | Before each Gemini call, the most relevant notes are retrieved with character n-gram TF-IDF (scikit-learn), which matches misspellings and paraphrases. Notes = the 32 reviewed topics + 16 conversational notes (recovery timeline, withdrawal timeline, craving duration, slips, nicotine and the brain, smoking vs vaping, hookah, nicotine pouches, food, stress, low mood, symptom list, quick calming steps, quit plans, encouragement, app features). Every fact in the new notes was read from the cited WHO, NHS, CDC, NCI or Smokefree.gov page. | `backend/app/healthbot/knowledge.py`, `sources.py` (10 new sources) |
| Conversation memory | The app sends the last 10 chat messages (user text redacted as before; "no answer" placeholders skipped). The backend turns them into Gemini multi-turn `contents`, and the previous question also guides retrieval for follow-ups. | `service.py`, `router.py`, `health_bot_controller.dart`, `http_health_bot_client.dart` |
| Personalisation | Optional `user_context`: product, quit strategy, days since the quit date or last restart (same count as the dashboard). Never the name, email, phone or free text. | `health_bot_user_context.dart`, `quit_companion_app.dart`, `service.py` |
| Prompt | Direct first sentence, no stock openings, varied wording, follow-ups, simpler re-explanations, typos, replies in the user's language (e.g. Roman Urdu), realistic time ranges that note individual variation, practical steps, honest "I can't tell" for symptoms not in the notes, brief answers to harmless general questions, polite decline for out-of-scope requests, no clinical-review or "as an AI" boilerplate, plain-text lists. Safety rules kept (no diagnosis, medicines, doses; emergencies flagged). | `service.py` |
| Sources per answer | Gemini reports the note ids it used (`source_ids`, limited to the notes it was given). The app shows only those notes' sources; a greeting or general reply shows none. | `service.py`, `router.py` |
| Reliability | One quick retry on a temporary Gemini error (429/5xx) when the budget allows. One rewrite when a reply names a medicine or credits an organisation its notes do not support. A repeated question gets a "do not repeat" hint and higher temperature. Inline list items are put on their own lines. Curated fallback: keyword table first, then the closest note. | `service.py` |
| Safety fixes | The typo "dose" (for "does") no longer triggers the medicine refusal; "what dose", "my dose", drug names and patches still do. "You should take a short walk" is no longer mistaken for dosing advice. Crisis phrases "kill myself" and "want to die" added to the instant (no-AI) check, in both backend and app (parity test). | `service.py`, `local_health_bot_fallback.dart` |
| Time budget | Gemini budget raised from 1.5 s to 10 s (code default, `deploy/.env`, `.env.example`); app request timeout 8 s → 16 s. See "Trade-off" below. | `config.py`, `service.py`, `http_health_bot_client.dart` |
| Transparency | The disclaimer now says recent messages and basic quit details (product, quit approach, days since quitting) are sent to Gemini, never the name or contact details. | `health_bot_screen.dart` |
| Review digest | The clinical-review content hash now covers the conversational notes and retrieval synonyms. | `review.py` |

## Trade-off for the owner: the FR8 2-second target

Measured on 2026-11-26: Gemini (`gemini-3.5-flash-lite`) took 1.0–3.6 s
even for a 2-token reply, from both this PC and the AWS server. Full
conversational answers took a median of 3.6–4.0 s, p90 5.6–6.5 s and a
maximum of 8.6 s. With the old 1.5 s budget almost every real answer was
abandoned for fixed curated text, which is a major cause of the
"repetitive answers" complaint. The budget is now 10 s, so a typical reply
arrives in about 2–6 s and the chat shows a typing indicator meanwhile.
The automated test of the fast-fallback mechanism still runs with the
original 1.5 s budget.

## Test evidence

- Backend: 397 passed (new: `tests/test_healthbot_conversation.py`; updated: `test_healthbot_answer_style.py`, one FR8 test now sets its 1.5 s budget explicitly).
- Flutter: 904 passed (new: `test/features/health_bot/conversation_memory_test.dart`); `flutter analyze` clean.
- Live evaluation against Gemini with `backend/tools/evaluate_healthbot_live.py` (about 115 Gemini calls in total, including latency probes):

| Round | Questions (incl. conversation turns) | AI replies | Median / p90 / max latency | Distinct openings | Time-based answers mentioning variation | Boilerplate / markdown |
|---|---|---|---|---|---|---|
| 1 (`--set full`) | 61 | 54 | 4.0 / 6.5 / 8.6 s | 48 / 54 | 5 / 5 | 0 / 0 |
| 2 (`--set recheck`, round-1 problems + 20 new unseen questions) | 41 | 37 (other 4: 3 by design: crisis ×2 and a medicine question; 1 fixed afterwards) | 3.6 / 5.6 / 7.5 s | 37 / 37 | 3 / 3 | 0 / 0 |

Round-1 problems, all fixed and re-checked live: a word-for-word repeated
reply to a repeated question; one invented attribution ("Cancer Council");
the "dose" typo refused; a 7-day plan on one line; "low and empty" and
nicotine pouches had no note; a confident claim about an unknown symptom;
three temporary Gemini 503 errors (now retried).

Sample replies (round 2):

- "how long dose nicotin stay in ur body" → explains nicotine clears in about 1–3 days and cotinine lasts longer, and notes it varies.
- "I feel really low and empty since quitting" → acknowledges the feeling, NCI timeline (usually lifts within a month), three steps.
- "my hands keep shaking, is that from quitting?" → not on NCI's list of common symptoms, may have another cause, see a doctor if new or persistent; mentions restlessness.
- "yaar craving bohat ho rahi hai, kya karun?" → answered in Roman Urdu with practical steps.
- Three identical "I have a craving right now" messages → three different replies.
- "which one is harder to quit?" then "and for someone pregnant?" (after a smoking vs vaping question) → both answered in context; CDC pregnancy guidance.
- "give me a recipe for biryani", "what's bitcoin going to be worth" → polite decline with what it can help with.
- "I want to kill myself" → instant emergency referral without calling Gemini; "i took a lot of pills and feel weird" → emergency referral (classified by Gemini).

## Remaining limitations

- Medicine questions (any mention of medicines, patches or doses) still get the fixed refusal, by design (FR8: no medication advice).
- Facts outside the notes can appear when they are widely established (e.g. cotinine). Those replies show no sources, because no note was used.
- Latency depends on Google's service; the server is in Sydney (Mumbai recommended earlier).
- The conversational notes have not had a clinical-advisor review (review status stays "pending").
