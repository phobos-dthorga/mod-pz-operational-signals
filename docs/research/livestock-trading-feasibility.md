# Research: Livestock Trading System — B42 PZ Feasibility Study

**Branch**: `research/livestock-trading`
**Date**: 2026-03-19
**Status**: Research complete, implementation feasible

## Executive Summary

Project Zomboid Build 42 provides a **fully capable animal API** that supports
programmatic spawning, despawning, location control, and property management
— all **without requiring debug mode**. A livestock trading system integrated
with POSnet's market infrastructure is technically feasible and would be
unique in the PZ modding ecosystem.

---

## 1. Can Mods Spawn Animals Programmatically?

**YES** — via the `IsoAnimal.new()` constructor.

```lua
local animal = IsoAnimal.new(
    getCell(),       -- IsoCell (world cell reference)
    x, y, z,         -- float coordinates
    animalType,      -- String: "Cow", "Chicken", "Sheep", "Pig", "Duck", "Rabbit"
    breedName        -- String: "Holstein", "Angus", etc.
)
```

Confirmed in vanilla code (`ButcheringUtil.lua`, `STrapGlobalObject.lua`).
The constructor is **not** gated behind `isDebug()`.

After creation, call `animal:addToWorld()` to make it visible.

---

## 2. Can Mods Control Spawn Location?

**YES — full coordinate control.**

| Capability | Method | Notes |
|-----------|--------|-------|
| Exact position | `IsoAnimal.new(cell, x, y, z, type, breed)` | Float precision |
| Grid square | Use `sq:getX()`, `sq:getY()`, `sq:getZ()` | Convert square → coords |
| Navigability check | `animal:canGoThere(sq)` | Verify square is walkable |
| Zone assignment | `zone:addAnimal(animal)` | Auto-assigns to pen/pasture |

**Area spawning strategy**: Pick a random walkable square within a radius,
verify with `canGoThere()`, spawn there. This gives the "delivery truck
dropped them off nearby" feel without pixel-perfect placement.

---

## 3. Can Mods Despawn/Remove Animals?

**YES — multiple methods available.**

| Method | Effect |
|--------|--------|
| `animal:removeFromWorld()` | Remove from world (clean despawn) |
| `zone:removeAnimal(animal)` | Remove from designated zone |
| `hutch:removeAnimal(animal)` | Remove from hutch |
| `hutch:killAnimal(animal)` | Kill and convert to butcherable corpse |
| `animal:becomeCorpse()` | Convert live animal to `IsoDeadBody` |

For a **sale** (player sells livestock), `removeFromWorld()` is the cleanest
approach — the animal simply disappears as if "collected by the buyer."

---

## 4. Animal Properties (Extensive)

Animals have a rich property system via `animal:getData()` → `AnimalData`:

### Core Properties
- **Type**: Cow, Chicken, Sheep, Pig, Duck, Rabbit, Deer, Boar
- **Breed**: Multiple per type (Holstein, Angus, etc.)
- **Gender**: `isFemale()` — affects pricing, breeding potential
- **Age**: Baby → Adult → Geriatric lifecycle
- **Health**: `setHealth(float)` — affects condition/value
- **Size**: `getAnimalSize()` — growth from birth to maturity

### Genetics (15+ genes)
maxSize, maxMilk, meatRatio, ageToGrow, maxWool, maxWeight, lifeExpectancy,
resistance, strength, fertility, aggressiveness, thirstResistance,
hungerResistance, milkInc, woolInc, eggSize, stress, eggClutch

### Genetic Disorders (20 possible)
gluttonous, highThirst, fidget, bully, poorFertility, sterile, weak,
dwarf, skinny, bony, dieAtBirth, poorLife, noEggs, smallEggs, noWool,
poorWool, noMilk, poorMilk, growSlow, slowWalking, craven

**Implication**: Animal quality can be assessed from genetics, creating a
natural market value hierarchy. A Holstein cow with high milkInc genes
is worth more than one with poorMilk disorder.

---

## 5. Zone/Pen System

### DesignationZoneAnimal (Primary Container)

| Method | Purpose |
|--------|---------|
| `addAnimal(animal)` | Register animal in zone |
| `removeAnimal(animal)` | Deregister |
| `getAnimals()` | List all zone animals |
| `getAnimalsConnected()` | Recursive across connected zones |
| `getTroughs()` | Find feeding troughs |
| `getHutchs()` | Find hutches |
| `addFoodOnGround(item)` | Feed zone |

### Hutch System (IsoHutch)

| Method | Purpose |
|--------|---------|
| `addAnimalInside(animal, sync)` | Place in hutch (shelter) |
| `addAnimalOutside(animal)` | Release from hutch |
| `addAnimalInNestBox(animal)` | Nesting (egg-laying) |
| `addEgg(animal)` | Generate eggs |
| `toggleDoor()` | Open/close hutch |

**Implication**: Purchased livestock could be delivered directly into a
player's existing zone or hutch if they have one set up. Otherwise,
spawn nearby on walkable ground.

---

## 6. Debug Mode Restrictions

### NOT Debug-Gated (Available to Mods)
- `IsoAnimal.new()` — spawning
- `addToWorld()` / `removeFromWorld()` — world management
- `zone:addAnimal()` / `zone:removeAnimal()` — zone assignment
- `hutch:addAnimalInside()` / `hutch:killAnimal()` — hutch operations
- `getData()` — property access
- `becomeCorpse()` — conversion to butcherable body

### Debug-Only (Restricted)
- `ISAnimalBehaviorDebugUI` — behavior state visualization
- `AnimalContextMenu.cheat` flag — gender swap, instant aging, food cheats
- `setAgeDebug(newAge)` — age manipulation

**Conclusion**: The core spawning/despawning/management API works
entirely in normal gameplay. No debug mode workarounds needed.

---

## 7. Available Animal Types

### Livestock (Tradeable)
| Type | Breeds | Products |
|------|--------|----------|
| Cow | Holstein, Angus, + more | Milk, Meat, Leather |
| Sheep | Multiple | Wool, Meat |
| Pig | Multiple | Meat |
| Chicken | Multiple | Eggs, Meat, Feathers |
| Duck | Multiple | Eggs, Meat, Feathers |
| Rabbit | Multiple | Meat, Fur |

### Wild (Trappable/Huntable, NOT Tradeable)
| Type | Notes |
|------|-------|
| Deer (Buck/Doe/Fawn) | Wild only |
| Boar | Wild only |
| Raccoon | Wild, trappable |
| Mouse | Pest, not tradeable |

---

## 8. No Native Trading System Exists

PZ B42 has **no built-in animal trading mechanics**:
- No `AnimalTrade` class
- No merchant/vendor systems for animals
- No purchase/sale methods on the animal API

This is entirely custom territory — and an opportunity for POSnet to be
the first mod to offer a proper livestock market.

---

## 9. Proposed Implementation Architecture

### Integration with POSnet Market System

Livestock would become a new **commodity super-category** in the existing
market intelligence engine, with sub-categories per animal type.

```
POSnet Market Categories (existing)
├── fuel, medicine, food, ammunition, tools, radio, survival, weapons, ...
└── livestock (NEW)
    ├── cattle (Cow, Bull, Calf)
    ├── poultry (Chicken, Duck)
    ├── swine (Pig, Piglet)
    ├── sheep (Sheep, Lamb)
    └── rabbits (Rabbit)
```

### Purchase Flow

1. Player opens POSnet terminal → Markets → Livestock
2. Browse available animals (type, breed, gender, age, genetics summary)
3. Price based on: breed quality, age, gender, genetic disorders, market drift
4. Player confirms purchase (money deducted from inventory)
5. Animal spawns at a **delivery point** near the player:
   - If player has a DesignationZoneAnimal: spawn inside zone
   - Otherwise: spawn on nearest walkable square within ~5 tiles
6. Animal is added to world via `IsoAnimal.new()` + `addToWorld()`
7. If zone exists: `zone:addAnimal(animal)` for auto-registration

### Sale Flow

1. Player right-clicks animal in their zone → "Sell via POSnet"
2. Price calculated from: animal properties, genetics, market conditions
3. Player confirms (animal removed via `removeFromWorld()`)
4. Money added to player inventory

### Pricing Factors

| Factor | Effect on Price |
|--------|----------------|
| Breed quality (genetics) | High milk/wool/meat genes = premium |
| Genetic disorders | poorMilk, sterile, etc. = heavy discount |
| Age (baby vs adult vs geriatric) | Adults most valuable, geriatric discounted |
| Gender (female for breeding/milk) | Females generally premium |
| Health | Low health = discount |
| Market conditions (POSnet drift) | Supply/demand affects base price |
| Reputation tier | Better prices at higher reputation |

### Sandbox Options

| Option | Default | Range |
|--------|---------|-------|
| `EnableLivestockTrading` | false | boolean |
| `LivestockDeliveryRadius` | 5 | 3-15 tiles |
| `LivestockBasePrice` | 500 | 100-5000 |
| `LivestockGeneticPremium` | 150 | 100-300 (%) |
| `LivestockDisorderDiscount` | 50 | 0-100 (%) |

---

## 10. Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| `IsoAnimal.new()` signature changes in future PZ updates | Medium | Wrap in pcall, version-gate |
| Animal spawning in inaccessible locations | Low | `canGoThere()` check before spawn |
| Performance impact from many spawned animals | Low | Cap concurrent purchases |
| Multiplayer desync on animal spawn | Medium | Server-authoritative spawn only |
| API is technically undocumented (not in JavaDocs) | Medium | Derived from vanilla usage, well-established |

---

## 11. Conclusion

**Livestock trading is fully feasible in B42 PZ modding** without debug mode.
The animal API is comprehensive (spawning, despawning, genetics, zones, hutches)
and unrestricted for normal gameplay. POSnet's existing market infrastructure
(categories, pricing engine, reputation, sandbox options) provides a natural
integration point.

**Recommended priority**: MEDIUM — implement after the core market exchange
screens are functional, as livestock would be a premium feature that builds
on the established trading framework.
