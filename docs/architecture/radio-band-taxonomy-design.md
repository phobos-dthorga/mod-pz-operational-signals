<!-- =========================================================================
     PhobosOperationalSignals — Radio Band Taxonomy Design
     Copyright (c) 2026 phobosgekko. All rights reserved.
     Part of the Phobos PZ mod suite for Project Zomboid Build 42.
     ========================================================================= -->

# Radio Band Taxonomy Design

> Formalises the separation between **data transport bands** and **public
> broadcast bands** within the POSnet radio architecture. This document is
> the authoritative reference for which payloads travel on which plane, which
> devices can access each plane, and how information crosses the boundary
> between them.

---

## 1. The Three Radio Domains

**Core rule:** *Data bands carry payloads. Broadcast bands carry
interpretations.*

POSnet divides all radio activity into three domains. Two are
network-facing data planes; one is a listener-facing broadcast plane. No
device should conflate the two unless it is explicitly acting as a bridge
(see Section 5).

### 1.1 Civilian Data Band

| Property        | Value                                                  |
|-----------------|--------------------------------------------------------|
| Orientation     | POSnet-facing, structured, non-public-first            |
| Security grade  | Lower — operational but not restricted                 |
| Access devices  | Terminals, higher-end data-capable radios, relay gear  |

**Carries:**

1. Market packets (price deltas, supply snapshots, demand signals).
2. Agent telemetry (position pings, status heartbeats).
3. Route advisories (road condition flags, hazard markers).
4. Uplink / downlink data (satellite handshake frames).
5. Bulletin drafts (pre-editorial content awaiting promotion).
6. Authentication and handshake traffic.
7. Terminal-to-terminal exchanges (queries, acknowledgements).

The Civilian Data Band is the workhorse of POSnet. Most structured
information originates here before it is optionally promoted into the
broadcast plane.

### 1.2 Tactical Data Band

| Property        | Value                                                        |
|-----------------|--------------------------------------------------------------|
| Orientation     | POSnet-facing, structured, restricted, higher-value          |
| Security grade  | Higher — military or privileged operational traffic           |
| Access devices  | Terminals, military/manpack/base-station gear, sat-assisted  |

**Carries:**

1. Tactical advisories (threat assessments, engagement notices).
2. Military and restricted contact traffic.
3. Higher-grade route intelligence (convoy corridors, denied zones).
4. Agent coordination (tasking orders, rendezvous confirmations).
5. Strategic packets (campaign-level directives).
6. High-priority uplink events (emergency relay escalations).

The Tactical Data Band is **not** public listening — it is network traffic.
Ordinary receivers cannot decode it; specialised military or terminal
equipment is required.

### 1.3 Broadcast Bands

| Property        | Value                                                    |
|-----------------|----------------------------------------------------------|
| Orientation     | Listener-facing, scheduled or semi-live, editorialised   |
| Security grade  | Public (with the exception of Grey / Whisper Net)        |
| Access devices  | Any receiver — car radios, handhelds, ham sets, terminals |

**Sub-bands:**

| Sub-band                         | Character                                  |
|----------------------------------|--------------------------------------------|
| Public Service / Emergency       | Civil defence alerts, evacuation orders     |
| Market Broadcast Service         | Editorialised price and trade summaries     |
| Operations / Intelligence News   | Curated situation reports, area briefings   |
| Grey / Whisper Net               | Unverified, fragmentary, rumour-grade       |
| Military Broadcast (future)      | Authorised military communiques             |

Broadcast bands are what ordinary radios tune into. Content here has
already passed through an editorial or templating step — it is designed to
be intelligible to any listener without specialist equipment or training.

---

## 2. Why Separation Matters

### 2.1 Device Identity

The separation preserves a clean identity for every device class:

- **Terminal** = intelligence workstation, packet terminal, signal-analysis
  node. It speaks in structured data.
- **Car radio** = receiver, bulletin listener, ambient world information
  source. It speaks in natural language.

Mixing the two collapses device identity. A car radio that dumps raw
`price_delta` packets is incoherent; a terminal that only plays
editorialised audio is under-utilised. Each device should behave according
to its nature.

### 2.2 Signal Semantics

Data nets and broadcast nets have fundamentally different requirements:

| Concern            | Data Nets                              | Broadcast Nets                          |
|--------------------|----------------------------------------|-----------------------------------------|
| Payload format     | Structured, machine-parseable          | Editorialised, human-readable           |
| Addressing         | Routed, filtered, confidence-tagged    | Scheduled, timed, geographically zoned  |
| Audience           | Operators, terminals, relay nodes      | General population, ambient listeners   |
| Tone               | Terse, numerical, coded                | Narrative, contextual, spoken           |

### 2.3 Player Understanding

The player mental model should be immediately clear:

- **"Terminal bands = this is where POSnet does network work."**
- **"Broadcast bands = this is where I listen to the world."**

If the player can articulate this distinction without reading documentation,
the taxonomy is doing its job.

---

## 3. Band-to-Device Access Matrix

The following matrix defines what each device class can do on each band.
Blank cells indicate no access.

| Device Class          | Civilian Data   | Tactical Data   | Public Broadcast | Emergency | Grey / Whisper | Military Broadcast |
|-----------------------|-----------------|-----------------|------------------|-----------|----------------|--------------------|
| POSnet Terminal       | Full decode     | Full decode     | Compose only     | Compose   | —              | —                  |
| Handheld Civilian     | —               | —               | Receive          | Receive   | Fragments      | —                  |
| Ham / Advanced        | Sniff (low conf)| —               | Receive (high)   | Receive   | Receive        | —                  |
| Military / Manpack    | Partial decode  | Receive         | Receive          | Receive   | Sniff          | Receive            |
| Vehicle Radio         | —               | —               | Receive (ambient)| Receive   | —              | —                  |
| Satellite Dish (IV)   | Bridge to bcast | Relay           | Amplify          | Amplify   | —              | —                  |
| Strategic Relay (V)   | Route + govern  | Route + govern  | Govern scheduling| Govern    | Govern         | Govern             |

**Key terminology:**

- *Full decode* — structured payload fully readable and actionable.
- *Partial decode* — some fields readable; others encrypted or truncated.
- *Sniff (low conf)* — fragments intercepted but with low confidence.
- *Receive* — standard listener reception of editorialised content.
- *Compose* — ability to author and push content onto the band.
- *Bridge* — convert data-plane content into broadcast-plane content.
- *Relay / Amplify* — retransmit without editorial transformation.
- *Route + govern* — full network control over traffic and scheduling.

### 3.1 AZAS Frequency Assignment

All POSnet radio stations — both data bands and broadcast bands — are
registered with the **AZAS Frequency Index** for dynamic per-world frequency
assignment and deconfliction with other radio mods.

| AZAS Station Key          | Band Domain     | Device Type | Default Freq |
|---------------------------|-----------------|-------------|-------------|
| `POSnet_Operations`       | Civilian Data   | amateur     | 130.0 kHz   |
| `POSnet_Tactical`         | Tactical Data   | military    | 155.0 kHz   |
| `POSnet_WBN_Market`       | Public Broadcast| amateur     | 91.4 MHz    |
| `POSnet_WBN_Emergency`    | Emergency       | amateur     | 103.8 MHz   |

WBN broadcast channels use AZAS `device_type = "amateur"` because public
broadcasts are receivable on standard civilian radios. The logical distinction
between data bands and broadcast bands is enforced at the application layer
(see §4), not at the frequency assignment layer.

When AZAS is unavailable, all stations fall back to their default frequencies.
Runtime frequency lookups are cached after first AZAS resolution via
`POS_AZASIntegration.getWBNMarketFrequency()` /
`POS_AZASIntegration.getWBNEmergencyFrequency()`.

### 3.2 Terminal Access Restriction

Only **data bands** (Civilian Data Net, Tactical Data Net) provide access
to POSnet terminal services. WBN broadcast bands are **receive-only** —
tuning a radio to a broadcast frequency and attempting to connect a
terminal will display an explanatory gate message directing the player to
tune to a data channel instead.

This is enforced in `POS_ConnectionManager` via
`POS_AZASIntegration.isBroadcastBand(band)`. The helper returns true for
`"wbn_market"` and `"wbn_emergency"` bands, false for `"operations"` and
`"tactical"`.

This separation enforces §4: data bands carry payloads, broadcast bands
carry interpretations. A terminal is a data processing device — it
requires structured network traffic, not editorialised public bulletins.

---

## 4. The Translation Boundary

Data and broadcast are separated by a **translation boundary**. Raw
structured data must be transformed before it becomes a public bulletin.

### 4.1 Examples

| Data Band Receives                            | Public Radio Says                                             |
|-----------------------------------------------|---------------------------------------------------------------|
| `ammo.price_delta = +12%`                     | "Ammunition is up twelve percent in West Point."              |
| `grid.zone.rosewood.stability = 0.34`         | "Rosewood's power situation is deteriorating again."          |
| `agent.contact.status = degraded`             | *(Potentially nothing — unless promoted to a public bulletin)*|
| `route.advisory.muldraugh.hazard = high`      | "Travellers are advised to avoid the Muldraugh corridor."     |
| `medical.supply.rosewood.delta = +11%`        | "Medical supplies are up eleven percent in Rosewood."         |

The translation boundary enforces editorial discretion: not everything on
the data plane deserves airtime on the broadcast plane.

---

## 5. Bridging Rules

### 5.1 Tier IV Bridge (Data to Broadcast)

Tier IV satellite infrastructure lets the player convert data artefacts
into public bulletins. Specifically, Tier IV enables the player to:

1. Promote data packets into the broadcast layer.
2. Seed rumours from structured findings.
3. Push selected narratives outward to listeners.
4. Convert raw telemetry into editorialised summaries.

Tier IV is a **bridge** between the data plane and the broadcast plane. It
is the primary mechanism by which structured POSnet intelligence becomes
public-facing content.

### 5.2 Tier V Governance (Both Planes)

Tier V strategic relay infrastructure governs both planes simultaneously.
Tier V enables the player to:

1. Prioritise which data domains get promoted to broadcast.
2. Control rebroadcast policy (frequency, reach, repetition).
3. Route data between nodes on the data plane.
4. Influence editorial weighting of public bulletins.
5. Gate what stays private versus what becomes public.

Tier V is the **network governor** across both planes.

### 5.3 Advanced Equipment Bridging

Some radios and terminal modules can act as bridging decoders: they listen
to data bands and render simplified human-readable summaries. The output is
distinct from true broadcast content:

| Source              | Player Hears                                                      |
|---------------------|-------------------------------------------------------------------|
| Bridging decoder    | "Decoded civilian traffic suggests medical prices are rising."    |
| Broadcast reception | "Medical supplies are up eleven percent in Rosewood."             |

The bridging decoder output is rougher, less contextualised, and lacks the
editorial framing of a true broadcast bulletin. This distinction reinforces
the value of the broadcast plane.

---

## 6. Floating Text Presentation by Source

In-world floating text should visually distinguish the origin of
information:

| Source Type                   | Presentation Style        | Example                                              |
|-------------------------------|---------------------------|------------------------------------------------------|
| Broadcast reception           | Natural, spoken cadence   | "Medical supplies are up eleven percent in Rosewood." |
| Data interception             | Clipped, operator-format  | `CIV-DATA: MEDICAL / ROSEWOOD / +11 / MEDIUM CONF`  |
| Bridging decoder              | Paraphrased, tentative    | "Decoded traffic suggests medical prices are rising." |
| Tactical intercept (partial)  | Fragmented, redacted      | `TAC-DATA: [REDACTED] / MULDRAUGH / THREAT: HIGH`   |

The visual treatment (font, colour, formatting) is implementation-specific
and defined in the signal ecology layer, but the **tonal distinction** is
mandated here.

---

## 7. Naming Convention

To avoid ambiguity now that both data and broadcast planes coexist, the
following naming convention is authoritative:

| Concept                        | Canonical Name                | Avoid                          |
|--------------------------------|-------------------------------|--------------------------------|
| Civilian data transport        | Civilian Data Net             | "civilian band"                |
| Tactical data transport        | Tactical Data Net             | "tactical band"                |
| Public trade summaries         | Market Broadcast Service      | "market channel", "trade band" |
| Civil defence alerts           | Emergency Broadcast Service   | "emergency channel"            |
| Curated situation reports      | Operations Bulletin Service   | "ops channel", "intel band"    |
| Unverified / rumour traffic    | Whisper Net                   | "grey band", "rumour channel"  |
| Local settlement transmissions | Settlement Radio              | "local band"                   |

All code identifiers, UI labels, and design documents should use the
canonical names from this table.

---

## 8. Cross-References

This document intersects with the following design documents:

| Document                                  | Relevance                                          |
|-------------------------------------------|----------------------------------------------------|
| `world-broadcast-network-design.md`       | Broadcast plane scheduling and content system       |
| `broadcast-influence-design.md`           | Editorial weighting and narrative shaping           |
| `satellite-uplink-design.md`              | Tier IV bridging mechanics                          |
| `tier-v-strategic-relay-design.md`        | Tier V governance across both planes                |
| `signal-ecology-design.md`               | Visual/audio presentation of all signal types       |
| `passive-recon-design.md` SS 2.3          | Passive interception of data-band fragments         |
| `design-guidelines.md` SS 54              | General design principles for radio systems         |

---

*End of document.*
