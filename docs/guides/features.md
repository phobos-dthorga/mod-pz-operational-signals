# POSnet Features

A player-friendly overview of everything POSnet offers.

---

## Market Intelligence

POSnet tracks **16 commodity categories** across the game world. The Markets
hub provides several screens for understanding the economy:

- **Market Overview** -- consolidated view of category prices, intel
  confidence levels, and zone supply pressure.
- **Watchlist** -- track categories you care about and see price movement
  over time.
- **Market Signals** -- event log showing rumours, price shifts, and
  economic disruptions as they happen.
- **Market Reports** -- deeper analysis of market trends when you have
  enough data.
- **Trade Catalog** -- browse available goods with inline purchase
  confirmation.

Market data comes from multiple sources: ambient radio chatter (passive),
active scanning with a Data Recorder, camera intelligence, and satellite
feeds. Higher-quality sources give more accurate and detailed information.

---

## Signal Interception (SIGINT)

The **SIGINT skill** is a custom perk with 10 levels. It represents your
character's ability to intercept, decode, and analyse radio signals.

- **Passive recon** -- ambient intelligence gathered automatically while a
  radio is tuned to AZAS frequencies. Requires no special equipment.
- **Active recon** -- use a **Data Recorder** near a radio to actively scan
  for detailed market and operational intelligence. Yields more XP and
  better data.
- **Compiled intelligence** -- use a **Camera Workstation** to process
  photographic evidence into actionable intel. Higher tier, more XP.
- **Broadcast intelligence** -- a **Satellite Uplink** lets you compile and
  broadcast intelligence at the highest tier.

Higher SIGINT levels unlock terminal screens, improve data quality, boost
operation rewards, and increase negotiation success rates.

---

## Trading

Once you reach **SIGINT Level 3**, the **Known Contacts** screen becomes
available under the Markets hub. From here you can:

- Browse traders and wholesalers operating in different zones.
- Buy and sell commodities at market-driven prices.
- Track trader inventory and specialisations.

Prices vary by zone, supply pressure, and data confidence. Better
intelligence means better deals.

---

## Operations

The **BBS** (Bulletin Board System) hub contains your mission content:

- **Operations** -- multi-objective missions ranging from Tier I (low risk,
  no cancel penalty) to Tier IV (high risk, high reward). Objectives may
  include travelling to locations, photographing targets, or retrieving
  items.
- **Deliveries** -- transport packages between locations. Cancellation
  penalties double if you have already picked up the package.
- **Investments** -- spend Base.Money on investment opportunities that
  mature over time, resolved server-side.

Before accepting any mission, you can **negotiate terms**: request higher
pay (at the cost of a tighter deadline) or more time (at reduced reward).
Negotiation success scales with your reputation tier.

---

## Living Market

When the **Living Market** sandbox option is enabled, the economy runs
autonomously:

- **Market agents** (traders, smugglers, military contacts) buy and sell
  commodities on their own schedules.
- **Wholesalers** supply goods to zones, creating regional price
  differences.
- **Supply pressure** shifts dynamically based on agent activity, zone
  events, and player actions.
- **Market events** (shortages, surpluses, trade disruptions) emerge
  organically from the simulation.

The Living Market is off by default. Enable it in Sandbox Settings under
the POSnet section if you want a more dynamic economy.

---

## Terminal Customisation

The POSnet terminal is fully customisable:

- **4 colour themes** -- choose the CRT aesthetic that suits you.
- **4 font sizes** -- from compact to large, depending on your resolution.
- **Resizable window** -- drag the terminal edges to resize.
- **CRT effects** -- scanline overlay and bezel for authentic retro feel.

Access these options from the terminal Settings screen.

---

## World Broadcast Network (Radio Bulletins)

POSnet's World Broadcast Network (WBN) converts simulation state into
diegetic radio bulletins receivable on vanilla radios. Tune to the Market
Broadcast Service or Emergency Broadcast Service to hear:

**Market intelligence** — price movements, supply changes, and trade
conditions voiced by quartermaster, trader, wholesaler, crafter, and
speculator archetypes. Each has a distinct personality.

**Weather reports** — real-time weather conditions from the game world.
Rain, snow, fog, extreme temperatures, and storm-force winds are reported
as they happen.

**Power grid updates** — grid failure and restoration events. When mains
power goes down, the Emergency channel broadcasts the event. When power
is restored (including by mods), a restoration notice follows.

**World atmosphere** — during quiet periods, the radio carries general
apocalypse-world flavour: trade rumours, safety advisories, scavenging
reports, and community updates.

**Intelligence feedback** — listening to broadcasts generates Signal
Fragments (low-confidence intelligence) that appear in your terminal's
market data. Repeated broadcasts about the same topic build confidence;
contradicting broadcasts reduce it. Intel discoveries trigger a
notification toast.

Frequencies are assigned dynamically via AZAS Frequency Index. Check your
radio dial for the Market Broadcast and Emergency Broadcast channels.

### How it works

Bulletins are generated automatically from the **Living Market** simulation
through a five-layer pipeline:

1. **Event Harvest** — watches economy ticks and market events for meaningful
   changes. When no pressure deltas occur (e.g. early game), ambient baseline
   reports are generated from absolute zone pressure.
2. **Editorial Filter** — scores candidates for importance, freshness, and
   uniqueness. Low-value or repetitive items are suppressed.
3. **Voice-Pack Composition** — assembles bulletin text from composable phrase
   templates (openers, subjects, conditions, qualifiers, closers) voiced
   through archetype personalities. All 9 archetypes have WBN radio voices.
4. **Channel Scheduling** — queues bulletins per station class with minimum
   cadence intervals (10 min market, 5 min emergency).
5. **DynamicRadio Delivery** — emits bulletins as vanilla RadioLine instances.
   Player hears them as floating text when near an active receiver.

### Broadcaster voices (9 archetypes)

Each station class is voiced by a default archetype, but all 9 have
WBN opener/closer text pools:

| Archetype | Tone |
|-----------|------|
| Quartermaster | Official, measured, authoritative |
| Field Reporter | Urgent, ground-level, immediate |
| Scavenger | Scrappy, street-level, informal |
| Wholesaler | Business-first, matter-of-fact |
| Smuggler | Hushed, cryptic, allusive |
| Military | Clipped, procedural, terse |
| Trader | Pragmatic, deal-focused |
| Speculator | Analytical, forward-looking |
| Crafter | Practical, hands-on, grounded |

### Tips

- Keep a radio on while looting, driving, or working at base
- Bulletins vary in confidence — "said to be" is less reliable than a direct statement
- Repeated bulletins about the same topic increase confidence
- Your broadcast history is saved and can be reviewed at a POSnet terminal
- Price movements are expressed as rounded percentages (e.g. "up twelve percent")
- Cause framing may accompany movements (e.g. "following renewed shortages")

### Radio Forecasts

WBN broadcasts include forward-looking predictions alongside current reports:

- **Weather forecasts** (high confidence): PZ's engine pre-computes future
  weather, so WBN can accurately predict storms, heavy rain, blizzards,
  fog, and temperature extremes 1–3 days ahead.
- **Economic forecasts** (medium confidence): price drift extrapolation and
  convoy ETA intelligence provide approximate market predictions.
- **Power grid forecasts** (low confidence): speculative warnings when grid
  shutoff approaches, giving players time to prepare generator fuel.

Forecasts use confidence-scaled language: "expect" (high), "are likely to
see" (medium), "may see" (low). Horizon varies randomly from 1–3 days.

### Band Access

POSnet uses two distinct radio domains:

- **Data bands** (Operations Net, Tactical Net): structured terminal traffic.
  Required for POSnet terminal access.
- **Broadcast bands** (Market Bulletin, Emergency Service): public radio
  bulletins. Listen-only — no terminal access. Any radio can receive these.

Tuning a broadcast frequency while trying to connect a terminal will show
a message explaining that data channels are required for terminal operations.

---

### Signal Ecology

POSnet's signal quality is determined by a five-pillar environmental model:

- **Propagation** — weather and season affect signal transmission. Rain,
  storms, and fog degrade propagation; clear skies improve it.
- **Infrastructure** — grid power supports stronger signals. Blackouts and
  generator-only power reduce infrastructure quality.
- **Clarity** — higher SIGINT skill levels improve signal clarity through
  better equipment operation and analysis capability.
- **Saturation** — active free agents and volatile market conditions increase
  network saturation, crowding the signal space.
- **Intent** — (future) Tier V bandwidth allocation and relay prioritisation.

Signal quality is expressed as six qualitative states: **Locked** (excellent),
**Clear** (good), **Faded** (moderate), **Fragmented** (poor), **Ghosted**
(very poor), and **Lost** (no signal). These states affect WBN broadcast
clarity, mission rewards, and connection reliability.

---

### Signal Fragment Review

The POSnet terminal includes a dedicated Signal Fragments screen
(`BULLETIN BOARD > Signal Fragments`) for reviewing intelligence
gathered passively from WBN radio broadcasts.

- **Filter tabs**: All Fragments, Market, Weather, Infrastructure
- **Per-fragment display**: type badge, received day, confidence/freshness percentages, zone, category, direction
- **Detail panel**: full fragment metadata including estimated change, station source, and verification status
- **Summary counts**: type breakdown when no fragment is selected

Fragments are generated automatically when the player's radio receives
WBN broadcasts. Confidence is capped at 60% (radio intelligence is
never definitive) and decays over time. Repeated broadcasts on the
same topic reinforce confidence; contradictory broadcasts reduce it.
