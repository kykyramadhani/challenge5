---
name: clean-code
description: >
  Clean-code discipline for writing, reviewing, and refactoring code in this
  project (Swift/SwiftUI, but the principles are language-agnostic). Apply it
  whenever you write a new type, function, or view; refactor or extend existing
  code; review a diff; or the user mentions clean code, readability,
  maintainability, code smells, naming, "make this cleaner," "tidy this up,"
  or a code review. Use it proactively even when the user doesn't say the words
  "clean code" — any non-trivial code you produce here should follow it.
---

# Clean Code

Code is read far more often than it is written, so the goal is code the next
reader (often future-you, or another Claude session) understands quickly and
can change safely. Optimize for readability and maintainability over cleverness
or brevity. These principles come from Robert C. Martin's *Clean Code*, adapted
for how this project is built.

## How to use this skill

1. **Before writing**, keep the highest-leverage rules below in mind — they
   catch the majority of problems.
2. **For anything non-trivial** (a new subsystem, a refactor, a review, or when
   the user asks for a thorough job), read `clean-code-rules.md` in this folder.
   It's the full checklist — names, functions, comments, formatting, objects vs.
   data structures, error handling, classes, tests, code smells, concurrency,
   system design, refactoring, and documentation. Don't paste it back to the
   user; apply it.
3. **Before you finish**, run the self-review checklist at the bottom.

## The rules that matter most

These are the ones that pay off on almost every change, so internalize them
rather than looking them up each time:

- **Names carry the design.** Use intention-revealing names that say *why* a
  thing exists, not what type it is. `charactersPerSession` beats `count`;
  `feedbackForIncorrectStroke` beats `data`. Types are nouns
  (`VocabRepository`), methods are verbs (`generateFeedback`). Avoid vague
  fillers like `manager`, `info`, `helper`, `temp`.
- **Small functions that do one thing.** If a function has multiple
  responsibilities or mixes levels of abstraction (high-level flow next to
  byte-fiddling), split it. Aim for a function you can read top to bottom
  without scrolling and describe in one sentence.
- **Few arguments.** 0–2 is ideal, 3 is a lot. A boolean flag argument usually
  means the function does two things — split it instead.
- **Commands vs. queries.** A function either changes state or returns
  information, not both. A getter that mutates surprises the caller.
- **Don't comment bad code — rewrite it.** Prefer self-explanatory code to a
  comment that props up something confusing. Keep comments that carry real
  information (a non-obvious *why*, a warning, a `TODO`, public-API docs).
  Never leave commented-out code — delete it; git remembers.
- **Handle errors with real errors.** Throw/return typed errors with context,
  not sentinel values or silent `nil`. Prefer returning an empty collection or
  an optional over a surprise `nil`, and don't pass `nil` in.
- **DRY, YAGNI, KISS, Boy Scout.** Remove duplication; don't build for
  imagined future needs; choose the simplest thing that works; leave every
  file you touch a little cleaner than you found it.

## Applying this in a Swift / SwiftUI project

The principles are universal, but here's how they land in this codebase:

- Favor small, single-purpose `View`s and extract subviews the moment a `body`
  gets hard to scan — the same "small functions" rule, applied to view trees.
- Use `let` and value types by default; expose behavior, not mutable internals.
  This is "objects hide data behind abstractions" in Swift's idiom.
- Keep responsibilities separated the way the project already does it — e.g.
  measurement (`HandwritingAnalyzer`) apart from presentation
  (`FeedbackGenerator`). When you add code, find the type whose single
  responsibility it belongs to rather than bolting it onto whatever's nearby.
- Route colors, fonts, and constants through the shared `Theme` instead of
  hardcoding them — duplication of a magic value is still duplication.
- Prefer `throws` + typed errors and optionals over force-unwraps (`!`) and
  sentinel values.

Match the file's existing conventions over any personal preference — consistency
within the codebase beats a "more correct" style imposed unevenly.

## A note on judgment

Clean code is about clarity, not ceremony. Don't wrap a 10-line script in
layers of protocols and factories to satisfy a rule — that violates KISS and
YAGNI, which are themselves clean-code principles. When two rules pull in
opposite directions, favor whatever makes the code easiest for the next person
to read and change, and say briefly why you chose it.

## Self-review checklist

Before calling code done, skim the change and ask:

- Do the names tell the reader what and why, without a mental decoder?
- Does each function/type do one thing, at one level of abstraction?
- Is there duplication I can remove, or dead code/commented-out code to delete?
- Are errors handled with context, and are `nil`/force-unwraps avoided?
- Would a new reader understand this without me explaining it?

If any answer is "no," refactor before finishing. See `clean-code-rules.md`
for the exhaustive checklist behind these questions.
