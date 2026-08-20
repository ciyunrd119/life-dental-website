# All-On-4 Mobile Image Order Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On viewports 640px wide or narrower, display the All-On-4 digital-planning image after the two introductory paragraphs and before the 01–04 planning list, while preserving the existing desktop and tablet layout.

**Architecture:** Add a page-section-specific class to the existing digital-planning section, then use narrowly scoped mobile CSS to flatten the text wrapper into the grid formatting context and order its paragraphs, the existing image, and the steps list. Reuse the single existing image node and existing full-bleed image styles.

**Tech Stack:** HTML5, CSS Grid, responsive CSS media queries, local in-app browser verification

## Global Constraints

- Apply the reordered flow only at `max-width: 640px`.
- Mobile order must be: two explanatory paragraphs → digital-planning image → 01–04 planning list.
- Desktop and tablet layouts must remain unchanged.
- Do not duplicate or replace `../img/services/allon4/digital-plan.webp`.
- Do not change copy or reorder any other section.
- `element.html` does not require synchronization because this is not a dental-knowledge article component change.
- Preserve all unrelated working-tree changes.

---

### Task 1: Reorder the digital-planning image on mobile

**Files:**
- Modify: `services/all-on-4.html:359`
- Modify: `css/style.css:3616`
- Test: static assertions plus visual checks in `services/all-on-4.html`

**Interfaces:**
- Consumes: the existing `.dsd-grid`, `.dsd-text`, `.dsd-visual-plan`, and `.dsd-steps` structure.
- Produces: the section hook `.ao4-dsd` and mobile-only ordering rules scoped beneath `.ceramic-source-page .ao4-dsd`.

- [ ] **Step 1: Run static precondition checks and confirm the new behavior is absent**

Run:

```bash
rg -n '<section class="dsd ao4-dsd">' services/all-on-4.html
rg -n '\.ao4-dsd \.dsd-text \{ display: contents; \}' css/style.css
```

Expected: both commands exit 1 with no matches because the section hook and mobile reordering rule do not exist yet.

- [ ] **Step 2: Add the section-specific HTML hook**

Change the digital-planning section opening tag in `services/all-on-4.html` to:

```html
<section class="dsd ao4-dsd">
```

Do not alter the section's children or duplicate the existing `<figure>`.

- [ ] **Step 3: Add the minimal mobile ordering rules**

Inside the existing `@media (max-width: 640px)` block in `css/style.css`, add:

```css
.ceramic-source-page .ao4-dsd .dsd-grid {
  gap: 0;
}
.ceramic-source-page .ao4-dsd .dsd-text {
  display: contents;
}
.ceramic-source-page .ao4-dsd .dsd-text > p {
  order: 1;
}
.ceramic-source-page .ao4-dsd .dsd-visual-plan {
  order: 2;
  margin-top: 0;
  margin-bottom: 36px;
}
.ceramic-source-page .ao4-dsd .dsd-steps {
  order: 3;
  margin-top: 0;
}
```

These declarations apply only to the approved All-On-4 section and only on phone-sized viewports. The existing paragraph bottom margin supplies spacing before the image; the figure bottom margin supplies spacing before the steps list.

- [ ] **Step 4: Run static verification**

Run:

```bash
rg -n '<section class="dsd ao4-dsd">' services/all-on-4.html
rg -n '\.ao4-dsd \.dsd-text \{' css/style.css
test "$(rg -o 'img/services/allon4/digital-plan\.webp' services/all-on-4.html | wc -l | tr -d ' ')" = "1"
git diff --check -- services/all-on-4.html css/style.css
```

Expected: both searches return the new selectors, the image-count assertion exits 0, and `git diff --check` exits 0 with no output.

- [ ] **Step 5: Verify the mobile layout visually**

Reload `services/all-on-4.html` in the in-app browser at approximately 395px viewport width and inspect the digital-planning section.

Expected:

- Both introductory paragraphs appear first.
- The full-width digital-planning image appears next.
- The list begins with `01 影像與骨質分析` below the image.
- No horizontal scrollbar or clipped content appears.

- [ ] **Step 6: Verify the desktop layout visually**

Inspect the same section at a viewport wider than 1024px.

Expected: text and the 01–04 list remain in the left column, the image remains in the right column, and no other page section changes position.

- [ ] **Step 7: Review the implementation without staging unrelated changes**

Run:

```bash
git diff --check -- services/all-on-4.html css/style.css
git diff -U3 -- services/all-on-4.html css/style.css
```

Expected: the whitespace check exits 0. In the full diff, identify the newly added `.ao4-dsd` HTML hook and mobile CSS block, and verify that the implementation did not overwrite any pre-existing working-tree edits. Do not stage or commit these already-dirty files unless the user separately requests it.
