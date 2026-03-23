# POSnet Satellite Uplink — Design & Styling Guide

**Branch**: `dev/data-recorder` (future)
**Date**: 2026-03-20
**Status**: Design phase — implementation not started
**Prerequisites**: Camera Workstation operational (see `camera-workstation-design.md`),
Terminal Analysis implemented (see `terminal-analysis-design.md`), SIGINT skill
registered (see `sigint-skill-design.md`)

---

## Executive Summary

The Satellite Uplink is the **Tier IV apex node** of the POSnet intelligence
hierarchy — a large, stationary satellite dish that transforms POSnet from a
local intelligence network into a regional broadcast authority. Where the
Camera Workstation compiles knowledge and the terminal analyses it, the
satellite dish **projects it outward**, affecting market behaviour, reputation,
and world state across a wide area.

```
                    THE FOUR-TIER INTELLIGENCE HIERARCHY
                    ═════════════════════════════════════

  Tier I — FIELD CAPTURE            messy, local, human
           Notes, VHS, recorders    "I saw something"

  Tier II — TERMINAL ANALYSIS       structured, processed
            POSnet terminal          "I understand something"

  Tier III — COMPILATION            verified, packaged
             Camera Workstation      "This is something"

  Tier IV — GLOBAL UPLINK           broadcast, influential   ← THIS DOCUMENT
            Satellite Dish           "Everyone knows something"
```

This is the moment POSnet stops being "a system" and becomes a **networked
world-state machine**. The player is no longer merely observing the post-collapse
economy — they are *shaping it*.

The diegetic fantasy: *"I define regional truth."*

**The crucial design rule**: The satellite dish is NOT passive. It is a
**deliberate, costly, strategic action point** — an operation, not a button.

---

## 1. What the Satellite Dish Is

A **large, stationary, world-placed furniture object** (vanilla PZ B42 moveable
satellite dish) that functions as a high-power broadcast node for POSnet
intelligence. Think of it as a post-collapse uplink station — a heavy parabolic
dish that can push compiled intelligence across a regional area, affecting
markets, reputation, and world behaviour.

It is:
- A fixed-location infrastructure object (moveable furniture, but heavy)
- The highest-tier broadcast node in the POSnet hierarchy
- A destination that gives rooftops, rural outposts, and military sites
  strategic value
- A power-hungry, resource-consuming system (not free to operate)
- The primary path for regional influence and reputation amplification
- An enhancer for Terminal Analysis when linked to a nearby terminal

It is NOT:
- A signal booster (it does not simply "increase range" — it unlocks new
  classes of behaviour)
- A passive auto-broadcaster (requires deliberate player action and materials)
- A replacement for the terminal or camera (it broadcasts compiled results,
  not raw data)
- A requirement for basic POSnet operation (all existing features work without it)
- Easy to set up (requires power, calibration, compiled data)

---

## 2. Why It Must Exist

### 2.1 Current Gap

The existing POSnet pipeline has an influence ceiling:

1. **Information spreads locally.** Market intelligence affects only the
   player's own terminal view. There is no mechanism to propagate
   intelligence broadly or influence the world economy.

2. **No broadcast authority.** All market data is equal once ingested.
   A player who invests heavily in field recon, analysis, and compilation
   has no way to *project* that investment outward.

3. **Reputation is local.** POSnet reputation is earned through missions
   and note submission but has no regional reach. A high-rep player is
   known only to their local contacts.

4. **No endgame infrastructure.** Late-game POSnet activity plateaus at
   "gather notes, sell notes, do missions." There is no infrastructure
   goal that rewards sustained investment.

### 2.2 What the Satellite Uplink Solves

| Problem | Solution |
|---------|----------|
| Information spreads locally | Satellite broadcasts push intelligence across regions |
| No broadcast authority | Player defines "regional truth" via authored broadcasts |
| Reputation is local | Broadcasts amplify reputation regionally |
| No endgame infrastructure | Satellite is the apex goal of POSnet progression |
| Markets are fragmented | Satellite-coupled markets experience price propagation |
| No world-state influence | Broadcasts trigger market shifts, demand flows, panic modifiers |

---

## 3. The Complete Intelligence Hierarchy

For the canonical four-tier table, see `design-guidelines.md` §20.

With the satellite uplink, POSnet's intelligence system forms a complete
four-tier hierarchy. Each tier is **independently useful** but produces
progressively more impactful results when combined. A player with only a
radio and notebook operates at Tier I. A player with a satellite dish
operating at full capacity operates at Tier IV — shaping the world economy.

```
    FIELD ──► TERMINAL ──► CAMERA ──► SATELLITE
    (chaos)   (analysis)   (compilation)  (projection)
    local     local        local          REGIONAL
```

The Satellite Uplink sits at **Tier IV**, the apex broadcast node.

---

## 4. Furniture Object

### 4.1 Sprite Identification

The Satellite Uplink uses a vanilla PZ Build 42 satellite dish furniture sprite.
This is a large parabolic dish, typically found on rooftops, at military
installations, and at communication facilities.

**IMPORTANT: Sprite names are subject to B42 beta changes.** The sprite name
whitelist must be verified against the current B42 build before implementation.
Detection follows the established pattern: `obj:getSprite():getName()` checked
against a constant whitelist.

| Sprite Family | Description | Typical Location |
|---------------|-------------|------------------|
| Satellite dish sprites | Large parabolic dish on mount | Rooftops, military bases, rural comm stations |

**Research note**: The user confirmed that a large satellite dish exists as
moveable furniture in vanilla B42 PZ. Exact sprite names must be captured via
in-game sprite audit before implementation.

### 4.2 CraftBench Entity Definition

The satellite dish is NOT a CraftBench entity. Unlike the Camera Workstation,
the dish does not use PZ's CraftBench/recipe system. Instead, it is interacted
with via right-click context menu actions that trigger ISBaseTimedAction
sequences.

**Design rationale**: The satellite's actions consume compiled intelligence
artifacts (not raw materials in a crafting grid). The interaction model is
closer to "use item at location" than "craft item at bench."

### 4.3 Detection Pattern

```lua
--- Whitelist of satellite dish sprite names.
--- MUST be verified against current B42 build.
POS_Constants.SATELLITE_DISH_SPRITES = {
    -- Placeholder: replace with verified sprite names after sprite audit
    -- ["appliances_misc_01_XX"] = true,
}
```

Right-click detection follows the established `POS_DeliveryContextMenu` and
`POS_CameraContextMenu` pattern: iterate `worldObjects`, check
`getSprite():getName()` against the whitelist, add context menu options.

---

## 5. Broadcast Actions

The Satellite Uplink offers broadcast actions that consume compiled intelligence
artifacts and project their effects across a wide area.

### 5.1 Broadcast Compiled Report (MVP Action)

| Property | Value |
|----------|-------|
| Input | 1 Compiled Intelligence artifact (`POS_Intelligence` tag) + fuel drain |
| Output | Regional market effect + reputation gain |
| Time | 120 seconds (2 min, sandbox-configurable) |
| Animation | `Disassemble` (operating equipment) |
| Power | Required (significant — generator fuel drain) |
| SIGINT influence | Broadcast credibility scales with SIGINT level |

The core action. Consumes one compiled artifact (Site Survey, Verified Intel
Report, or Market Bulletin) and broadcasts its intelligence across the region.
The artifact's confidence, category, and type determine the broadcast's effects.

### 5.2 Broadcast Effects

When a compiled report is broadcast via satellite, the following effects apply:

| Effect | Mechanism | Scale |
|--------|-----------|-------|
| Market price shift | Observations propagate to all tracked categories | Proportional to artifact confidence |
| Demand flow | NPC trader behaviour shifts toward broadcast intelligence | Moderate (sandbox-configurable) |
| Reputation gain | Player gains POSnet reputation for broadcasting | Scales with artifact tier |
| Information persistence | Broadcast data persists longer in the market database | 2x normal staleness threshold |

### 5.3 Broadcast Strength Formula

```
baseStrength = artifactConfidence / 100

bonuses = 0
bonuses += sigintCredibility     -- SIGINT-based (see sigint-skill-design.md §4.4)
bonuses += dishConditionBonus    -- +10% if dish condition > 80%
bonuses += powerStabilityBonus   -- +5% if generator has > 50% fuel

strength = baseStrength * (1.0 + bonuses)
strength = min(1.0, strength)    -- capped at 100% effectiveness
```

### 5.4 Artifact Tier Effects

| Artifact | Reputation Gain | Market Impact | Persistence |
|----------|----------------|---------------|-------------|
| Compiled Site Survey | +0.3 rep | Local category prices shift | 1.5x staleness |
| Verified Intel Report | +0.5 rep | Regional category prices shift | 2.0x staleness |
| Market Bulletin | +1.0 rep | Multi-category regional shift | 2.5x staleness |

Market Bulletins are the highest-impact broadcast: they affect multiple
categories and grant the most reputation.

### 5.5 Action Availability States

Same 6-state system as Camera Workstation and Gather Market Intel:

| State | Condition | Menu Behaviour |
|-------|-----------|----------------|
| `READY` | All requirements met | Clickable, starts timed action |
| `NO_POWER` | No electricity to the dish | Greyed out, tooltip explains |
| `MISSING_INPUTS` | No compiled intelligence artifacts | Greyed out, tooltip lists requirement |
| `DANGER_NEARBY` | Zombies within danger radius | Greyed out, tooltip warns |
| `ON_COOLDOWN` | Recently broadcast from this dish | Greyed out, shows remaining time |
| `NOT_CALIBRATED` | Dish not yet calibrated (first use) | Greyed out, shows calibration action |

### 5.6 Cooldown

Broadcast cooldown is per-dish, scoped to the building using the same
`BuildingDef.getX()/getY()` composite key pattern:

| Action | Default Cooldown | Sandbox Option |
|--------|-----------------|----------------|
| Broadcast Compiled Report | 24 hours (in-game) | `SatelliteBroadcastCooldownHours` |

Cooldown stored in player modData:
`POS_SatelliteVisit_<buildingDefX>_<buildingDefY>_broadcast`

---

## 6. Calibration (First-Use Setup)

Before a satellite dish can broadcast, the player must **calibrate** it. This
is a one-time setup action per dish that represents aligning the dish and
establishing a signal.

| Property | Value |
|----------|-------|
| Action | Calibrate Satellite Dish |
| Time | 300 seconds (5 min) |
| Requirements | Screwdriver + Wrench (both kept) |
| Skill check | Electrical 3 (lower skill = longer calibration) |
| Power | Required |
| Result | Dish becomes operational; stored in world modData |

Calibration state is stored in world modData:
`POS_SatelliteCalibrated_<buildingDefX>_<buildingDefY> = true`

Once calibrated, the dish remains operational until the building loses power
for more than 7 consecutive game days, at which point recalibration is required.

---

## 7. Power Requirements

The satellite dish is **power-hungry** by design. This is not just a gameplay
gate — it reflects the physical reality of pushing a signal through a parabolic
dish.

| Condition | Behaviour |
|-----------|-----------|
| Grid power | Dish operational |
| Generator powering the building | Dish operational; generator drains fuel faster |
| No power | Dish inoperative; context menu greyed out |
| Generator fuel < 20% | Warning tooltip; broadcast strength reduced by 25% |

### 7.1 Generator Fuel Drain

When broadcast via generator power, the action consumes additional fuel:

| Action | Additional Fuel Drain |
|--------|----------------------|
| Calibrate Satellite Dish | 0.05 units |
| Broadcast Compiled Report | 0.10 units |

This is significant enough to matter for resource planning but not crippling.

---

## 8. Context Menu Structure

Right-clicking a satellite dish furniture object presents a sub-menu (per the
retroactive rule in `feedback_context_menu_submenus.md`):

```
Right-click satellite dish:
  └─ POSnet Satellite Uplink ─┐
                               ├─ Broadcast Compiled Report
                               ├─ Calibrate Dish (if not calibrated)
                               └─ Check Signal Status
```

### 8.1 Check Signal Status

A free, instant action that displays:
- Calibration state
- Power status
- Last broadcast time
- Signal strength estimate
- Terminal link status (if a terminal is within link range)

---

## 9. Terminal Link

When a satellite dish is within **50 tiles** of a POSnet terminal (radio +
computer), the terminal gains satellite enhancement for its Analysis action
(see `terminal-analysis-design.md` Section 8).

### 9.1 Link Detection

Link is checked on terminal screen open and cached for the session:

```lua
function POS_SatelliteService.isLinkedToTerminal(terminalSq)
    -- scan within SATELLITE_LINK_RANGE for calibrated, powered dish
    -- return true if found
end
```

### 9.2 Link Range

| Constant | Value | Notes |
|----------|-------|-------|
| `SATELLITE_LINK_RANGE` | 50 tiles | ~10 building-widths |

The link does not require line-of-sight. It represents wired or short-range
wireless connectivity between the terminal and dish infrastructure.

---

## 10. Regional Broadcast Authority

This is the satellite's core strategic function: the ability to define
"regional truth" through authoritative broadcasts.

### 10.1 Without Satellite

- Information spreads locally
- Markets are fragmented
- Prices are inconsistent
- Rumours dominate

### 10.2 With Satellite

- Player defines regional economic narrative
- Examples:
  - "Fuel is scarce" → triggers price spikes across tracked categories
  - "Medical stock available in X" → demand flows toward that data
  - "Military activity detected" → panic modifiers on relevant categories
- Broadcast data has higher credibility weight than field-gathered data

### 10.3 Market Coupling

Satellite broadcasts introduce **market coupling** — the phenomenon where
previously independent local micro-economies begin to synchronise:

| State | Market Behaviour |
|-------|-----------------|
| No satellite broadcasts | Fragmented micro-economies, local price variation |
| Occasional broadcasts | Partial coupling, price trends begin to align |
| Regular broadcasts | Regional market coupling, arbitrage opportunities emerge |
| Competing broadcasts (MP) | Contested truth, price instability, information warfare |

### 10.4 Reputation Amplification

Without satellite, reputation is localised. With satellite:
- Reputation gains from broadcasts are amplified regionally
- Higher-tier missions unlock based on broadcast history
- Contacts recognise the player remotely (future faction system)
- Broadcasts carry identity weight — the player goes from "some survivor
  with notes" to "recognised network operator"

---

## 11. Sandbox Options

| Option | Type | Default | Range | Description |
|--------|------|---------|-------|-------------|
| `EnableSatelliteUplink` | boolean | true | — | Master toggle for satellite dish interactions |
| `SatelliteBroadcastCooldownHours` | integer | 24 | 0-72 | Cooldown between broadcasts at the same dish (0 disables) |
| `SatelliteBroadcastStrength` | integer | 100 | 25-200 | Percentage modifier on broadcast market impact |
| `SatelliteBroadcastRepBonus` | integer | 100 | 0-300 | Percentage modifier on broadcast reputation gains |
| `SatellitePowerDrain` | boolean | true | — | Whether satellite broadcasts drain extra generator fuel |
| `SatelliteCalibrationRequired` | boolean | true | — | Whether calibration is needed before first use (false = always operational) |
| `SatelliteCalibrationTime` | integer | 300 | 60-600 | Calibration action time in seconds |
| `SatelliteLinkRange` | integer | 50 | 20-100 | Tile range for satellite-to-terminal link |
| `SatelliteMarketCoupling` | boolean | true | — | Whether broadcasts cause market price propagation |
| `SatelliteDecalibrationDays` | integer | 7 | 0-30 | Days without power before recalibration needed (0 = never decalibrates) |

---

## 12. Constants

New constants in `POS_Constants.lua`:

```lua
-- Satellite Uplink
POS_Constants.SATELLITE_VISIT_KEY_PREFIX       = "POS_SatelliteVisit_"
POS_Constants.SATELLITE_CALIBRATED_KEY_PREFIX  = "POS_SatelliteCalibrated_"
POS_Constants.SATELLITE_LINK_RANGE             = 50   -- tiles
POS_Constants.SATELLITE_BROADCAST_COOLDOWN_DEFAULT = 24  -- hours
POS_Constants.SATELLITE_CALIBRATION_TIME_DEFAULT   = 300 -- seconds
POS_Constants.SATELLITE_DECALIBRATION_DAYS         = 7

-- Satellite broadcast effects
POS_Constants.SATELLITE_REP_SURVEY             = 30   -- hundredths of rep point
POS_Constants.SATELLITE_REP_REPORT             = 50
POS_Constants.SATELLITE_REP_BULLETIN           = 100
POS_Constants.SATELLITE_STALENESS_SURVEY       = 1.5  -- multiplier
POS_Constants.SATELLITE_STALENESS_REPORT       = 2.0
POS_Constants.SATELLITE_STALENESS_BULLETIN     = 2.5

-- Satellite power
POS_Constants.SATELLITE_FUEL_DRAIN_CALIBRATE   = 0.05
POS_Constants.SATELLITE_FUEL_DRAIN_BROADCAST   = 0.10
POS_Constants.SATELLITE_LOW_FUEL_THRESHOLD     = 0.20 -- 20%
POS_Constants.SATELLITE_LOW_FUEL_PENALTY       = 0.25 -- 25% strength reduction

-- Satellite dish sprites (MUST be verified against current B42 build)
POS_Constants.SATELLITE_DISH_SPRITES           = {}  -- populated after sprite audit

-- Satellite dish detection
POS_Constants.SATELLITE_DISH_CONDITION_BONUS_MIN = 80  -- condition threshold for bonus
```

---

## 13. Module Architecture

### 13.1 New Modules

| Module | Layer | Purpose |
|--------|-------|---------|
| `POS_SatelliteContextMenu.lua` | Client | Right-click context menu on satellite dish furniture |
| `POS_SatelliteBroadcastAction.lua` | Client | ISBaseTimedAction for broadcast and calibration |
| `POS_SatelliteService.lua` | Shared | Core business logic: validation, strength calculation, market effects, calibration |

### 13.2 Modified Modules

| Module | Change |
|--------|--------|
| `POS_Constants.lua` | ~20 new constants (see Section 12) |
| `POS_SandboxIntegration.lua` | 10 new getter functions for satellite sandbox options |
| `POS_Reputation.lua` | No changes needed — `addReputation()` already exists |
| `POS_MarketDatabase.lua` | Add `SOURCE_TIER_BROADCAST` handling for staleness multiplier |
| `POS_EconomyTick.lua` | Respect broadcast staleness multiplier during purge |
| `.luacheckrc` | Add new module globals |

### 13.3 Separation of Concerns

- `POS_SatelliteContextMenu.lua` — **presentation only**. Detects dish
  furniture, builds sub-menu, delegates to service for validation and
  status checks.
- `POS_SatelliteBroadcastAction.lua` — **timed action only**. Handles
  animation, timing, interruption, fuel drain. Delegates to
  `POS_SatelliteService.broadcast()` in `perform()`.
- `POS_SatelliteService.lua` — **all business logic**. Calibration state
  management, broadcast strength calculation, market effect propagation,
  reputation grants, terminal link detection, fuel drain calculation.

---

## 14. Persistence Strategy

### World ModData

| Field | Type | Purpose |
|-------|------|---------|
| `POS_SatelliteCalibrated_<bx>_<by>` | boolean | Whether the dish at this building is calibrated |
| `POS_SatelliteLastPower_<bx>_<by>` | integer | Last game hour the dish had power (for decalibration timer) |

### Player ModData

| Field | Type | Purpose |
|-------|------|---------|
| `POS_SatelliteVisit_<bx>_<by>_broadcast` | integer | Game hour of last broadcast at this dish |
| `POS_SatelliteBroadcastCount` | integer | Lifetime broadcast count (stat tracking) |

### Market Data

Broadcast observations are stored in `POSNET_market_data.dat` with
`sourceTier = "broadcast"`. The staleness multiplier is applied during
`POS_EconomyTick` purge phase.

---

## 15. Translation Keys

### 15.1 UI Strings (UI.json)

```
"UI_POS_Satellite_SubMenu": "POSnet Satellite Uplink",
"UI_POS_Satellite_Broadcast": "Broadcast Compiled Report",
"UI_POS_Satellite_Calibrate": "Calibrate Dish",
"UI_POS_Satellite_CheckStatus": "Check Signal Status",
"UI_POS_Satellite_NoPower": "Dish requires electricity.",
"UI_POS_Satellite_LowFuel": "Generator fuel low — broadcast strength reduced.",
"UI_POS_Satellite_MissingReport": "Requires a compiled intelligence artifact.",
"UI_POS_Satellite_OnCooldown": "Recently broadcast. Available in %1 hour(s).",
"UI_POS_Satellite_NotCalibrated": "Dish must be calibrated before use.",
"UI_POS_Satellite_DangerNearby": "Too dangerous to operate the dish here.",
"UI_POS_Satellite_Ready": "Ready to broadcast.",
"UI_POS_Satellite_Broadcasting": "Transmitting broadcast...",
"UI_POS_Satellite_Calibrating": "Calibrating dish alignment...",
"UI_POS_Satellite_BroadcastComplete": "Broadcast transmitted successfully.",
"UI_POS_Satellite_CalibrationComplete": "Dish calibrated and operational.",
"UI_POS_Satellite_Mumble": "*adjusts the dish heading*",
"UI_POS_Satellite_StatusCalibrated": "Status: Calibrated and operational.",
"UI_POS_Satellite_StatusUncalibrated": "Status: Requires calibration.",
"UI_POS_Satellite_StatusLinked": "Terminal link: Active (%1 tiles).",
"UI_POS_Satellite_StatusUnlinked": "Terminal link: No terminal in range.",
"UI_POS_Satellite_StatusLastBroadcast": "Last broadcast: Day %1.",
"UI_POS_Satellite_StatusNoBroadcast": "Last broadcast: Never."
```

### 15.2 Sandbox Strings (Sandbox.json)

Standard pattern: 10 new options = 20 new translation keys.

---

## 16. Icon Pipeline

The satellite dish is a world-placed furniture object with no inventory icon
needed. However, broadcast-related UI elements need icons:

### 16.1 New Icons Required

| Icon | Usage | Style Notes |
|------|-------|-------------|
| `UI_POS_SatelliteLinked.png` | Terminal screen indicator (satellite active) | Small dish icon with signal waves, green tint |
| `UI_POS_SatelliteUnlinked.png` | Terminal screen indicator (no satellite) | Small dish icon, greyed out, no signal |

### 16.2 Specifications

- **Dimensions**: 32x32 pixels, RGBA PNG (UI indicators, not inventory icons)
- **Style**: Simple, clear, readable at small size
- **Generator**: gpt-image-1 (~$0.18 per icon)
- **Estimated cost**: 2 icons x $0.18 = ~$0.36

---

## 17. Gameplay Loops

### Loop 1 — First Broadcast (Milestone Moment)

1. Player discovers satellite dish at a military base or communications tower
2. Gathers tools (screwdriver + wrench) and ensures building has generator power
3. Calibrates the dish (5-minute action, Electrical 3)
4. Returns to TV station with compiled intelligence artifacts
5. Brings artifact to satellite dish
6. Broadcasts — first regional market effect, reputation spike
7. Player feels: *"I am no longer just surviving. I am shaping the world."*

### Loop 2 — Regular Broadcasting (Endgame Loop)

1. Field recon → accumulate raw notes from diverse locations
2. Terminal analysis → process into Intel Fragments (SIGINT skill applies)
3. Camera compilation → produce Compiled Site Survey or Market Bulletin
4. Satellite broadcast → project intelligence regionally
5. Market shifts → new arbitrage opportunities emerge
6. Repeat with fresh field data

This loop is the **full POSnet pipeline** — the player engages with all four
tiers in sequence, each adding value.

### Loop 3 — Strategic Infrastructure Maintenance

1. Ensure generator at satellite location stays fuelled
2. Monitor calibration status (recalibrate if power was lost)
3. Defend satellite location from zombie incursions
4. Plan broadcast timing for maximum market impact

---

## 18. Implementation Phases

### Phase 1 — Core Broadcast (Minimum Viable)

- Sprite audit: identify and verify satellite dish sprite names in B42
- `POS_SatelliteService.lua` — calibration, broadcast strength, reputation
- `POS_SatelliteBroadcastAction.lua` — timed action (calibrate + broadcast)
- `POS_SatelliteContextMenu.lua` — right-click detection + sub-menu
- Constants in `POS_Constants.lua`
- Sandbox options: `EnableSatelliteUplink`, `SatelliteBroadcastCooldownHours`,
  `SatelliteCalibrationRequired`
- Translation keys
- Cooldown system (player modData)
- Calibration system (world modData)
- Power requirement check + fuel drain
- Check Signal Status action

### Phase 2 — Market Effects

- Market price propagation from broadcasts
- `SOURCE_TIER_BROADCAST` in `POS_MarketDatabase`
- Staleness multiplier in `POS_EconomyTick`
- Market coupling mechanics (sandbox-configurable)
- `SatelliteMarketCoupling`, `SatelliteBroadcastStrength` sandbox options

### Phase 3 — Terminal Link

- `POS_SatelliteService.isLinkedToTerminal()` detection
- Terminal Analysis satellite enhancement integration
- Background passive data accumulation
- `SatelliteLinkRange` sandbox option
- UI indicators for satellite link status

### Phase 4 — SIGINT Integration

- Broadcast credibility scaling with SIGINT level
- Propagation persistence modifier
- Misinformation resistance at high SIGINT

### Phase 5 — Polish

- Tutorial tooltip (one-time, PhobosLib notice system)
- Steam Workshop description update
- Documentation updates to `design-guidelines.md`
- Balance pass on market impact coefficients

---

## 19. Anti-Patterns — What the Satellite Must Never Become

1. **Not a signal booster.** The satellite does not simply "increase radio
   range." It unlocks entirely new classes of behaviour: regional broadcast,
   market coupling, reputation amplification.

2. **Not passive.** The satellite never auto-broadcasts. Every transmission is
   a deliberate player action consuming resources and time.

3. **Not a button press.** Broadcasting must feel heavy: consume artifacts,
   drain fuel, take time. It is an *operation*, not an interface element.

4. **Not easy.** Finding a dish, calibrating it, maintaining power, defending
   the location, and producing worthy artifacts to broadcast — the full
   pipeline requires sustained investment.

5. **Not required.** A player who never finds or uses a satellite dish
   experiences zero regression. All existing POSnet functionality remains
   fully operational at Tiers I-III.

6. **Not a win button.** Broadcasting does not "fix" markets or guarantee
   profits. It shifts probabilities and trends. Smart players exploit these
   shifts; careless players may create unfavourable conditions.

---

## 20. Future Possibilities (Explicitly Deferred)

These items build ON TOP of the satellite system and are not part of the
initial implementation:

- **Competing broadcasts (MP)** — multiple players/factions pushing conflicting
  data, creating information warfare
- **Signal strength & interference** — better dishes = wider influence,
  terrain effects on broadcast propagation
- **Encryption tiers** — military vs civilian broadcast networks
- **Broadcast decay** — truth fades unless refreshed by new broadcasts
- **Counter-intelligence** — false broadcasts, signal hijacking,
  misinformation warfare
- **Emergency alerts** — broadcasting danger warnings that affect NPC/zombie
  behaviour across the region
- **Settlement recruitment** — broadcasting settlement existence to attract
  NPC survivors (future NPC system)
- **Trade announcements** — broadcasting specific trade offers visible to
  other POSnet operators (MP)
- **Bounty postings** — broadcasting bounties on specific targets or
  resources (future faction system)

---

## 21. Relationship to Other Design Documents

| Document | Relationship |
|----------|-------------|
| `camera-workstation-design.md` | Camera Workstation produces the **compiled artifacts** that the satellite broadcasts |
| `terminal-analysis-design.md` | Terminal Analysis is **enhanced** by satellite link (confidence bonus, tier upgrades, passive data) |
| `sigint-skill-design.md` | SIGINT skill affects broadcast **credibility and persistence** (tertiary influence) |
| `data-recorder-design.md` | Recorder captures raw data that feeds the full pipeline ending at satellite |
| `passive-recon-design.md` | Passive recon devices capture raw data that feeds the full pipeline |
| `design-guidelines.md` | Satellite follows all existing guidelines; new section for uplink-specific rules |

The Satellite Uplink is the **projection layer** at the apex of the pipeline:

```
passive-recon → data-recorder → terminal-analysis → camera-workstation → SATELLITE
  (capture)     (buffering)     (understanding)     (compilation)        (projection)
      │              │                │                   │                    │
      └──────────────┴────────────────┴───────────────────┴────────────────────┘
                                      │
                              SIGINT SKILL
                         (analytical throughline)
```

---

## 22. Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| No confirmed B42 satellite dish sprite | **High** | Phase 1 begins with sprite audit; user confirmed moveable dish exists |
| Market impact too powerful (economy manipulation) | High | Broadcast strength capped; cooldowns; fuel cost; sandbox tuneable |
| Market impact too weak (not worth the effort) | Medium | Balance pass; reputation gain provides independent value |
| Power requirements too punishing | Medium | Sandbox options for fuel drain; grid power works without fuel |
| Calibration feels tedious | Low | Sandbox toggle to skip; 5 min is short for a milestone action |
| Late-game players have no new challenges | Low | Satellite maintenance + strategic broadcast timing provide ongoing engagement |

---

## 23. Success Criteria

The Satellite Uplink implementation is successful when:

1. A player who calibrates and broadcasts from a satellite dish feels a
   genuine sense of *influence* — the broadcast has visible market effects
2. The full Tier I-IV pipeline (field → terminal → camera → satellite) feels
   like a coherent, satisfying progression of investment and reward
3. Satellite locations (military bases, communication towers) become
   strategically valuable territory worth defending
4. The broadcast action feels *heavy and deliberate* — not a casual button
   press but a meaningful operation
5. Players who never use a satellite experience zero regression in all
   existing POSnet systems
6. Late-game players who maintain satellite infrastructure have a meaningful
   endgame activity loop

---

## 24. Passive Collection Mode

> **Status:** Design only — not yet implemented.
> **Prerequisite:** Satellite wiring connection (§5.6).

### 24.1 Overview

When a satellite dish is physically wired to a terminal, the player can enable
**Passive Collection Mode** — a persistent background process that gathers raw
signal data from the satellite uplink. This transforms the satellite from a
one-shot broadcast tool into an always-on intelligence appliance.

### 24.2 Three Operating States

| State | Power Draw | Behaviour |
|---|---|---|
| **Idle** | Standby (negligible) | Satellite linked, not collecting. All manual functions available. |
| **Passive Collection** | Heavy continuous | Generates raw intermediate data over time. Less efficient short-term, more efficient over very long durations. Requires powered + satellite link intact + collection mode enabled. |
| **Deep Sweep** | Extremely high | Temporary boosted late-game mode. Higher chance of rare/high-value intercepts. Increased wear and interruption risk. |

### 24.3 Core Design Principle

Passive collection must feel like **feeding a hungry machine**:
- Generator fuel burn is visible and painful
- Priority conflicts with refrigeration, lighting, industry
- Power stability matters — outages cause partial data loss
- Aspirational: a reward for advanced base infrastructure, not a default habit

### 24.4 Data Pipeline

```
Satellite → Passive Collection → Raw Data Backlog → Analysis/Processing → Useful Intel
```

Passive mode generates **intermediate resources** (not finished intelligence):
raw signal logs, recorded traffic fragments, market chatter snippets, unidentified
transmissions. The player then processes these — preserving player agency.

### 24.5 Failure Behaviours

If power cuts out during passive collection:
- No data gain for the outage period
- Small backlog corruption chance
- Partial data retained; terminal logs the outage
- Restart delay before reacquiring stable lock

Not brutal punishment — just enough to make stable infrastructure matter.

### 24.6 Output Quality Factors

- Satellite dish placement (rooftop = better)
- Terminal tier and operator SIGINT skill
- Power stability and band access (AZAS frequency coverage)
- Collection duration (longer ≠ automatically perfect)
- Weather / atmospheric interference

### 24.7 Future Expansion Hooks

- Wire degradation and environmental break chance
- Signal quality bonuses for elevation and shielded cable upgrades
- Lightning/storm disruption events
- Amplifiers, boosters, junction boxes
