# Service and Knowledge Image Alt Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure every `<img>` in the treatment and dental-knowledge pages has an `alt` value containing `台中南投生活牙醫`.

**Architecture:** Apply one content-only normalization rule across the existing HTML files: preserve each existing `alt` description and prepend the required phrase when absent; replace an empty `alt` with the required phrase. Do not change HTML structure, CSS classes, JavaScript, image paths, or `element.html`.

**Tech Stack:** Static HTML, shell-based verification, Git diff checks.

**Spec:** Direct user request in the active Codex task on 2026-08-21.

## Global Constraints

- Scope is `services/*.html`, `knowledge.html`, and `knowledge/*.html`.
- Every `<img>` `alt` must contain the exact text `台中南投生活牙醫`.
- Preserve existing descriptive text after the required phrase.
- Do not modify reusable knowledge components or their markup, so `element.html` does not require synchronization.

---

### Task 1: Normalize treatment-page image alt text

**Files:**
- Modify: `services/*.html`
- Test: shell audit over `services/*.html`

- [x] **Step 1:** Count all treatment-page `<img>` elements missing the exact phrase.
- [x] **Step 2:** Prefix missing non-empty `alt` text and populate empty `alt` text.
- [x] **Step 3:** Re-run the audit and require zero missing values.

### Task 2: Normalize dental-knowledge image alt text

**Files:**
- Modify: `knowledge.html`
- Modify: `knowledge/*.html`
- Test: shell audit over the list page and article pages

- [x] **Step 1:** Count all dental-knowledge `<img>` elements missing the exact phrase.
- [x] **Step 2:** Prefix missing non-empty `alt` text and populate empty `alt` text.
- [x] **Step 3:** Re-run the audit and require zero missing values.

### Task 3: Verify the complete change set

**Files:**
- Verify: `services/*.html`
- Verify: `knowledge.html`
- Verify: `knowledge/*.html`

- [x] **Step 1:** Confirm every `<img>` contains the exact required phrase.
- [x] **Step 2:** Run `git diff --check` on all modified HTML files.
- [x] **Step 3:** Review the diff summary and confirm no CSS, JavaScript, or component-library files changed.
