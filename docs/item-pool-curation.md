# Item Pool Curation

## Overview

POSnet's item pool scans all ~5,100 vanilla PZ items via `ScriptManager` at
init time. Without curation, untradeable junk leaks into the commodity pool:
blood-soaked bandages, zombie damage textures, corpses, furniture sprites,
debug items, and animal carcass parts. A two-layer exclusion filter removes
these before any item is indexed.

## Two-Layer Filter

### Layer 1 — DisplayCategory Blacklist

Items whose `DisplayCategory` appears in `POS_Constants.ITEM_POOL_EXCLUDED_CATEGORIES`
are skipped unconditionally. This is a hash-set for O(1) lookup.

| DisplayCategory | Count | Rationale |
|-----------------|------:|-----------|
| ZedDmg | 74 | Zombie damage clothing overlays |
| Wound | 60 | Blood-soaked bandage body states |
| Bandage | 34 | Blood-soaked bandage variants |
| Memento | 218 | Character-bound keepsakes |
| Corpse | 3 | Body part items |
| AnimalPart | 69 | Skulls, organs, sinew |
| MaleBody | 3 | Body cosmetics |
| Ears | 3 | Body cosmetics |
| Tail | 2 | Body cosmetics |
| Appearance | 36 | Cosmetic character presets |
| Hidden | 6 | Debug / hidden items |
| Bug | 6 | Debug / test items |
| Junk | 109 | Explicitly marked valueless |
| Furniture | 337 | World fixtures, not inventory |
| Container | 162 | Structural containers |
| Animal | 2 | Live animal entities |
| Generic | 1 | Uncategorised generic item |
| Animal corpses | ~15 | Raccoon, Fox, Duck, Bunny, Spider, Mole, Hedgehog, Goblin, Eye, Badger, Bear, Beaver, Dog, Frog, Squirrel |

**Total excluded by category:** ~1,140 items (~22%)

### Layer 2 — Name Pattern Blacklist

Items matching any pattern in `POS_Constants.ITEM_POOL_EXCLUDED_PATTERNS` are
skipped even if their DisplayCategory is otherwise mapped. Patterns use
plain-text matching (`string.find` with `plain=true`).

| Pattern | Catches |
|---------|---------|
| `_Blood` | Blood-soaked bandage variants (e.g. `Bandage_Abdomen_Blood`) |
| `ZedDmg_` | Zombie damage prefix (belt-and-suspenders with Layer 1) |
| `Wound_` | Wound state prefix |
| `Corpse` | Any corpse-related item |
| `_Broken` | Broken item variants |

## Commodity Category Mapping

Items that survive both filters are mapped from their PZ `DisplayCategory` to
a POSnet commodity category via `DISPLAY_CATEGORY_MAP` in `POS_ItemPool.lua`:

| DisplayCategory | Commodity |
|-----------------|-----------|
| FirstAid | medicine |
| Food, Cooking, CookingWeapon | food |
| Ammo, Explosives, WeaponPart | ammunition |
| Tool, ToolWeapon, Material, RecipeResource, VehicleMaintenance, Gardening, Household, Paint, Security | tools |
| Electronics, Communications, LightSource | radio |
| Camping, Fishing, Trapping, WaterContainer, Bag, FireSource, Water | survival |
| Weapon, WeaponCrafted | weapons |
| Clothing, ProtectiveGear | clothing |
| Literature, SkillBook, Cartography | literature |
| *(fuel detected by name pattern, not DisplayCategory)* | fuel |
| *(unmapped categories)* | miscellaneous |

## Extending the Filter

### Adding a new exclusion category

Add the DisplayCategory string to `POS_Constants.ITEM_POOL_EXCLUDED_CATEGORIES`
in `POS_Constants_Market.lua`:

```lua
["NewCategory"] = true,   -- reason for exclusion
```

### Adding a name pattern exclusion

Append to `POS_Constants.ITEM_POOL_EXCLUDED_PATTERNS`:

```lua
"_Suffix",   -- what this catches
```

### Cross-mod items

Items registered via `POS_ItemPool.registerItem()` bypass curation entirely.
They are always included regardless of DisplayCategory or name.

## Expected Pool Size

After curation: ~3,950 items indexed from ~5,100 total (~77% inclusion rate).
The exact count varies by PZ version as TIS adds/removes items.
