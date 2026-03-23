# POSnet FAQ

Answers to common questions about the Phobos Operational Signals Network.

---

### Why can't I connect to the terminal?

The "Connect to POSnet Terminal" option only appears when all conditions are
met:

- You are right-clicking a **radio** (not a computer).
- A **powered computer** is within **3 tiles** of the radio, OR you have a
  **portable computer** (laptop) with battery charge in your inventory.
- The radio is **powered on** and tuned to an AZAS frequency band.
- Both the radio and computer have power (generator, battery, or wall power).

If any of these are missing, the context menu option will not show up.

---

### How do I get market data?

Market data arrives through two channels:

1. **Ambient intel (passive)** -- as long as a radio is powered and tuned to
   an AZAS frequency, the terminal passively collects market chatter. This
   takes approximately **30 game-minutes** to start showing results. You do
   not need the terminal open for this; the radio just needs to be on.

2. **Active scanning** -- equip a **Data Recorder** and use it near a radio
   for targeted intelligence gathering. This produces higher-quality data
   and more SIGINT XP than passive collection.

Higher-tier methods (camera workstations, satellite uplinks) provide the
most detailed and accurate intelligence.

---

### What does the SIGINT skill do?

SIGINT (Signal Intelligence) is a custom perk with 10 levels that affects
nearly everything in POSnet:

- **Gates terminal screens** -- some screens require a minimum SIGINT level
  to access (e.g., Known Contacts requires Level 3).
- **Boosts rewards** -- higher SIGINT levels increase payouts from
  operations and improve trade prices.
- **Improves data quality** -- more accurate price data and confidence
  levels.
- **Negotiation success** -- better odds when haggling mission terms.

You gain SIGINT XP from all intelligence activities: passive recon, active
scanning, camera processing, and satellite broadcasts.

---

### My terminal shows no items / no market data

This is normal when you first start. The system needs time to collect
ambient intelligence:

- Ensure your radio is **powered on** and tuned to an **AZAS frequency**.
- Wait approximately **30 game-minutes** of in-game time.
- Check the **Market Overview** screen -- categories will populate as data
  arrives.

If data still does not appear after waiting, check your Sandbox Settings to
ensure POSnet options have not been disabled.

---

### How do I trade with contacts?

Trading requires **SIGINT Level 3** or higher:

1. Open the terminal and navigate to **Markets > Known Contacts**.
2. Browse available traders and their inventories.
3. Select a trader and choose items to buy or sell.
4. Confirm the transaction.

Traders operate in specific zones, so prices and availability vary by
location. Better intelligence (more sources, higher confidence) gives you
access to better deals.

---

### What are zones?

Zones are **geographic regions** of the game world, each with independent
economic characteristics:

- Different **supply levels** per commodity category.
- Different **price modifiers** based on local supply and demand.
- Different **trader populations** operating in each area.

Zone pressure indicates how tight supply is in a region. High-pressure zones
have scarcer goods and higher prices. Low-pressure zones have surplus stock
and better deals. Use the Market Overview to compare zone conditions.

---

### Can I play without the Living Market?

Yes. The Living Market is an **optional sandbox setting** that is **off by
default**. Without it, the economy still functions through ambient intel,
static pricing models, and player-driven operations. The Living Market adds
autonomous agent behaviour and dynamic supply/demand simulation for players
who want a more complex economy.

---

### What mods does POSnet require?

POSnet requires:

- **PhobosLib** (v1.49.0 or later) -- shared utility library.
- **AZAS Frequency Index** -- provides the dual-band radio frequency system.

Optional cross-mod support exists for PhobosChemistryPathways,
PhobosIndustrialPathology, and PhobosNotifications.
