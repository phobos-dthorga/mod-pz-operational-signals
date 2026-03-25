<!--
  ________________________________________________________________________
 / Copyright (c) 2026 Phobos A. D'thorga                                \
 |                                                                        |
 |           /\_/\                                                         |
 |         =/ o o \=    Phobos' PZ Modding                                |
 |          (  V  )     All rights reserved.                              |
 |     /\  / \   / \                                                      |
 |    /  \/   '-'   \   This source code is part of the Phobos            |
 |   /  /  \  ^  /\  \  mod suite for Project Zomboid (Build 42).         |
 |  (__/    \_/ \/  \__)                                                  |
 |     |   | |  | |     Unauthorised copying, modification, or            |
 |     |___|_|  |_|     distribution of this file is prohibited.          |
 |                                                                        |
 \________________________________________________________________________/
-->

# POSnet World Broadcast Network -- Design Document

**Branch**: `dev/world-broadcast-network` (future)
**Date**: 2026-03-25
**Status**: Design phase -- implementation not started
**Prerequisites**: Living Market active (see `living-market-design.md`),
Signal Ecology layer registered (see `signal-ecology-design.md`),
Free Agent System registered (see `free-agent-system.md`)

> **Design reference**: `design-guidelines.md` section 32.4 (voice packs),
> section 52 (transmission hierarchy)
> **Cross-references**: `broadcast-influence-design.md`,
> `radio-band-taxonomy-design.md`, `satellite-uplink-design.md`,
> `tier-v-strategic-relay-design.md`, `signal-ecology-design.md`,
> `passive-recon-design.md`

> **Boundary note**: This document describes the **delivery pipeline** --
> how simulation state becomes radio bulletins that players hear on vanilla
> receivers. For the downstream *influence* system (how broadcasts affect
> markets, agents, and trust), see `broadcast-influence-design.md`.

---

## 1. What It Is

The **POSnet World Broadcast Network (WBN)** is a persistent, semi-automated
radio bulletin system. It transforms internal simulation state into diegetic
radio broadcasts that players receive on vanilla radios, experienced as
floating text above the player's head.

**Core doctrine**:

> Treat the radio network as an editorialised living medium, not a debug
> output bus.

The chain from origin to player perception:

1. **World simulation** produces meaningful state changes.
2. **Candidate generation** wraps each change into a broadcast candidate.
3. **Editorial filtering** decides radio-worthiness -- most candidates die here.
4. **Voice-pack composition** renders the surviving candidate through a
   broadcaster archetype and tone.
5. **Channel scheduling** places the rendered bulletin into a station queue.
6. **Vanilla radio delivery** checks player proximity, device capability, and
   signal quality.
7. **Floating text** appears above the player's head.

The WBN does not create information. It re-presents information that already
exists in other POSnet subsystems, filtered through editorial judgement and
voice personality.

---

## 2. Five-Layer Architecture

### 2.1 Event Harvest Layer

The harvest layer watches existing POSnet systems for meaningful state
changes. It never speaks directly to the radio -- it only creates **broadcast
candidates** that enter the editorial queue.

**Sources watched**:

| # | Source                     | Example Events                                      |
|---|----------------------------|------------------------------------------------------|
| 1 | Market simulation          | Price spike, scarcity alert, surplus detected        |
| 2 | Wholesaler posture         | Posture shift (cautious → hoarding), new entrant     |
| 3 | Free-agent state           | Agent missing, route abandoned, new contact available |
| 4 | Route warnings             | Road blocked, corridor contested, new path opened    |
| 5 | Blackouts / grid events    | Power loss, relay failure, generator dependency surge |
| 6 | Faction activity           | Territory claimed, alliance formed, hostilities open |
| 7 | Military advisories        | Restricted zone declared, patrol route change        |
| 8 | Satellite broadcasts       | Tier IV uplink transmissions (re-broadcast eligible) |
| 9 | Player Tier IV/V actions   | Manual bulletin injection, channel steering          |

Each source produces zero or more candidates per evaluation tick. The harvest
layer applies no editorial judgement -- it merely translates state deltas into
a uniform candidate structure.

**Broadcast candidate schema**:

```lua
--- @class WBN_BroadcastCandidate
--- @field id              string   -- unique candidate identifier
--- @field domain          string   -- "economy"|"faction"|"infrastructure"|"operations"|"agent"|"rumour"
--- @field eventType       string   -- specific event classification
--- @field zoneId          string   -- geographic zone identifier
--- @field categoryId      string?  -- item/market category (economy domain)
--- @field severity        number   -- 0.0-1.0 how severe the underlying event is
--- @field confidence      number   -- 0.0-1.0 how reliable the source data is
--- @field freshness       number   -- 1.0 = just happened, decays toward 0.0
--- @field sourceType      string   -- originating subsystem
--- @field publicEligible  boolean  -- false = restricted/military net only
--- @field expiresAt       number   -- world-age-hours after which candidate is stale
local BroadcastCandidate = {
    id              = "cand_market_rosewood_med_shortage",
    domain          = "economy",
    eventType       = "scarcity_alert",
    zoneId          = "rosewood",
    categoryId      = "medicine",
    severity        = 0.63,
    confidence      = 0.78,
    freshness       = 1.0,
    sourceType      = "market_simulation",
    publicEligible  = true,
    expiresAt       = worldAgeHours + 18,
}
```

### 2.2 Editorial Layer

The editorial layer decides **radio-worthiness**. Most candidates never reach
a microphone. This is where spam dies.

**Editorial checks** (evaluated in order):

| # | Check                  | Rule                                                           |
|---|------------------------|----------------------------------------------------------------|
| 1 | Importance threshold   | `severity * confidence >= 0.35` (tunable per domain)           |
| 2 | Freshness gate         | `freshness >= 0.3` -- stale events are not newsworthy          |
| 3 | Repetition suppression | No bulletin with same `domain + eventType + zoneId` aired in   |
|   |                        | the last N hours (default 4, tunable per station class)        |
| 4 | Public/private gate    | `publicEligible == false` excludes civilian and emergency nets  |
| 5 | Similar-active check   | If a bulletin covering the same zone+category is still in the  |
|   |                        | active queue, the new candidate must score 20% higher to       |
|   |                        | displace it                                                    |
| 6 | Saturation cap         | Each station class has a maximum bulletin rate per hour;        |
|   |                        | excess candidates are ranked and the lowest-scoring are culled  |

**Scoring formula**:

```lua
local function scoreBulletin(candidate)
    local base = candidate.severity * candidate.confidence
    local freshBonus = candidate.freshness * 0.25
    local domainWeight = DomainWeights[candidate.domain] or 1.0
    return (base + freshBonus) * domainWeight
end
```

Candidates that survive editorial filtering advance to the composition layer
with an assigned **priority rank** (1 = highest) within their target channel.

### 2.3 Voice-Pack Composition Layer

The composition layer renders a surviving candidate into human-readable
bulletin text. The same event sounds different depending on **who is on air**.

**Broadcaster archetypes**:

| Archetype      | Tone               | Typical Channels                    |
|----------------|---------------------|--------------------------------------|
| Quartermaster  | Clipped, pragmatic  | Civilian Market, Operations          |
| Smuggler       | Wry, understated    | Grey/Whisper Net                     |
| Military       | Formal, terse       | Military/Restricted, Emergency       |
| Field Reporter | Conversational      | Civilian Market, Emergency           |
| Analyst        | Measured, cautious  | Operations, Civilian Market          |

**Bulletin Grammar System** -- composable templates, not canned lines:

Bulletins are assembled from slotted phrase banks. Each phrase bank is keyed
by domain, event type, and voice archetype. The grammar system composes a
bulletin from five slots:

1. **Opener** -- sets the register.
   - Quartermaster: "Attention all stations," / "Update follows."
   - Smuggler: "Word from the field:" / "Passing this along --"
   - Military: "Priority traffic." / "All units, be advised."
   - Field Reporter: "This just in:" / "Breaking from the wire --"
   - Analyst: "Situation update." / "Assessment follows."

2. **Subject phrase** -- names the thing being reported.
   - "Medical stock around Rosewood"
   - "Fuel reserves east of Muldraugh"
   - "Ammunition availability in the valley corridor"

3. **Condition phrase** -- describes the state change.
   - High confidence: "is tightening faster than expected"
   - Medium confidence: "appears to be softening after fresh arrivals"
   - Low confidence: "may have shifted, though sources are unclear"

4. **Qualifier** -- hedges or reinforces.
   - "Reports remain uneven on this."
   - "Multiple sources confirm."
   - "Take with a grain of salt."

5. **Closer** -- sign-off appropriate to voice.
   - Quartermaster: "Trade accordingly." / "Adjust plans."
   - Smuggler: "Stay sharp out there." / "You didn't hear this from me."
   - Military: "Out." / "End traffic."
   - Field Reporter: "More as it develops." / "We'll keep you posted."
   - Analyst: "Proceed with caution." / "Assessment is provisional."

**Assembled example** (quartermaster, economy, high confidence):

> "Attention all stations, medical stock around Rosewood is tightening faster
> than expected. Multiple sources confirm. Trade accordingly."

**Assembled example** (smuggler, economy, low confidence):

> "Word from the field: fuel east of Muldraugh may have shifted, though
> sources are unclear. Take with a grain of salt. Stay sharp out there."

**Voice-pack render input schema**:

```lua
--- @class WBN_VoiceRenderInput
--- @field voiceId        string  -- broadcaster archetype
--- @field domain         string  -- bulletin domain
--- @field eventType      string  -- specific event classification
--- @field confidenceBand string  -- "high"|"medium"|"low"
--- @field urgencyBand    string  -- "routine"|"moderate"|"urgent"|"critical"
--- @field zoneName       string  -- human-readable zone name
--- @field subjectName    string  -- human-readable subject
local VoiceRenderInput = {
    voiceId        = "quartermaster",
    domain         = "economy",
    eventType      = "scarcity_alert",
    confidenceBand = "high",
    urgencyBand    = "moderate",
    zoneName       = "Rosewood",
    subjectName    = "medical stock",
}
```

### 2.4 Scheduling and Channel Layer

Rendered bulletins are placed into **station class queues**. Each station
class represents a distinct radio channel personality with its own editorial
pace and audience.

**Five station classes**:

| # | Station Class              | Content Scope                                                     | Pace        |
|---|----------------------------|-------------------------------------------------------------------|-------------|
| 1 | Civilian Market Net        | Economy, trade, shortages, opportunities, price movements         | Moderate    |
| 2 | Operations Net             | Route warnings, agent updates, recon summaries, contact bulletins | Moderate    |
| 3 | Emergency / Public Service | Blackouts, grid instability, water/power, large hazards           | Low (burst) |
| 4 | Military / Restricted Net  | Requisitions, secure movement, controlled releases, tactical      | Low         |
| 5 | Grey / Whisper Net         | Smugglers, rumours, low-confidence leads, black-market activity   | Variable    |

**Scheduling rules**:

- Each station maintains a **bulletin queue** (priority-ordered).
- The scheduler pops the highest-priority bulletin when the channel's
  broadcast window opens.
- **Dead air** is intentional -- not every minute has a bulletin. Silence
  reinforces the sense that broadcasts are events, not wallpaper.
- **Headline cycle**: the top bulletin in each channel may re-broadcast once
  during its active window (decay reduces priority on repeat).
- **Pre-emption**: a critical-urgency bulletin can interrupt a lower-priority
  bulletin mid-window.

### 2.5 Delivery Layer

The final layer governs what the **player actually hears**. A bulletin is not
delivered simply because it was scheduled -- the player must satisfy physical
and equipment conditions.

**Delivery conditions** (all must be true):

1. Player is carrying or standing near an active radio receiver.
2. The receiver can access the target band (see receiver class table, sec. 9).
3. Signal quality at the player's location is sufficient for the channel.
4. The channel is currently broadcasting (not in dead air).
5. Local environmental conditions do not bury the message (extreme noise,
   deep underground with no relay).

**Player experience**:

- **Floating text** appears above the player's head (vanilla radio text
  system).
- Text is prefixed with a **radio-head flavour tag** identifying the station
  class (e.g., `[CMN]`, `[OPS]`, `[EMRG]`, `[MIL]`, `[GREY]`).
- An optional **broadcast history log** is accessible through the POSnet
  terminal, storing the last N bulletins received per channel.

---

## 3. Six Bulletin Families

Every bulletin belongs to one of six families. Each family has distinct
editorial priorities, voice tendencies, and scheduling characteristics.

### 3.1 Economy Bulletins

Price movements, scarcity alerts, surplus notifications, trade advisories.

> *Example*: "Attention all stations, ammunition pricing in the valley
> corridor has climbed roughly eight per cent following renewed shortages.
> Trade accordingly."

### 3.2 Faction Bulletins

Territory changes, alliance shifts, hostility declarations, faction
posture changes.

> *Example*: "Priority traffic. The northern coalition has declared the
> warehouse district a restricted zone effective immediately. All units,
> be advised. Out."

### 3.3 Infrastructure Bulletins

Power grid status, relay health, water system alerts, generator
dependency warnings.

> *Example*: "This just in: grid instability persists in eastern Muldraugh.
> Civilian power windows are narrowing. More as it develops."

### 3.4 Operations Bulletins

Route status, corridor safety, patrol observations, movement advisories.

> *Example*: "Update follows. The southern highway corridor is reporting
> increased contact density. Reroute where possible. Adjust plans."

### 3.5 Agent Bulletins

Free-agent status changes, missing operatives, new contacts, handler
alerts.

> *Example*: "Situation update. Contact BRAVO-7 has not reported in
> forty-eight hours. Last known position was the Rosewood fuel depot.
> Assessment is provisional."

### 3.6 Rumour / Low-Confidence Bulletins

Unverified leads, contradictory reports, whisper-net intelligence,
black-market chatter.

> *Example*: "Passing this along -- someone south of Muldraugh claims
> fuel is moving through unofficial channels at below market. Take with
> a grain of salt. You didn't hear this from me."

---

## 4. Semi-Automated Origin Model

Broadcast candidates enter the system through three origin paths. The origin
determines how much human (player) involvement shaped the bulletin.

### 4.1 Automatic Origin

The simulation produces candidates without player involvement. These are the
backbone of the WBN -- the world talks whether or not the player is listening.

**Trigger sources**: blackouts, scarcity thresholds, wholesaler posture
shifts, faction territory changes, agent status transitions.

The player cannot suppress automatic bulletins (except at Tier V). They
represent the baseline information climate.

### 4.2 Assisted Origin

The simulation detects a candidate-worthy event and **proposes** it to the
player for amplification. The player reviews and may authorise broadcast.

**Interaction**: a terminal notification appears: "Ammo demand spike detected
in Rosewood -- publish to Civilian Market Net?" The player confirms, edits
the urgency band, or dismisses.

Assisted origin requires **Tier IV** access. The player does not write the
bulletin -- the system composes it -- but the player decides whether it airs.

### 4.3 Manual Origin

The player authors a bulletin directly through the Tier IV/V interface.
Manual bulletins bypass the harvest layer entirely and enter editorial
filtering with player-assigned parameters.

**Use cases**: strategic rumours, disinformation campaigns, morale
broadcasts, targeted price manipulation signals.

Manual origin carries **trust and reputation risk** -- if the broadcast
contradicts observable reality, listener trust in that channel erodes over
time (see `broadcast-influence-design.md` for trust mechanics).

---

## 5. Economic Bulletin Design

Economic bulletins are the most frequent bulletin family. Their design
requires particular care to avoid monotony and to scale gracefully with
market complexity.

**Core rule**:

> Let the simulation think in pressure; let the radio speak in price
> movement.

The simulation tracks supply, demand, wholesaler posture, and scarcity
indices. The radio never exposes these internals. It speaks in percentage
changes, directional language, and cause framing.

### 5.1 Three Formats

| Format             | Scope                  | Example                                                    |
|--------------------|------------------------|------------------------------------------------------------|
| Category Movement  | Entire category        | "Medical supplies around Rosewood are up about twelve."    |
| Item Spotlight     | Single item            | "Antibiotics specifically have surged past twenty."        |
| Basket Summary     | Multi-category digest  | "Fuel steady, ammo climbing, medical under pressure."      |

### 5.2 Confidence Phrasing

The confidence band shapes how precisely the radio reports numbers.

| Band   | Phrasing Style                                | Example                        |
|--------|-----------------------------------------------|--------------------------------|
| High   | Exact integer, assertive language             | "Up twelve per cent."          |
| Medium | Approximate integer, hedged language          | "Up about twelve."             |
| Low    | Rounded estimate, speculative language        | "Said to be up around ten."    |

### 5.3 Broadcast Thresholds

Not every price movement is newsworthy. The editorial layer applies
percentage-based thresholds to economy candidates.

| Change Range | Treatment     | Editorial Note                         |
|--------------|---------------|----------------------------------------|
| 0--2%        | Ignore        | Noise -- not broadcast-worthy.         |
| 3--6%        | Light mention | May appear in basket summaries only.   |
| 7--12%       | Normal        | Standard single-category bulletin.     |
| 13--20%      | Strong        | Prioritised, may pre-empt lower items. |
| 20%+         | Headline      | Top of queue, headline cycle eligible.  |

### 5.4 Cause Framing

Where possible, the composition layer attaches a **cause tag** to give the
bulletin narrative weight.

| Cause Tag        | Phrasing Example                              |
|------------------|------------------------------------------------|
| `scarcity`       | "...after renewed shortages"                   |
| `grid_event`     | "...following grid interruption"               |
| `panic`          | "...traders blame panic buying"                |
| `surplus`        | "...as fresh stock arrives"                    |
| `faction_action` | "...linked to coalition activity in the area"  |
| `route_closure`  | "...after the southern corridor was shut down" |
| `unknown`        | (no cause phrase appended)                     |

### 5.5 Economic Bulletin Data Schema

```lua
--- @class WBN_EconomicBulletinData
--- @field zoneId         string  -- geographic zone
--- @field scope          string  -- "category"|"item"|"basket"
--- @field categoryId     string  -- market category
--- @field itemId         string? -- specific item (item spotlight only)
--- @field direction      string  -- "up"|"down"|"stable"
--- @field percentChange  number  -- absolute percentage change
--- @field compareWindow  string  -- "last_cycle"|"last_day"|"last_week"
--- @field confidenceBand string  -- "high"|"medium"|"low"
--- @field causeTag       string  -- cause classification
--- @field urgencyBand    string  -- "routine"|"moderate"|"urgent"|"critical"
local EconomicBulletinData = {
    zoneId         = "rosewood",
    scope          = "category",
    categoryId     = "medical",
    itemId         = nil,
    direction      = "up",
    percentChange  = 12,
    compareWindow  = "last_cycle",
    confidenceBand = "medium",
    causeTag       = "scarcity",
    urgencyBand    = "moderate",
}
```

---

## 6. Signal Degradation of Information

The WBN does not merely hide bulletins when signal quality drops. It
**degrades the content**, producing partial, uncertain, and sometimes
misleading fragments.

**Degradation effects by signal quality tier**:

| Signal Quality | Effect                                                         |
|----------------|----------------------------------------------------------------|
| Excellent      | Full bulletin, all detail intact.                              |
| Good           | Full bulletin, minor static flavour (cosmetic only).           |
| Fair           | Bulletin shortened: qualifier and cause framing may drop.      |
| Poor           | Names may drop out, numbers become vaguer, lines truncate.     |
| Minimal        | Only opener and fragments survive -- mostly noise.             |

**Degradation examples for the same underlying bulletin**:

**Excellent signal**:
> "This just in: grid instability persists in eastern Muldraugh. Civilian
> power windows are narrowing. Relay uptime has dropped below sixty per cent.
> More as it develops."

**Fair signal**:
> "This just in: grid instability persists in eastern Muldraugh. Power windows
> narrowing. More as it develops."

**Poor signal**:
> "...instability persists... Muldraugh... power windows narrowing..."

**Minimal signal**:
> "...grid... Muldraugh... ...narrowing..."

The degradation engine operates on the rendered bulletin text, not the
candidate data. It progressively removes clauses, truncates phrases, and
replaces precise terms with ellipses. The player never knows exactly what
was lost -- only that the signal was poor.

---

## 7. Signal Fragments (Tier 0.5 Intelligence)

Every broadcast a player hears can generate a **signal fragment** -- a piece
of soft intelligence. Fragments are not hard facts. They are hints, leads,
trends, early warnings, anomalies, and contradictions.

Signal fragments represent the **interpretive residue** of passive radio
monitoring. A player who listens to the radio regularly accumulates a
mosaic of partial knowledge that rewards attention and pattern recognition.

### 7.1 Fragment Schema

```lua
--- @class WBN_SignalFragment
--- @field type            string   -- fragment classification
--- @field zoneId          string   -- geographic zone
--- @field categoryId      string?  -- relevant market category
--- @field direction       string?  -- "up"|"down"|"stable" (market fragments)
--- @field estimatedChange number?  -- approximate magnitude (market fragments)
--- @field confidence      number   -- 0.0-1.0 how reliable the fragment is
--- @field freshness       number   -- 1.0 = fresh, decays toward 0.0
--- @field source          string   -- "radio_broadcast"
--- @field verified        boolean  -- false until independently confirmed
local SignalFragment = {
    type            = "market_fragment",
    zoneId          = "muldraugh",
    categoryId      = "fuel",
    direction       = "up",
    estimatedChange = 0.12,
    confidence      = 0.42,
    freshness       = 0.9,
    source          = "radio_broadcast",
    verified        = false,
}
```

### 7.2 Five Fragment Types

| # | Type              | Content                                                   | Typical Source Channels       |
|---|-------------------|-----------------------------------------------------------|-------------------------------|
| 1 | Market            | Price direction, approximate magnitude, category hint     | Civilian Market, Grey Net     |
| 2 | Route             | Corridor status, blockage hints, movement advisories      | Operations, Military          |
| 3 | Infrastructure    | Grid status, relay health, power window hints             | Emergency, Operations         |
| 4 | Agent / Faction   | Agent status, faction posture, territorial hints          | Operations, Military, Grey    |
| 5 | Anomaly           | Contradictions between sources, unexplained patterns      | Any (cross-channel detection) |

### 7.3 Confidence Rules

Radio-sourced fragments are **never high confidence**. The radio is a noisy,
editorialised, degradation-prone medium. Hard confirmation requires direct
observation or terminal analysis.

| Rule                         | Effect                                             |
|------------------------------|----------------------------------------------------|
| Base confidence range        | 0.20 -- 0.60 (radio fragments never exceed 0.60)  |
| Signal quality modifier      | Poor signal reduces confidence by up to 0.15       |
| Repetition across broadcasts | Each independent repetition adds 0.05 (capped)     |
| Contradiction detected       | Reduces confidence by 0.10 per contradiction        |
| Age decay                    | Freshness decays; confidence floor is 0.10          |

### 7.4 Gameplay Loop

The intelligence loop for radio-sourced fragments:

1. **Passive intake** -- player hears bulletins on the radio.
2. **Interpretation** -- player (or terminal analysis) extracts fragments.
3. **Action** -- player acts on fragment intelligence (trade, move, prepare).
4. **Validation** -- outcome confirms or contradicts the fragment.
5. **Feedback** -- validated fragments feed back into the system, improving
   future confidence calibration.

This forms a **closed intelligence loop** -- the radio is not a one-way
information dump but the first stage of an active intelligence cycle.

---

## 8. Tier IV/V Interaction

The WBN intersects with the player's progression through two tier gates.

### 8.1 Tier IV -- Data Plane to Broadcast Plane

Tier IV bridges the **data plane** (what the player knows) and the
**broadcast plane** (what the world hears). The doctrine:

> The world will hear this.

**Tier IV capabilities**:

| Capability               | Description                                            |
|--------------------------|--------------------------------------------------------|
| Inject bulletin          | Push a manual bulletin into editorial filtering.       |
| Shape public bulletins   | Modify urgency band or confidence framing before air.  |
| Push narrative           | Sustain a bulletin across multiple broadcast windows.   |
| Seed rumour              | Inject low-confidence bulletin into Grey/Whisper Net.  |

### 8.2 Tier V -- Broadcast Fabric Governance

Tier V governs the **broadcast fabric itself** -- not individual bulletins
but the structure and behaviour of the entire WBN. The doctrine:

> This is how the world will hear things.

**Tier V capabilities**:

| Capability               | Description                                            |
|--------------------------|--------------------------------------------------------|
| Prioritise nets          | Re-order station class priority rankings.              |
| Allocate airtime         | Expand or contract broadcast windows per channel.      |
| Amplify / suppress       | Boost or dampen specific domain bulletins system-wide.  |
| Improve reach            | Invest in relay infrastructure to extend coverage.     |
| Schedule headline cycles | Control which bulletins enter headline rotation.        |

---

## 9. Device Behaviour by Receiver Class

Not all radios are equal. The receiver class determines which bands and
channels the player can access.

| Receiver Class          | Data Band | Civilian Mkt | Operations | Emergency | Military | Grey Net |
|-------------------------|-----------|--------------|------------|-----------|----------|----------|
| Handheld civilian radio | --        | Yes          | --         | Yes       | --       | --       |
| Terminal (POSnet)       | Full      | Yes          | Yes        | Yes       | Limited  | Yes      |
| Ham / advanced radio    | --        | Yes          | Yes        | Yes       | --       | Yes      |
| Military manpack        | --        | Yes          | Yes        | Yes       | Yes      | --       |
| Vehicle radio           | --        | Yes          | Limited    | Yes       | --       | Limited  |

**Notes**:

- **Data band** is the POSnet data channel (structured data, not voice
  bulletins). Only terminals access this. The WBN operates exclusively on
  **broadcast bands** (voice-style bulletins).
- **Limited** access means the device can receive the channel but at reduced
  signal quality (one tier penalty).
- Military manpack receivers intentionally exclude Grey Net -- military
  doctrine does not acknowledge unofficial channels.
- Ham/advanced radios pick up Grey Net due to wider frequency scanning.

---

## 10. Power Grid Broadcasting

Infrastructure state is a first-class source for the WBN. Each zone
maintains a set of grid health indicators that feed the harvest layer.

**Per-zone infrastructure indicators**:

| Indicator              | Range     | Description                                           |
|------------------------|-----------|-------------------------------------------------------|
| Grid stability         | 0.0--1.0  | Overall power grid health.                            |
| Blackout chance        | 0.0--1.0  | Probability of imminent blackout event.               |
| Relay uptime           | 0.0--1.0  | Fraction of communication relays operational.         |
| Generator dependency   | 0.0--1.0  | How much the zone relies on generators vs mains.      |
| Fuel reserve stress    | 0.0--1.0  | Pressure on local fuel reserves from generator use.   |

**Meaningful thresholds** that trigger broadcast candidates:

| Indicator            | Threshold   | Candidate Generated                                  |
|----------------------|-------------|------------------------------------------------------|
| Grid stability       | < 0.40      | "Grid instability warning" -- Emergency Net          |
| Blackout chance      | > 0.60      | "Blackout risk advisory" -- Emergency Net            |
| Relay uptime         | < 0.50      | "Communications degraded" -- Operations Net          |
| Generator dependency | > 0.75      | "Generator dependency alert" -- Civilian Market Net  |
| Fuel reserve stress  | > 0.80      | "Fuel reserve pressure" -- Civilian Market Net       |

These candidates enter editorial filtering like any other. A zone with
chronic low grid stability will not produce a bulletin every tick -- the
repetition suppression check (sec. 2.2) prevents saturation.

---

## 11. Performance

The WBN must remain lightweight. Radio bulletins are flavour and intelligence
-- they must never degrade frame rate or server tick performance.

**Design principles**:

1. **Aggregate-first**: the harvest layer reads aggregate state (zone-level
   summaries, category-level prices), never per-item or per-NPC data.
2. **Interval generation**: candidate generation runs at a configurable
   interval (default: every 10 in-game minutes), not every tick.
3. **Channel queue model**: the scheduling layer maintains fixed-size queues
   per station class (default: 8 slots). Overflow is culled by priority.
4. **Delivery check scope**: on each delivery tick, the system checks only
   actual players (not NPCs) and only devices within interaction range.
5. **Emit-once**: a bulletin is emitted to a player once per broadcast
   window. No repeated delivery of the same rendered text.
6. **Rolling history**: the broadcast log retains the last N bulletins per
   channel (default: 20). Older entries are discarded, not archived.
7. **No per-NPC simulation**: NPCs do not receive or react to WBN bulletins.
   NPC behaviour is governed by the systems the WBN merely reports on.

**Estimated cost per tick** (delivery phase only):

| Operation                        | Cost     |
|----------------------------------|----------|
| Check active players             | O(P)     |
| Check nearby devices per player  | O(D)     |
| Channel queue read               | O(C)     |
| Total per delivery tick          | O(P * D * C) -- all constants are small |

Where P = active players (1 in single-player), D = devices within range
(typically 0--2), C = station classes (5).

---

## 12. Implementation Phases

### Phase 1 -- Foundation

- Civilian Market Net and Emergency/Public Service channels operational.
- Automatic economy bulletins (category movement format).
- Automatic blackout/grid bulletins.
- Handheld and vehicle radio reception.
- Floating text delivery via vanilla radio system.
- Simple voice-pack templating (quartermaster and field reporter archetypes).
- Broadcast candidate pipeline: harvest → editorial → composition → schedule → deliver.

### Phase 2 -- Depth

- Operations Net channel operational.
- Faction voice archetypes (military, analyst).
- Route warning bulletins.
- Agent status bulletins.
- Signal degradation rendering (fair/poor/minimal tiers).
- Signal fragment generation from received bulletins.
- Item spotlight and basket summary economic formats.

### Phase 3 -- Player Agency

- Tier IV manual bulletin injection.
- Assisted origin (simulation-proposed, player-approved).
- Strategic rumour seeding via Grey/Whisper Net.
- Trust and reliability tracking for manual bulletins.
- Regional weighting (broadcasts carry more weight near origin zone).
- Cause framing system active on all economic bulletins.

### Phase 4 -- Mastery

- Tier V channel steering and airtime allocation.
- Rebroadcast priority control.
- Relay synchronisation (multi-zone bulletin propagation delay).
- Military/Restricted Net fully operational.
- Grey/Whisper Net expanded with smuggler archetype.
- Headline cycle scheduling under player control.
- Full five-archetype voice-pack system.

---

## 13. Anti-Patterns

The following patterns are explicitly prohibited in WBN implementation.

| Anti-Pattern                        | Why It Is Wrong                                          |
|-------------------------------------|----------------------------------------------------------|
| Raw simulation data on radio        | The radio is editorialised. Players hear prose, not JSON. |
| Notification spam                   | Dead air is intentional. Silence is a feature.            |
| Per-NPC broadcast simulation        | NPCs do not listen to the radio. Cost is unjustifiable.   |
| Data band content on broadcast band | Data and voice are separate channels with separate rules.  |
| Guaranteed delivery                 | Signal, device, and location must all align. No freebies.  |
| Bypassing editorial filtering       | Every candidate -- including manual -- passes editorial.   |
| Exposing confidence as a number     | The radio says "reports are mixed", not "confidence 0.4".  |
| Identical phrasing across voices    | If two archetypes sound the same, the system has failed.   |

---

## 15. Implementation Notes (Phase 1)

### 15.1 Vanilla PZ Radio API

WBN Phase 1 uses PZ Build 42's `DynamicRadio` system (same pattern as
the Unseasonal Weather mod). Key classes:

- `DynamicRadioChannel.new(name, freq, category, uuid)` — channel registration
- `RadioBroadCast.new(id, x, y)` — broadcast container (`-1, -1` for global reach)
- `RadioLine.new(text, r, g, b)` — individual coloured text line
- `channel:setAiringBroadcast(bc)` — emit broadcast on channel
- `Events.OnDeviceText` — client event fired when player's radio receives text

Channel categories available: `ChannelCategory.Amateur`, `.Emergency`,
`.Military`, `.Radio`, `.Television`, `.Bandit`, `.Other`.

### 15.2 Starlit Event Integration

The harvest layer subscribes to Starlit `LuaEvent` instances defined in
`POS_Events.lua` rather than polling:

- `POS_Events.OnStockTickClosed` → economy candidate generation
- `POS_Events.OnMarketEvent` → infrastructure/emergency candidates

### 15.3 PhobosLib Utilities

| Utility | Used For |
|---------|----------|
| `PhobosLib.safecall()` | Wrap DynamicRadio API calls (may be nil) |
| `PhobosLib.safeGetText()` | All translation key resolution |
| `PhobosLib.debug()` | Diagnostic logging |
| `PhobosLib.clamp()` | Pressure value clamping |
| `PhobosLib_Radio` | Device classification (future phases) |

### 15.4 ModData Patterns

Broadcast history is stored in player ModData at
`player:getModData().POSNET.BroadcastHistory`. Java-table-safe access
rules apply: string keys, `pairs()` iteration, no `#` operator or
`table.insert()`.

### 15.5 Translation Key Conventions

All WBN translation keys use the `UI_WBN_*` prefix:

| Pattern | Example |
|---------|---------|
| `UI_WBN_Channel_*` | Channel display names |
| `UI_WBN_StationTag_*` | Broadcast prefix tags |
| `UI_WBN_Phrase_<Slot>_<Arch>_<N>` | Grammar phrase pools |
| `UI_WBN_Phrase_Cause_*` | Cause framing suffixes |
| `UI_WBN_Phrase_ConfMod_*` | Confidence modifiers |

### 15.6 Voice Pack Integration

The opener and closer grammar slots are resolved through the Voice Pack
Registry rather than hardcoded phrase banks. This follows the data-pack
extensibility pattern (§32.4).

**Resolution chain**:
1. Query `POS_VoicePackRegistry.getOverride(archetypeId, "wbn_opener")`
2. If found: load text pool definition via `require(poolId)`
3. Extract translation keys from pool entries
4. If not found: fall back to `DEFAULT_OPENERS[archetypeId]`

**Phase 1 voice packs**:

| Archetype | Opener Pool | Closer Pool |
|-----------|------------|------------|
| quartermaster | `voice_wbn_quartermaster_openers` | `voice_wbn_quartermaster_closers` |
| field_reporter | `voice_wbn_field_reporter_openers` | `voice_wbn_field_reporter_closers` |

**Addon extensibility**: To add a custom radio voice (e.g., "smuggler"),
create a voice pack definition with `wbn_opener` and `wbn_closer` overrides
pointing to new text pool files. No changes to CompositionService required.

---

## 16. Cross-References

| Document                              | Relationship                                          |
|---------------------------------------|-------------------------------------------------------|
| `broadcast-influence-design.md`       | Downstream: how broadcasts affect markets and agents.  |
| `radio-band-taxonomy-design.md`       | Defines data vs broadcast band separation.             |
| `satellite-uplink-design.md`          | Tier IV transmission feeds WBN candidate queue.        |
| `tier-v-strategic-relay-design.md`    | Tier V relay infrastructure extends WBN reach.         |
| `signal-ecology-design.md`            | Signal quality model governs delivery and degradation. |
| `passive-recon-design.md`             | Recon observations may generate WBN candidates.        |
| `design-guidelines.md` sec. 32.4      | Voice-pack design rules and archetype constraints.     |
| `design-guidelines.md` sec. 52        | Transmission hierarchy and channel priority rules.     |
