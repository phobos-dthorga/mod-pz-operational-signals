# Free Agent System — Architecture & Implementation Guide

> **Design reference**: `design-guidelines.md` §46, §47
> **Role**: POSnet's field-operations actor layer (not merely selling Phase 3)
> **Dependencies**: PhobosLib (ModData, safecall, randFloat, clamp, notifyOrSay), Starlit (POS_Events)
> **Cross-references**: §42 Three-Layer Selling, §43 Contracts, §9 Panel Architecture,
> §24 Living Market, §21 SIGINT, §39 Apocalypse Pricing, §40 Starlit, §45 Band Registry

---

## 1. What It Is

The Free Agent System is POSnet's **field-operations actor layer** — named
NPCs that the player dispatches into zombie territory to execute operations
on their behalf. While it originated as Phase 3 of the Three-Layer Selling
System (§42), the system is designed as a general-purpose operations
substrate that can serve:

- Contract fulfilment (sell-side logistics)
- Commodity sale runs (spot selling)
- Black-market smuggling (grey-market contracts)
- Wholesaler/contact procurement (buy-side delegation)
- Recon couriering (intel delivery between terminals)
- Signal relay or data handoff jobs (future)

**Fantasy**: "You send someone into the wasteland. You wait by the radio.
The static crackles. Sometimes they come back. Sometimes they don't."

### 1.1 Design Pillars

1. **Observability first** — If the player can't see the system working
   through the signal feed and terminal, it has failed. Agents are not
   background automation; they are radio drama.
2. **Cargo and money are sacred** — Item movement and money movement must
   have hard invariants. No fuzzy handwaving about "where did the items go."
3. **Zone risk is central** — Agent risk is not a flat archetype scalar.
   It is a function of archetype baseline, zone volatility, market
   disruption, signal quality, and intel freshness.
4. **Signal infrastructure matters** — The radio layer (§5) is not just
   flavour. Poor signal degrades telemetry, worsens recall success, and
   limits intervention options.

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

### 3.3 State Machine Expansion Path (Future)

The current 9-state machine covers the conceptual ground. When gameplay
demands it (e.g. partial-success recall requiring "which leg" the agent
is on), the following expansion stages are available:

```
sourcing/pickup → outbound transit → arrival/market access →
negotiation/execution → return transit → settlement/handoff
```

This split would enable:
- Partial success modelling (recall during return = cargo retained)
- Archetype specialisation per stage (runners excel at transit, brokers at negotiation)
- More granular signal-feed radio drama

**Deferred until**: the Deploy UI exists and real players provide feedback
on whether the current granularity feels sufficient.

---

## 4. Hard Invariants

These rules are non-negotiable. They protect the integrity of the economy
and prevent exploits, duplication, and authority confusion — especially
important for future MP support.

### 4.1 Cargo Movement

| Rule | Detail |
|------|--------|
| **Deploy consumes immediately** | `PhobosLib.consumeItems()` removes cargo from player inventory at deployment time. No "promise to deliver later." |
| **Provenance is explicit** | Every agent record stores `cargoSourceType` (player_inventory / faction_depot / world_stash) and `cargoSourceOwnerId`. |
| **Recall returns proportionally** | Recalled agents return a percentage of cargo based on progress: `drafted/assembling` = 100%, `transit` = 75%, `negotiation+` = 50%, `compromised` = 0%. |
| **Failure = total loss** | Failed/compromised-to-failed agents lose all cargo. This is the risk the player accepted. |

### 4.2 Money Movement

| Rule | Detail |
|------|--------|
| **Settlement is the only credit point** | Money is only added to the player when `state == COMPLETED`. No partial payouts on recall. |
| **Commission is deducted atomically** | `netPayout = settlementPayout × (1 - commissionRate)` — single operation, no intermediate state. |
| **Contract linkage is mandatory** | If an agent is fulfilling a contract, completion must call `POS_ContractService.settleViaAgent()` (or equivalent). The contract and agent settle in the same transaction. |

### 4.3 Ownership (MP-Ready)

| Rule | Detail |
|------|--------|
| **Every record has an owner scope** | `ownerScopeType` (player / faction / public_system) + `ownerScopeId` on all operational records. |
| **Only owner scope can act** | Recall, cancel, and settlement require matching ownership. Faction officers can act on faction-owned agents. |
| **World owns truth** | The authoritative data store is world-scoped ModData. Ownership tags filter access, not storage location. |
| **Single settlement authority** | Only the server/SP authority settles outcomes and credits funds. Idempotent — reprocessing the same completion must not duplicate money or items. |

---

## 5. Three-Layer Observability

If the player can't see the system working, it has failed. Agent
observability is not a UI enhancement — it is a core requirement.

### 5.1 Strategic Visibility (before deployment)

What the player sees when deciding whether to send an agent:
- Chosen archetype with commission/risk/speed tradeoffs
- Destination zone with current volatility and pressure
- Cargo manifest and expected payout
- Calculated risk: `archetype_baseline × zone_volatility × disruption × signal_penalty`
- Expected ETA range
- Reason for using this agent vs. manual fulfilment

### 5.2 Operational Visibility (during mission)

What the player sees while waiting by the radio:
- State badge updates in the SignalPanel intel stream (§9.2)
- PN toast notifications per state change (§9 PN Integration)
- ContextPanel detail when agent is selected: current state, zone,
  last contact time, ETA countdown, risk level, cargo status
- Delay/compromise cause text from text pools (voice-pack-aware)
- Signal quality indicator (degraded telemetry at low signal)

### 5.3 Forensic Visibility (after completion)

What the player sees in the history tab:
- Full state transition log with timestamps
- Settlement breakdown (payout, commission, net)
- Cargo manifest (what was sent, what was delivered/lost)
- Failure cause (compromised → failed, recalled, expired)
- Agent success rate (if persistent agent roster is implemented)

---

## 6. Risk Model

Agent risk is not a flat archetype scalar. The full risk formula:

```
finalRisk = archetypeBaseline
          × zoneVolatility
          × (1 + marketDisruption)
          × signalPenalty
          × intelFreshnessMod
```

Where:
- `archetypeBaseline` = `FREE_AGENT_RISK_LEVELS[archetype]` (0.03–0.25)
- `zoneVolatility` = `zoneDef.baseVolatility` (0.15–0.30)
- `marketDisruption` = current zone pressure / max pressure (0–1)
- `signalPenalty` = `1.0 + (1.0 - signalStrength) × 0.5` (poor signal = +50% risk)
- `intelFreshnessMod` = stale zone intel increases risk (placeholder, future)

> **Current state**: Only `archetypeBaseline` is wired. Zone volatility,
> disruption, signal, and intel are documented but not yet integrated.

---

## 7. Signal Infrastructure Integration

The radio layer is not just flavour for agents — it has mechanical effects:

| Signal Quality | Telemetry | Recall Success | Intervention |
|---------------|-----------|----------------|-------------|
| 80-100% | Full state updates | 95% success | Mid-run rerouting possible (future) |
| 50-79% | Delayed updates (1 tick lag) | 75% success | Recall only |
| 25-49% | Sporadic updates | 50% success | Recall with 50% cargo loss |
| <25% | "Last contact X days ago" | 25% success | No intervention possible |

> **Current state**: Not yet wired. Signal quality is available via
> `POS_ConnectionManager.getSignalStrength()` but agents don't read it.

> **Future integration**: When the Broadcast Influence system is implemented
> (see `broadcast-influence-design.md` §4), Tier IV broadcasts will create
> `agent_advisory` records that modify agent telemetry quality, recall odds,
> route bias, and per-archetype behavioural modifiers. Signal infrastructure
> will no longer be a flat percentage — it will be a composite of five pillars
> (see `signal-ecology-design.md` §3).

---

## 8. Archetype Tuning

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

## 9. PhobosNotifications Integration Opportunities

> **Current state**: All `notifyOrSay` calls in FreeAgentService use the
> **broken shorthand** `notifyOrSay("POSnet", text, "info")` — passing a
> string where `player` should be. This silently falls back to a garbled
> `PhobosLib.say()` call or fails entirely when PN is installed. The correct
> API is `notifyOrSay(player, { title, message, colour, channel, ... })`.
> This same bug affects ContractService, EventService, and CommodityItems.

### 9.1 Notification Opportunities (MEDIUM–HIGH benefit)

The following agent lifecycle events should produce distinct PN toast
notifications with appropriate colour presets, priorities, and channels.
All should use the `"POSnet"` channel (registered via `PN_ChannelRegistry`)
so players can mute agent updates if desired.

| Event | Colour | Priority | Benefit | Rationale |
|-------|--------|----------|---------|-----------|
| **Agent deployed** | `info` | `normal` | HIGH | Confirms action taken; player needs to know the agent left |
| **Agent in transit** | `info` | `low` | MEDIUM | Ambient awareness — the radio crackles with confirmation |
| **Agent delayed** | `warning` | `normal` | HIGH | Player needs to know something went wrong; builds tension |
| **Agent compromised** | `error` | `high` | HIGH | Critical — cargo/agent at risk. Player may want to recall. |
| **Agent negotiating** | `info` | `low` | MEDIUM | Reassurance that the agent arrived safely |
| **Agent completed** | `success` | `normal` | HIGH | Money credited! Player needs confirmation of settlement |
| **Agent failed/lost** | `error` | `critical` | HIGH | Cargo gone, agent gone. Player must know immediately. |
| **Agent recalled** | `warning` | `normal` | MEDIUM | Confirms recall action was processed |

### 9.2 Suggested Implementation

Replace the broken shorthand calls in `POS_FreeAgentService.lua` with
proper PN-aware notifications:

```lua
-- Current (broken):
PhobosLib.notifyOrSay("POSnet",
    agent.agentName .. " deployed to " .. zoneId, "info")

-- Fixed (PN-aware):
PhobosLib.notifyOrSay(getPlayer(), {
    title   = PhobosLib.safeGetText("UI_POS_FreeAgent_Deployed_Title"),
    message = agent.agentName .. " deployed to " .. zoneName,
    colour  = "info",
    channel = POS_Constants.PN_CHANNEL_AGENTS,
    icon    = POS_Constants.ICON_FREE_AGENT,
})
```

### 9.3 Channel Registration

POSnet should register a dedicated PN channel for agent updates so players
can mute them independently of other POSnet notifications:

```lua
-- In POS_NotificationChannels.lua (or OnGameStart):
if PN_ChannelRegistry then
    PN_ChannelRegistry.register({
        id          = POS_Constants.PN_CHANNEL_AGENTS,
        name        = "POSnet Field Agents",
        description = "Agent deployment, transit, and settlement updates",
        defaultEnabled = true,
    })
end
```

Suggested channel IDs for POSnet (all MEDIUM+ benefit):

| Channel ID | Covers | Benefit |
|------------|--------|---------|
| `"posnet_agents"` | Free agent state changes | HIGH — frequent, player may want to mute |
| `"posnet_contracts"` | Contract accept/fulfil/expire/betray | HIGH — financial impact |
| `"posnet_market"` | Market events, zone disruptions | MEDIUM — ambient awareness |
| `"posnet_trade"` | Buy/sell confirmations | MEDIUM — transaction receipts |
| `"posnet_intel"` | Item discoveries, ambient intel | MEDIUM — can be noisy |

### 9.4 Priority Escalation Pattern

Agent notifications should escalate priority based on state severity:

| State | PN Priority | Rationale |
|-------|-------------|-----------|
| `drafted`, `assembling` | `low` | Routine confirmation |
| `transit`, `negotiation` | `low` | Ambient progress |
| `delayed` | `normal` | Something went wrong but recoverable |
| `compromised` | `high` | Cargo at risk — player may want to intervene |
| `settlement`, `completed` | `normal` | Financial impact — money credited |
| `failed` | `critical` | Total loss — demands attention |

### 9.5 Icon Opportunities

Each archetype could use a distinct icon in PN toasts for visual
differentiation. Currently POSnet has 40 custom icons; adding 5 archetype
icons would make agent notifications instantly recognisable at a glance.

| Archetype | Suggested Icon | Fantasy |
|-----------|---------------|---------|
| Runner | Backpack or running shoe | Speed and vulnerability |
| Broker | Radio or ledger | Communication and deals |
| Courier | Package or truck | Reliable transport |
| Smuggler | Lockpick or mask | Subterfuge |
| Contact | Handshake or Rolodex | Established relationships |

### 9.6 Broader POSnet PN Fixes Required

The broken shorthand pattern `notifyOrSay(string, string, string)` appears
in **11 files** across POSnet (55 total call sites). These ALL need fixing
to the proper opts-table signature. This is a **HIGH-priority bug** that
affects every notification in POSnet when PN is installed:

| File | Broken Calls | Fix Priority |
|------|-------------|-------------|
| `POS_FreeAgentService.lua` | 3 | HIGH (agent lifecycle) |
| `POS_ContractService.lua` | 5 | HIGH (financial events) |
| `POS_EventService.lua` | 1 | MEDIUM (market events) |
| `POS_Screen_CommodityItems.lua` | 6 | HIGH (buy/sell receipts) |
| `POS_Screen_Contracts.lua` | 2 | MEDIUM (error feedback) |
| `POS_MarketDatabase.lua` | 1 | MEDIUM (item discovery) |

Files already using the correct opts-table signature (no fix needed):
`POS_DataRecorderService`, `POS_CameraCompileAction`,
`POS_SatelliteBroadcastAction`, `POS_RecorderContextMenu`,
`POS_Screen_DataManagement`, `POS_Screen_Markets`,
`POS_TutorialService`, `POS_TradeService`, `POS_WatchlistService`,
`POS_TerminalAnalysisAction`, `POS_SatelliteWiringAction`.

---

## 10. Cross-References

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
| **PhobosNotifications** | **Toast notifications for all 8 state changes** | **⛔ Broken** (shorthand sig) |
| **PN Channels** | **Dedicated `posnet_agents` channel for muting** | **❌ Not registered** |

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

## 12. Multiplayer Ownership Model

> **Status**: Design only — not yet implemented. Documented early because
> the schema shape depends on ownership decisions.

### 12.1 Principle

POSnet MP uses a **hybrid model**: the world owns the simulation, players
and factions own operational rights, and intelligence moves from private
to shared to public by deliberate publication.

**One sentence**: "Single server-owned data model with explicit ownership
scopes, where the world owns truth, players/factions own operational
rights, and intelligence can move from private to shared to public."

### 12.2 Four Ownership Classes

| Class | Examples | Persistence |
|-------|----------|-------------|
| **World-owned** | Economy state, market prices, zone volatility, global event logs, building caches, broadcast intel | World ModData |
| **Player-owned** | Cash, reputation, watchlists, draft jobs, personal agent roster, private intel | Player ModData |
| **Faction-owned** | Shared depots, faction contracts, shared agents, faction treasury, relay permissions | World ModData (tagged) |
| **Lease/claim-owned** | Terminal operator, relay maintainer, satellite installation | World ModData (tagged) |

### 12.3 Ownership Scope Fields

Every operational record (agent, contract, shipment, compiled intel) carries:

```lua
ownerScopeType    -- "player" | "faction" | "public_system"
ownerScopeId      -- steam ID or faction ID
createdByPlayerId -- who initiated the action
visibility        -- "private" | "faction" | "public"
terminalId        -- which terminal originated this
```

### 12.4 Cargo Provenance

Every deployable operation records where items came from:

```lua
cargoSourceType   -- "player_inventory" | "faction_depot" | "world_stash"
cargoSourceOwnerId
reservedItems     -- items locked on dispatch
consumedItems     -- items removed on dispatch
salvagePolicy     -- rules for partial return on recall/failure
```

### 12.5 Free Agents in MP

- Default to **player-owned** dispatch from personal terminal
- Faction terminal/depot prompts for personal vs faction dispatch
- Only owner scope can recall/cancel
- Faction officers can intervene on faction-owned agents
- Public visibility only if deliberately rebroadcast into signal feed

### 12.6 Contracts in MP

Three layers:
1. **Public board contracts** — visible to all who can receive that feed
2. **Claimed contracts** — temporarily reserved to player/faction
3. **Private execution records** — working state after claim

Claiming converts a public offer into a scoped operational record. The
offer remains visible as "TAKEN" on the board.

### 12.7 Intel in MP

Three publication tiers:
1. **Raw private intel** — player records VHS/scanner data, kept private
2. **Compiled scoped intel** — processed at terminal, shared with faction
3. **Broadcast public intel** — published to the POSnet network

This makes espionage, resale, and intelligence asymmetry possible later.

### 12.8 Implementation Phases

| Phase | Scope | When |
|-------|-------|------|
| 1. Ownership tags | Add scope fields to all records, filter UI | Before MP beta |
| 2. Action permissions | Only correct scope can recall/cancel/settle | MP alpha |
| 3. Inventory provenance | Reserve/consume cargo correctly, salvage rules | MP alpha |
| 4. Scoped intel | Private → faction → public pipeline | MP beta |
| 5. Claimable infrastructure | Terminals, relays, dishes, shared depots | MP release |

### 12.9 Vanilla Faction Integration

PZ Build 42 has built-in factions via the `Faction` Java class. POSnet
should lean on vanilla factions for membership/role queries rather than
building a parallel system. A thin adapter layer maps vanilla faction
roles to POSnet permission levels:

| Vanilla Role | POSnet Permission |
|-------------|-------------------|
| Owner | Full control (dispatch, recall, settle, manage infrastructure) |
| Officer | Dispatch + recall faction-owned agents, spend treasury |
| Member | View faction operations, contribute cargo |

### 12.10 Anti-Grief Rules

| Rule | Detail |
|------|--------|
| Reservation before execution | Goods locked immediately on dispatch |
| Single settlement authority | Only server settles and credits funds |
| Idempotent completion | Reprocessing same completion must not duplicate money/items |
| Lease timeout | Abandoned infrastructure decays to neutral after sandbox-configurable days |
| Audit trail | Append-only operational log: who created, claimed, changed state, got paid |

---

## 13. Suggested Next Steps (Priority Order)

1. **Fix notifyOrSay calls across POSnet** — 18 broken shorthand calls in
   6 files. All must be converted to the opts-table signature. Without this,
   PN toasts don't work at all for agents, contracts, or buy/sell. This is
   the highest-priority fix because it affects every user-facing notification.
2. **Register PN channels** — `posnet_agents`, `posnet_contracts`,
   `posnet_market`, `posnet_trade`, `posnet_intel`. Lets players mute
   categories independently. ~20 lines of code, HIGH benefit.
3. **Build the Deploy UI** — Without this, the system is untestable by
   players. Add "Send Agent" button to Contract screen ContextPanel.
4. **Wire agent cargo consumption** — Deploy should consume items from
   inventory (use `PhobosLib.consumeItems`).
5. **Wire contract settlement** — Agent completion should call
   `POS_ContractService.fulfil()` or a similar settlement path.
6. **Expand ContextPanel** — Show full agent detail on selection.
7. **Zone risk scaling** — Multiply archetype risk by zone volatility.
8. **Partial cargo on recall** — Return items proportional to progress.
9. **Archetype icons for PN toasts** — 5 custom icons for instant visual
   differentiation of agent notifications.
