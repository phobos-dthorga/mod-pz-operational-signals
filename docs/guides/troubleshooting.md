# POSnet Troubleshooting

Solutions for common issues with the Phobos Operational Signals Network.

---

## Terminal Won't Open

**Symptom:** Right-clicking the radio does not show "Connect to POSnet
Terminal" in the context menu.

**Causes and fixes:**

1. **No computer in range.** A desktop computer must be within 3 tiles of
   the radio, OR you need a portable computer (laptop) in your inventory.
   Move your radio closer to a computer, or pick up a laptop.

2. **Computer has no power.** Desktop computers need wall power or a
   connected generator. Portable computers need battery charge. Verify
   power is reaching the computer.

3. **Radio is off or unpowered.** The radio must be turned on. If it is a
   stationary radio, it also needs a power source.

4. **Wrong frequency band.** The radio must be tuned to an AZAS frequency.
   Check that the AZAS Frequency Index mod is installed and active, then
   tune your radio to one of the assigned amateur or tactical bands.

5. **Missing dependencies.** Confirm that both PhobosLib and AZAS Frequency
   Index are installed, enabled, and loaded in the correct order in your
   mod list.

---

## No Data Appearing

**Symptom:** The terminal opens but market screens show empty categories,
no prices, or "No data available."

**Causes and fixes:**

1. **Not enough time elapsed.** Ambient intel takes approximately 30
   game-minutes to start arriving. Leave the radio on and wait.

2. **Radio not tuned to AZAS frequency.** Ambient intel only collects when
   the radio is on a valid AZAS band. Check your radio frequency.

3. **Sandbox settings disabled.** Open Sandbox Settings and check the
   POSnet section. Ensure market data options are not turned off.

4. **Signal strength too low.** The radio's transmit range affects signal
   quality. A radio with very low range may receive limited or no data
   from distant sources. Try a higher-powered radio or move to a
   location with better coverage.

---

## Prices Seem Wrong

**Symptom:** Commodity prices appear unusually high, low, or inconsistent.

**Explanation:** POSnet prices reflect **data confidence** -- the accuracy
depends on how many sources contribute to a price estimate and how recently
data was collected.

**What to check:**

1. **Confidence indicators.** The Market Overview shows data confidence per
   category. Low confidence means the price is based on limited or stale
   information.

2. **Number of sources.** More sources (ambient + active + camera + satellite)
   yield more accurate prices. Use a Data Recorder for active scanning to
   improve confidence.

3. **Zone differences.** Prices vary by zone. A price that seems "wrong"
   globally may be accurate for the specific zone it represents.

4. **Living Market events.** If the Living Market is enabled, dynamic events
   (shortages, surpluses) can cause sudden price swings. Check the Market
   Signals screen for recent events.

---

## Save File Issues

**Symptom:** Corrupted data, missing progress, or unexpected terminal
behaviour after loading a save.

**Steps:**

1. **Check mod load order.** PhobosLib must load before POSnet. AZAS
   Frequency Index must also load before POSnet. Incorrect order can cause
   data initialisation failures.

2. **Verify mod versions.** POSnet requires PhobosLib v1.49.0 or later.
   Outdated dependencies can cause save compatibility issues.

3. **Use the Data Reset tool.** If terminal data is corrupted, POSnet
   provides a data reset option accessible through the terminal Settings
   screen. This clears cached market data and forces a fresh collection
   cycle. Your SIGINT skill, reputation, and mission history are preserved.

4. **Check the PZ console log.** Open the Project Zomboid console
   (debug mode) and look for lines prefixed with `[POSnet]` or
   `[PhobosLib]` for specific error messages.

---

## Screen Shows "Locked" or "Requires..."

**Symptom:** A terminal screen appears greyed out with a lock message.

**Explanation:** POSnet uses a "visible but locked" design. Screens you
cannot access yet are shown with the reason they are locked:

- **"Requires SIGINT Level X"** -- raise your SIGINT skill to the indicated
  level through intelligence-gathering activities.
- **"Requires Data Recorder"** -- craft or find a Data Recorder item and
  have it in your inventory.
- **"Requires Camera Workstation"** -- set up a Camera Workstation near
  your terminal.
- **"Requires Satellite Uplink"** -- the most advanced equipment gate.

This is intentional. It lets you see what features exist and what you need
to work towards unlocking them.
