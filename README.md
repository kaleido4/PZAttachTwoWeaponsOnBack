# Attach Two Weapons On Back

Project Zomboid (Build 42) mod that adds a second back slot to the hotbar, so you can carry two weapons on your back, like a shotgun and a crowbar, each on its own hotbar key.

```
[1 Back: Crowbar] [2 Back 2: Shotgun] [3 Belt Left] [4 Belt Right] ...
```

- "Back 2" sits right after "Back" (key 2). Belts, holsters and other slots move up one.
- It takes every item the vanilla back slot takes: rifles and shotguns, axes, bats, crowbars, swords, shovels, rackets, pans, guitars.
- The second item is mirrored across the back, so the two cross instead of clipping into each other.
- With a backpack on, both go beside the bag, one on each side. Guitars come off, like in vanilla.
- Can be added to existing saves: the slots after Back move up one and keep their items.
- Before removing the mod, take the item off Back 2.

## How it works

### Locations

A character holds one item per attached location ("Rifle On Back", "Blade On Back", ...), and the vanilla back slot uses them all, so the second slot needs its own: an item put on a vanilla location would knock the first one off the model. Every vanilla back location, and every "with Bag" one, gets a twin named `ATWOB <location>` (`ATWOB_Shared.lua`). They are made in `shared/` because the server checks locations too: in B42 the client sends attached items to the server (`GameCharacterAttachedItemPacket`), which fails with "no such location" on one it does not know.

Each twin points at a new model attachment on the body models (`Base.FemaleBody`, `Base.MaleBody`), made at boot from the vanilla one mirrored across the spine. Left and right attachments on the body differ by the sign of Y (`belt_left`/`belt_right` on the pelvis, `webbing_left`/`webbing_right` on the spine, `backpack_left` on the back bone), so the mirror flips the Y offset and the rotations about X and Z:

| | offset | rotate |
|---|---|---|
| `rifle_back` (vanilla) | 0.008 -0.102 0.061 | -49 11 0 |
| `atwob_rifle_back` | 0.008 0.102 0.061 | 49 11 0 |

In vanilla a crowbar (`blade_back`, -61 0 0) and a shotgun (`rifle_back`, -49 11 0) sit at almost the same angle, so mirroring is what keeps them apart. The values are read from the game's attachments when the game starts, so they follow any changes to the vanilla ones. If a model attachment cannot be made, the twin location falls back to the vanilla attachment: the slot still works, and the two items overlap.

### Hotbar

`ISHotbar` is wrapped, not copied (`ATWOB_Hotbar.lua`), so other hotbar mods keep working:

- **`haveThisSlot`**: `refresh()` drops every slot that is not the back slot or one a worn item provides. It checks that through `haveThisSlot(type, list)`, the only call with a list, so the wrapper keeps "Back 2" there, like the back slot.
- **`loadPosition`**: adds "Back 2" after "Back" on a new character, and to saves made without the mod. Items save both their slot index and their slot type, so the indices of the slots that moved are matched to their type again (and synced in MP).
- **`attachItem` / `canBeAttached`**: vanilla moves back items beside a worn bag only for slots named "Back" (the bag's `AttachmentReplacement`). "Back 2" is not named "Back", or vanilla would use the same bag locations as the first slot. The wrapper does the same move with the mirrored "with Bag" locations, and refuses items that cannot be on the back with a bag (guitars).

The slot's item types are copied from the vanilla back slot at boot, so items other mods add to it work on "Back 2" too, as long as they use a vanilla back location.

## Layout

```
Contents/mods/PZAttachTwoWeaponsOnBack/
  42/mod.info
  common/media/lua/
    shared/AttachTwoWeaponsOnBack/ATWOB_Shared.lua   locations and model attachments
    client/AttachTwoWeaponsOnBack/ATWOB_Hotbar.lua   the "Back 2" hotbar slot
    shared/Translate/EN/IG_UI.json
tests/                                               Kahlua test runner and tests
```

## Tests

```
tests/run_tests.sh
```

The tests run on Kahlua from the game's jar and load the vanilla hotbar code (`ISHotbar`, the attach and detach actions, the slot and location definitions) and the body models from the game folder, so they check the mod against the game's own code. Set `PZ_DIR` if the game is not in `D:/Games/Steam/steamapps/common/ProjectZomboid`.
