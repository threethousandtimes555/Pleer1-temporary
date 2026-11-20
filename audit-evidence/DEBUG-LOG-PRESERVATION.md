# Pleer1 — Debug log archive and evidence protocol

Last updated: 20 November 2026

## Mandatory rule

Every complete diagnostics export pasted or uploaded by the user is a primary evidence artifact. Preserve it verbatim in a separate immutable raw file. Never replace raw logs with a summary. New interpretations belong in a separate analysis note.

## Required metadata

Use a stable ID, for example `2026-11-20-repeat-one-cm-build-05`. Record exact received date/time and timezone; app build provider/number/workflow/branch/commit/artifact; device and iOS version if known; network route/VPN and offline-only state; user test steps and expected result; whether the raw log is complete or excerpted.

## Paired analysis note

Record scenario/question, exact action sequence, expected vs actual behavior, timestamp window, exact key events and values, important absent events, proven facts, hypotheses (clearly labeled), alternative explanations, related commits/code locations, next reproducible test, and evidence status (source-only/build/device).

Keep manual seek, natural end, backgrounding, relaunch, Siri/remote actions and network handoff as distinct event origins. A manual seek to the end is not evidence of natural auto-advance.

## Integrity and privacy

- Never invent missing lines, reorder events, normalize timestamps or silently omit entries.
- If only a snippet is available, mark it as an excerpt; never reconstruct the rest.
- Do not archive cookies, authorization headers, tokens, passwords, private keys or credentials. Redact secrets safely and record that redaction occurred.
- Preserve old raw logs unchanged when later diagnostics arrive; create a new artifact and link the two in analysis.

## Known evidence referenced as of 20 November 2026

- 19 November 2026: a user-provided Pleer1 YouTube diagnostics export with 134 entries was discussed. This index does not claim a complete verbatim copy is present in this repository.
- 20 November 2026: a user-provided excerpt reported 45 entries. Visible key lines included:
  - `store.flush | favorites=11, playlists=3, history=40`
  - local favorite prefetch skipped for IDs `yzjnHQZrHGKY` and `y-9udREwo5Nc` because `audio_file_cached`;
  - prefetch success for `ybs4hu3M-cfY`, resolver swift, client VISIONOS, bitrate 130583, duration 219.00;
  - playback ticks for `yzjnHQZrHGKY`: expected 218.00, assetDuration 435.12, position advanced from 215.00 to 236.20, with item=1/control=2/empty=false/likely=true/waiting=none.
- The excerpt did not contain a clear Repeat One button action, playback load start, natural-end event, or failure event. It is not proof that Repeat One worked or failed.

## Open archive work

When the original complete 134-entry and 45-entry exports are available in conversation/files, archive each verbatim as its own raw artifact. This index and policy are not substitutes for those originals.
