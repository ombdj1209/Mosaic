# ADR 0006: LLM triage as an assistant with a decision log and human oversight

**Status:** accepted

## Context

Front desk staff spend time sorting inbound patient messages. An LLM can sort
them, but in a health context a wrong label (missing an urgent message) is
costly, and EU AI Act obligations around logging, transparency and human
oversight apply to the system as it matures.

## Decision

* `AiTriage::Classifier` calls an OpenAI compatible endpoint behind a 3 s
  timeout with temperature 0 and a JSON only prompt.
* Any timeout, transport error, invalid JSON or unknown label falls back to
  `needs_human`. The model can never invent a category.
* Everything `urgent_clinical`, `needs_human`, or below 0.7 confidence lands in
  the review queue (`triage_review_queue` partial index).
* Every outcome, fallbacks included, is logged in `triage_decisions`: model,
  prompt template version, SHA 256 of the exact prompt, label, confidence,
  rationale, reviewer, override, and whether the patient was told that an
  automated system sorted the message (`disclosed`).
* Message bodies are personal data and are deleted on erasure; decisions keep
  labels only.

## Consequences

* The system degrades to "everything goes to a human", which is the safe
  failure mode, and the share of fallbacks is observable (`ai_triage.fallback`).
* Whether this use case is high risk under the AI Act is a legal question; the
  design follows the record keeping and oversight logic either way.
