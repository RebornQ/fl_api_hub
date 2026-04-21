# Cross-Layer Thinking Guide

> **Purpose**: Think through data flow across layers before implementing.

---

## The Problem

**Most bugs happen at layer boundaries**, not within layers.

Common cross-layer bugs:
- API returns format A, frontend expects format B
- Database stores X, service transforms to Y, but loses data
- Multiple layers implement the same logic differently

---

## Before Implementing Cross-Layer Features

### Step 1: Map the Data Flow

Draw out how data moves:

```
Source → Transform → Store → Retrieve → Transform → Display
```

For each arrow, ask:
- What format is the data in?
- What could go wrong?
- Who is responsible for validation?

### Step 2: Identify Boundaries

| Boundary | Common Issues |
|----------|---------------|
| API ↔ Service | Type mismatches, missing fields |
| Service ↔ Database | Format conversions, null handling |
| Backend ↔ Frontend | Serialization, date formats |
| Component ↔ Component | Props shape changes |

### Step 3: Define Contracts

For each boundary:
- What is the exact input format?
- What is the exact output format?
- What errors can occur?

---

## Common Cross-Layer Mistakes

### Mistake 1: Implicit Format Assumptions

**Bad**: Assuming date format without checking

**Good**: Explicit format conversion at boundaries

### Mistake 2: Scattered Validation

**Bad**: Validating the same thing in multiple layers

**Good**: Validate once at the entry point

### Mistake 3: Leaky Abstractions

**Bad**: Component knows about database schema

**Good**: Each layer only knows its neighbors

### Mistake 4: Lazy Cascade on Read

**Bad**: Feature `A` deletes an entity but feature `B`'s records still
cite it; the read path "filters out orphan ids".

**Good**: Cascade on write. The deleting feature calls the sibling
repository to clean references **before** removing its own record.

→ See `frontend/state-management.md` → **Pattern 5 — Cross-Feature
Cascade Delete via Sibling Repository** for the executable contract and
wrong-vs-correct example.

### Mistake 5: Dual-Source Booleans Across Layers

**Bad**: The same "is-enabled" decision is persisted in two places
without a documented precedence rule — e.g. `Account.autoCheckInEnabled`
on the domain entity **and** `CheckInTask.enabled` inside the scheduler
storage. Whichever layer reads last sets the apparent truth, and the UI
toggle silently stops working whenever the other side was updated.

**Good**: Persist each concern in exactly one layer. If both must exist
(per-account opt-in vs scheduler-level kill-switch), document the
precedence as an explicit AND/OR:

```
scheduler should run on account a at time t
  ⇔ account.checkIn.autoCheckInEnabled   // user-level opt-in
    AND taskFor(a).enabled               // scheduler-level kill switch
```

Reference: `lib/features/accounts/domain/entities/check_in_config.dart`
library-level comment spells out the contract; the scheduler must honor
the AND semantics.

---

## Checklist for Cross-Layer Features

Before implementation:
- [ ] Mapped the complete data flow
- [ ] Identified all layer boundaries
- [ ] Defined format at each boundary
- [ ] Decided where validation happens
- [ ] If one entity is referenced by id in another entity's list field:
      is there a **cascade delete** path? (Mistake 4)
- [ ] If the feature has an "enabled" / "active" flag: is it persisted
      in one place, or documented with explicit AND/OR semantics across
      layers? (Mistake 5)

After implementation:
- [ ] Tested with edge cases (null, empty, invalid)
- [ ] Verified error handling at each boundary
- [ ] Checked data survives round-trip
- [ ] If new fields were added to a persisted entity, verified that
      legacy payloads (missing those fields) still deserialize (Hive
      mapper fallback coverage).

---

## When to Create Flow Documentation

Create detailed flow docs when:
- Feature spans 3+ layers
- Multiple teams are involved
- Data format is complex
- Feature has caused bugs before
