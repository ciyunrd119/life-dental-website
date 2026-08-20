# Deep-Bite Case Copy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update only the third orthodontics case card so its title and description match the approved deep-bite category copy.

**Architecture:** Make a focused static-HTML copy replacement in the existing third `.case-card`. Preserve the image, category, DOM structure, CSS classes, and the first two cards.

**Tech Stack:** Static HTML, shared CSS, local browser verification.

## Global Constraints

- Modify only the third case card's `case-title` and `case-desc` in `services/orthodontics.html`.
- Keep category text `深咬矯正` unchanged.
- Do not change the first or second case card.
- Verify at 394px viewport width.

---

### Task 1: Apply and verify the approved deep-bite copy

**Files:**
- Modify: `services/orthodontics.html:176-177`
- Test: static source assertions and local browser DOM inspection

**Interfaces:**
- Consumes: the third `.cases-grid .case-card` and its existing `.case-title` / `.case-desc` elements
- Produces: updated visible title and description text without structural or styling changes

- [ ] **Step 1: Verify the current third-card copy is still the old text**

Run:

```bash
rg -n -F '以透明牙套規劃低調矯正日常' services/orthodontics.html
rg -n -F '依照齒列條件與配戴習慣評估是否適合隱形矯正，透過個人化牙套計畫逐步調整排列。' services/orthodontics.html
```

Expected: each command returns exactly one match in the third card.

- [ ] **Step 2: Replace only the title and description**

Use these exact values:

```html
<div class="case-title">調整深咬關係，建立協調咬合</div>
<div class="case-desc">針對前牙覆蓋過深及局部受力情形，綜合評估齒列排列與咬合高度，規劃合適的矯正方式。</div>
```

- [ ] **Step 3: Run static verification**

Run:

```bash
git diff --check
test "$(rg -F -c '<div class="case-title">調整深咬關係，建立協調咬合</div>' services/orthodontics.html)" -eq 1
test "$(rg -F -c '<div class="case-desc">針對前牙覆蓋過深及局部受力情形，綜合評估齒列排列與咬合高度，規劃合適的矯正方式。</div>' services/orthodontics.html)" -eq 1
```

Expected: exit code 0 with no `git diff --check` errors.

- [ ] **Step 4: Verify rendered mobile layout**

Open `services/orthodontics.html` through the local web server at a 394px viewport. Confirm the third card shows the approved title and description, `document.documentElement.scrollWidth <= window.innerWidth`, and the browser console has no errors.
