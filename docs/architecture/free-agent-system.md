# Free Agent System — Architecture & Implementation Guide

> **Design reference**: `design-guidelines.md` §46
> **Part of**: Three-Layer Selling System (§42, Phase 3)
> **Dependencies**: PhobosLib (ModData, safecall, randFloat, clamp, notifyOrSay), Starlit (POS_Events)

---

## 1. What It Is

The Free Agent System is Phase 3 of the Three-Layer Selling System (§42).
It lets the player delegate trade operations to NPC runners, brokers, couriers,
and smugglers. The player deploys an agent from the terminal, then waits
by the radio as the agent progresses through a probabilistic state machine.

**Fantasy**: "You send someone into the wasteland. You wait. The radio
crackles. Sometimes they come back."

---

## 2. Files

| File | Layer | Purpose |
|------|-------|---------|
| `POS_FreeAgentSchema.lua` | shared | Schema validator for agent records |
| `POS_FreeAgentService.lua` | shared | Lifecycle service — deploy, tick, recall, query |
| `POS_Screen_FreeAgents.lua` | client | Terminal screen — dual tab bars, agent rows, recall |
| `POS_Constants.lua` (lines 216-282) | shared | All agent constants (states, archetypes, rates) |
| `POS_Events.lua` (lines 122-126) | shared | 2 Starlit LuaEvents |
| `POS_EconomyTick.lua` (lines 124-125) | shared | Tick integration |

---

## 3. State Machine

```
drafted → assembling → transit → negotiation → settlement → completed
                          ↓           ↓
                       delayed    compromised
                          ↓           ↓
                       transit     transit OR failed
```

### State Descriptions

| State | Description | Duration | Risk |
|-------|-------------|----------|------|
| `drafted` | Agent has been assigned, preparing | 1 tick (auto-advance) | None |
| `assembling` | Gathering gear and supplies | 1-2 ticks | None |
| `transit` | Travelling to target zone | 1-3 ticks | Delay (50%) or Compromise (50%) |
| `delayed` | En route but held up (zombies, weather) | 1-2 ticks, then resumes transit | None (already in trouble) |
| `compromised` | Cargo or agent at risk | 30% fail, 40% recover, 30% wait | Critical |
| `negotiation` | At destination, executing the trade | 1-2 ticks | None |
| `settlement` | Trade complete, returning with money | 1 tick (auto-advance) | None |
| `completed` | **Terminal state.** Money credited. | — | — |
| `failed` | **Terminal state.** Cargo lost, agent gone. | — | — |

### Transition Logic

Each economy tick, `resolveNextState()` checks:
1. Minimum 1 game-day must pass between state changes
2. `FREE_AGENT_ADVANCE_CHANCE` (55%) determines if agent advances normally
3. During `transit`, `riskLevel` (per-archetype) determines if risk events occur
4. `DELAY_VS_COMPROMISE` (50/50) determines which risk event
5. `delayed` resolves after 1-2 days (60% chance per tick)
6. `compromised` has 30% fail, 40% recover, 30% stay (each tick)
7. `settlement` always advances to `completed` (auto)

---

## 4. Archetype Tuning

All values sourced from `POS_Constants` — no magic numbers.

| Archetype | Commission | Risk | Speed (days) | Constant Key |
|-----------|-----------|------|--------------|-------------|
| `runner` | 5% | 20% | 2 | `FREE_AGENT_ARCHETYPE_RUNNER` |
| `broker` | 15% | 5% | 5 | `FREE_AGENT_ARCHETYPE_BROKER` |
| `courier` | 10% | 10% | 3 | `FREE_AGENT_ARCHETYPE_COURIER` |
| `smuggler` | 20% | 25% | 4 | `FREE_AGENT_ARCHETYPE_SMUGGLER` |
| `wholesaler_contact` | 8% | 3% | 6 | `FREE_AGENT_ARCHETYPE_CONTACT` |

**Trade-off design**: Runners are cheap but risky. Brokers are safe but slow
and expensive. Smugglers take the biggest cut but can go where others can't.
Contacts are the safest but take the longest (established routes).

---

## 5. Persistence

Agents are stored in **world ModData** via PhobosLib:
- Key: `POSNET.FreeAgents`
- Structure: `{ agents = [ ...agent records... ] }`
- Read: `PhobosLib.getWorldModDataTable("POSNET", "FreeAgents")`
- Write: `PhobosLib.setWorldModDataTable("POSNET", "FreeAgents", store)`

No file I/O. ModData auto-persists with the save.

---

## 6. Events (Starlit Integration)

| Event | Payload | When |
|-------|---------|------|
| `POS_Events.OnFreeAgentDeployed` | `{ agentId, archetype, zoneId }` | Agent deployed |
| `POS_Events.OnFreeAgentStateChanged` | `{ agentId, prevState, newState, agentName }` | Any state transition |

The SignalPanel subscribes to `OnFreeAgentStateChanged` to show real-time
agent status updates in the left-sidebar intel stream (§9.2).

---

## 7. Screen (POS_Screen_FreeAgents)

- **ID**: `pos.bbs.agents`
- **Menu path**: `pos.bbs` (under BBS Hub)
- **Guard**: `requires = { connected = true }`

### Dual Tab Bars

- **Row 1** (Archetype): `[All] [Runner] [Broker] [Courier] [Smuggler]`
- **Row 2** (Status): `[Active] [Completed] [Failed]`

### Agent Row Layout

```
[STATE] Ghost 'the Runner' (Runner)
  riverside | 5x Base.Antibiotics | $450
  ETA: ~2d | Risk: HIGH | Commission: 5%
  [Recall Agent]
```

### ContextPanel Integration

Currently minimal — shows active count only. **Not yet expanded** to show
selected agent detail (see §8 Unfinished Work below).

---

## 8. What's Implemented vs. What's Not

### ✅ Implemented

- [x] Schema with full field validation (9 states, 5 archetypes)
- [x] Service with deploy/tick/recall/query API
- [x] Probabilistic state machine with risk events
- [x] World ModData persistence
- [x] Economy tick integration
- [x] 2 Starlit events (deployed, state changed)
- [x] Signal feed notifications on state change
- [x] Screen with dual tab bars + pagination + recall button
- [x] Apocalypse-themed name generation (40 name combinations)
- [x] Commission deduction on settlement
- [x] Max active agent cap (3)
- [x] 19 translation keys (states, archetypes, UI)
- [x] All constants in POS_Constants (no magic numbers)

### ❌ Not Yet Implemented

#### HIGH priority

1. **Deploy UI flow**: There is no screen/button to actually *deploy* an
   agent. The service API (`deploy()`) exists and works, but there's no
   terminal screen flow where the player selects an archetype, picks a
   contract, and sends the agent. Currently the only way to deploy is via
   code/debug.

   **Suggested approach**: Add a "Deploy Agent" button on the Contracts
   screen ContextPanel for accepted contracts. Opens a sub-screen or modal
   where the player picks an archetype and confirms. The ContextPanel
   already has `action` type items, so a "Send Agent" button alongside
   "Deliver Items" and "Abandon" would fit naturally.

2. **ContextPanel detail for selected agent**: The screen has
   `_selectedAgentId` declared but unused — `getContextData()` only shows
   the active count summary. Should expand to show full agent detail when
   a row is selected (state history, risk indicator, ETA countdown, cargo
   detail, zone name, commission breakdown).

3. **Agent return with partial cargo on recall**: Currently recall sets
   state to `FAILED` with no cargo return. Design intent was "returns with
   partial cargo" (§46 design doc says "better than losing everything").
   Need: on recall, return a percentage of cargo items to the player's
   inventory based on how far the agent got.

#### MEDIUM priority

4. **Zone-aware risk scaling**: Risk is currently flat per-archetype.
   Design intent was for zone danger to affect risk (military corridor =
   higher risk, rural east = lower). Need: read zone `baseVolatility`
   from zone registry and multiply into `riskLevel`.

5. **SIGINT influence on agent quality**: Higher SIGINT skill should
   improve agent outcomes (better negotiation, lower risk). Not yet wired.

6. **Agent inventory consumption**: Deploying an agent should consume the
   cargo items from the player's inventory. Currently the deploy API
   accepts cargo info but doesn't actually remove items. The `consumeItems`
   pattern from ContractService.fulfil should be replicated.

7. **Contract linkage**: When an agent fulfils a contract, the contract
   should be marked as settled. Currently the agent completes independently
   — no callback to `POS_ContractService.fulfil()`.

8. **Agent signal feed entries**: State changes emit notifications via
   `PhobosLib.notifyOrSay` but don't write to the SignalPanel's rolling
   buffer. Should also add entries to `POS_SignalPanel.addEntry()` so they
   persist across screen navigation.

#### LOW priority

9. **Agent reputation/history**: Agents could have a track record. A runner
   who has completed 5 missions becomes "Veteran Runner" with better stats.
   Would need a persistent agent roster (not just per-deployment records).

10. **Agent equipment requirements**: Some archetypes could require items
    to deploy (runner needs a backpack, smuggler needs a walkie-talkie).
    Would add a `requiredItems` field to the deployment flow.

11. **Agent voice in briefings**: When a contract is fulfilled by an agent
    rather than the player, the signal feed could show agent-voiced
    settlement text (e.g. smuggler: "Goods delivered. Nobody the wiser.
    Your cut is in the usual place.").

12. **Multiplayer agent authority**: In MP, which player "owns" an agent?
    Currently uses world ModData (shared). Need per-player agent stores
    or ownership tagging.

---

## 9. Cross-References

| System | Integration Point | Status |
|--------|------------------|--------|
| Economy Tick (§24) | `POS_FreeAgentService.tick()` called each tick | ✅ Wired |
| Contracts (§43) | Deploy agent to fulfil a contract | ❌ Not linked |
| Signal Feed (§9.2) | State changes shown in feed | ⚠️ Partial (notifyOrSay only) |
| ContextPanel (§9.3) | Agent detail when selected | ❌ Stub only |
| Living Market (§24) | Zone risk scaling | ❌ Not wired |
| SIGINT Skill (§21) | Quality influence | ❌ Not wired |
| Starlit Events (§40) | 2 events registered | ✅ Done |
| Three-Layer Selling (§42) | Phase 3 implementation | ✅ Core done |
| Apocalypse Pricing (§39) | Agent cargo priced via item value registry | ✅ Indirect |

---

## 10. Constants Reference

All in `POS_Constants.lua`:

```
-- States (9)
AGENT_STATE_DRAFTED .. AGENT_STATE_COMPROMISED

-- Archetypes (5)
FREE_AGENT_ARCHETYPE_RUNNER .. FREE_AGENT_ARCHETYPE_CONTACT

-- Transition probabilities
FREE_AGENT_ADVANCE_CHANCE          = 0.55
FREE_AGENT_DELAY_VS_COMPROMISE     = 0.50
FREE_AGENT_DELAY_RESOLVE_CHANCE    = 0.60
FREE_AGENT_COMPROMISE_FAIL_CHANCE  = 0.30
FREE_AGENT_COMPROMISE_RECOVER_CHANCE = 0.40

-- Limits
FREE_AGENT_MAX_ACTIVE              = 3
FREE_AGENT_PAGE_SIZE               = 4
FREE_AGENT_DEFAULT_ESTIMATED_DAYS  = 4

-- Per-archetype tables
FREE_AGENT_COMMISSION_RATES = { runner=0.05, broker=0.15, ... }
FREE_AGENT_RISK_LEVELS      = { runner=0.20, broker=0.05, ... }
FREE_AGENT_ESTIMATED_DAYS   = { runner=2,    broker=5,    ... }

-- Risk display thresholds
RISK_THRESHOLD_HIGH     = (defined in constants)
RISK_THRESHOLD_MODERATE = (defined in constants)
```

---

## 11. Suggested Next Steps (Priority Order)

1. **Build the Deploy UI** — Without this, the system is untestable by
   players. Add "Send Agent" button to Contract screen ContextPanel.
2. **Wire agent cargo consumption** — Deploy should consume items from
   inventory (use `PhobosLib.consumeItems`).
3. **Wire contract settlement** — Agent completion should call
   `POS_ContractService.fulfil()` or a similar settlement path.
4. **Expand ContextPanel** — Show full agent detail on selection.
5. **Zone risk scaling** — Multiply archetype risk by zone volatility.
6. **Partial cargo on recall** — Return items proportional to progress.
