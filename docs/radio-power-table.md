# POSnet Radio Power & Signal Strength Reference

## Signal Strength Formula

POSnet uses the **inverse square law** to calculate signal strength from
radio hardware:

```
signalStrength = clamp(0, 1, (radioPower / referencePower)^2)
```

Where:
- `radioPower` = PZ vanilla TransmitRange value of the connected radio
- `referencePower` = sandbox configurable (default: 10,000)

## Radio Power Table

| Radio | Full Type | TransmitRange | Real-World Equiv. | Signal % (ref=10000) |
|---|---|---|---|---|
| WalkieTalkie 1 | Base.WalkieTalkie1 | 750 | ~0.5W toy-grade | 0.6% |
| WalkieTalkie (makeshift) | Base.WalkieTalkieMakeShift | 1,000 | ~1W homebrew | 1.0% |
| WalkieTalkie 2 | Base.WalkieTalkie2 | 2,000 | ~2W civilian | 4.0% |
| WalkieTalkie 3 | Base.WalkieTalkie3 | 4,000 | ~5W mid-range | 16.0% |
| Ham Radio (makeshift) | Base.HamRadioMakeShift | 6,000 | ~5W homebrew base | 36.0% |
| Ham Radio 1 | Base.HamRadio1 | 7,500 | ~10W civilian ham | 56.3% |
| WalkieTalkie 4 | Base.WalkieTalkie4 | 8,000 | ~8W tactical | 64.0% |
| WalkieTalkie 5 (military) | Base.WalkieTalkie5 | 16,000 | ~20W military | 100% |
| Ham Radio 2 (military) | Base.HamRadio2 | 20,000 | ~100W base station | 100% |
| Man-Pack Radio | Base.ManPackRadio | 20,000 | ~50W man-pack | 100% |

Commercial receivers (RadioBlack, RadioRed, RadioMakeShift, CDplayer)
have TransmitRange = 0 and cannot connect to POSnet.

## Signal Quality Thresholds

| Range | Quality | Reward Multiplier |
|---|---|---|
| 80-100% | EXCELLENT | 90-100% |
| 50-79% | GOOD | 75-89% |
| 25-49% | WEAK | 62-74% |
| 15-24% | CRITICAL | 57-62% |
| 0-14% | Cannot connect | N/A (below MinSignalThreshold) |

## Reward Scaling

```
rewardMultiplier = 0.5 + 0.5 * signalStrength
```

At 100% signal: full rewards (1.0x multiplier).
At 50% signal: 75% rewards (0.75x multiplier).
At minimum threshold (15%): ~58% rewards (0.575x multiplier).

## Sandbox Options

| Option | Default | Description |
|---|---|---|
| EnableSignalStrength | true | Master toggle. When off, all radios work equally. |
| SignalReferencePower | 10,000 | TransmitRange for 100% signal. |
| MinSignalThreshold | 15% | Below this, connection refused. |

## AZAS Band Assignment

POSnet registers two stations with AZAS Frequency Index:
- **POSnet_Operations** (amateur band) — civilian content
- **POSnet_Tactical** (military band) — combat content

Frequencies are assigned dynamically per-world by AZAS.
