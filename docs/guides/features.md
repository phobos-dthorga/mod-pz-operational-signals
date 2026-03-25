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

POSnet includes a live radio bulletin system. Tune any in-game radio to
one of the following frequencies to hear market and emergency updates:

- **91.4 MHz** — POSnet Market Bulletin (economy updates, price movements)
- **103.8 MHz** — POSnet Emergency Service (infrastructure alerts, grid warnings)

Frequencies are dynamically assigned per-world via the **AZAS Frequency
Index**. The defaults above are used when AZAS is unavailable.

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
