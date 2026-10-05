# Morghasts & Dread Abyssals for Vampire Counts

A Total War: Warhammer III mod that unlocks the Nagash DLC Morghasts and the
Dread Abyssal mounts for the Vampire Counts race, instead of keeping them
exclusive to the Nagash (Undead Legions) campaign.

**What it does:**

* **Morghast Harbingers** and **Morghast Archai**
  (`wh3_dlc29_vmp_mon_morghast_*`) become recruitable by every Vampire
  Counts faction
* Recruitment from the **Haunted Wood** building chain (where Vargheists and
  Terrorgheists live): Harbingers from tier 4, Archai from tier 5
* Building-based unit caps, Tomb Kings style:
  * Haunted Wood T4: 1 Harbinger
  * Haunted Wood T5: 2 Harbingers + 1 Archai
  * Tech *Legacy of the Tombs* (ghosts branch): +1 Harbinger
  * Tech *Nightmare Spirits* (ghosts branch): +1 Archai
* Morghasts are added to the buff lists of the VC roster skills:
  * *Raising the Dead* (Black Knights / Blood Knights / Drakenhof Templars
    red-line skill)
  * the flying-monsters red-line skill (Fell Bats / Vargheists /
    Terrorgheists / Zombie Dragons, rank 7+)
  * the ghost tech branch unit buffs — barrier health and battle healing
    cap. Like the ghost units themselves, Morghasts have 0 base barrier:
    the researched techs grant it (+200/+200/+300, up to 700)
* **Ashigaroth, Devourer of the Craven** for Mannfred and the Dread Abyssal
  mount for Neferata: the mount skill nodes already exist in their skill
  trees but are gated to the Nagash campaign subculture — the gate is
  removed, so the mounts are available in every campaign (vanilla level
  requirement kept)

Hire costs, upkeep and unit stats are untouched. Works in Immortal Empires
and all campaigns; the Nagash campaign itself is unaffected (his own
buildings are granted a high cap so his ritual-capacity system keeps
working exactly as before).

Save-game compatible: add at any time. Removing mid-campaign is safe too —
already-recruited Morghasts just become over-cap.

## How it works

No Assembly Kit, no RPFM — the mod is generated from the game's own db by a
PowerShell toolchain (see [tools/](tools/)):

| Table | Rows | Purpose |
|---|---|---|
| `units_to_groupings_military_permissions` | 2 | allow the units for the `wh_main_group_vampire_counts` military group |
| `building_units_allowed` | 3 | recruitment from Haunted Wood 4/5 |
| `character_skill_nodes` | 2 (override) | clear the `wh3_dlc29_sc_nag_undead_legions` subculture gate on the two mount skill nodes |
| `unit_set_to_unit_junctions` | 5 | add Morghasts to the knight / flying-monster skill unit sets |
| `effects` | 2 | new unit-cap effects (cloned from the TK Morghast cap effects) |
| `effect_bonus_value_unit_record_junctions` | 6 | bind `unit_cap` to the units; extend barrier/healing tech buffs to them |
| `building_effects_junction` | 7 | caps from Haunted Wood (+ cap 30 from Nagash's own Necropolis buildings so his campaign is unchanged) |
| `technology_effects_junction` | 2 | +1/+1 caps from the ghost-branch technologies |
| `text/db/*.loc` | 2 | English tooltips for the cap effects |

The binary table layouts were reverse-engineered by brute-forcing token
grammars against the live db with exact-EOF validation
(`tools/build_vc_morghasts.ps1` writes every row byte-by-byte; skill-node
and effect rows are raw-cloned from vanilla with targeted field edits).

## Build from source

```bash
powershell -File tools/build_vc_morghasts.ps1
```

Requires the game installed (tables are read from `data/db.pack`) and any
`libzstd.dll` (the one shipped with Git for Windows works).

## Known quirks

* The cap-effect tooltip line ("Unit capacity: +N") is English-only — mod
  `.loc` files apply to all game languages.
* In the Nagash campaign Morghast recruitment may additionally show a
  "x/30" unit-cap badge next to the ritual capacity — cosmetic.

## Disclaimer

Not affiliated with Creative Assembly or Games Workshop. Single-player
convenience mod; unbalancing by design.

## See also

[Unlimited Mercenaries](https://github.com/okolovmark/unlimited-mercenaries) —
the sibling mod built with the same toolchain.
