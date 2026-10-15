# Second Back Slot

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

## Sandbox options

| Option | Values | Default |
|---|---|---|
| Required Strength Level | 0-10 | 0 |

The Strength level a character needs for Back 2; 0 means every character has it from the start. Strength is the skill that sets how much a character can carry. Only the level in the Skills panel counts (`getPerkLevel`, which both read): moodles like hunger, starving or nicotine withdrawal do not change it. In B42.21 that level only goes down through the XP decay below or debug and admin tools, since `XP.AddXP` takes a level away only when XP drops under the level's threshold, and the decay is the only thing that removes Strength or Fitness XP. The slot shows up when the level is reached and goes away if Strength drops below it: its item then comes off the back and stays in the inventory, and the slot comes back once Strength is trained back up. That is rare: the game only takes Strength XP from a character who has not trained it for about 7 in-game weeks, 1 XP every 20 in-game hours (`XpUpdate.everyTenMinutes`, B42.21). This is checked when the hotbar is made and in its `update()`, which runs every frame, so the slot follows right away. During a timed action, which may be about to use a slot index, it waits until the action is done.

## How it works

### Locations

A character holds one item per attached location ("Rifle On Back", "Blade On Back", ...), and the vanilla back slot uses them all, so the second slot needs its own: an item put on a vanilla location would knock the first one off the model. Every vanilla back location, and every "with Bag" one, gets a twin named `ATWOB <location>` (`ATWOB_Shared.lua`). They are made in `shared/` because the server checks locations too: in B42 the client sends attached items to the server (`GameCharacterAttachedItemPacket`), which fails with "no such location" on one it does not know.

Each twin points at a new model attachment, made at boot from the vanilla one mirrored across the spine, on every model that has the vanilla back attachments: the vanilla bodies (`Base.FemaleBody`, `Base.MaleBody`), and the models body mods draw characters with instead (`HumanVisual:setForceModelScript`; any body mod has to carry the vanilla back attachments for the vanilla back slot to work). A model without them would draw a Back 2 item at its root, between the legs. The model a player is drawn with is also checked in the hotbar's `update()`, in case a body mod picks it, or scripts are loaded again, after boot; a line in `console.txt` says when a model other than the vanilla bodies got them. Only clients make them: a server does not draw models. Left and right attachments on the body differ by the sign of Y (`belt_left`/`belt_right` on the pelvis, `webbing_left`/`webbing_right` on the spine, `backpack_left` on the back bone), so the mirror flips the Y offset.

A model cannot be mirrored, only turned, so the item is also turned over across one of its own directions. On the back bone X points out of the back, Y to the side and Z up; the game rotates about X, then Y, then Z (`rotateXYZ` in `ModelInstanceRenderData.makeAttachmentTransform`). The direction picked runs across the item's length (the model's own Y, which is along the item) and lies in the back, worked out from each attachment's rotation. Then every part of the item stays exactly as far out of the back as on the first back slot, and its length is mirrored; the item is only flipped across its own length line, which looks the same for most items.

| | offset | rotate |
|---|---|---|
| `rifle_back` (vanilla) | 0.008 -0.102 0.061 | -49 11 0 |
| `atwob_rifle_back` | 0.008 0.102 0.061 | -131 11 0 |

Two earlier attempts and what they did in game:

- Flipping the rotations about X and Z (`-x, y, -z`) also flips the item's length: with a bag on, a crowbar on Back 2 stood up over the head instead of hanging down beside the bag.
- Turning the item over across its own X (`-x, y, 180 - z`, which is also how the game's right and left belt attachments relate) turns it over across the direction out of the back. A crowbar or a shotgun is thin that way, so it looked right, but whatever stands out from the back went into the body: a frying pan came out of the chest.

An item's own model can also have an attachment with the same name: the game looks for the location's attachment name on the body and on the item (`AttachedModelNames.initFrom`), and draws the item at bone × body attachment × inverse of item attachment × mesh (`transformToParent`). In vanilla only `FryingPanForged` has them (`fryingpan_back` turns its hand mesh 90° about Y), weapon mods can have more. Those get a Back 2 copy, unchanged and with no bone; without it, such an item on Back 2 would be drawn without its own placement. The body attachment already keeps every part of the item as far out of the back, whatever the item's own attachment does.

In vanilla a crowbar (`blade_back`, -61 0 0) and a shotgun (`rifle_back`, -49 11 0) sit at almost the same angle, so mirroring is what keeps them apart. The values are read from the game's attachments when the game starts, so they follow any changes to the vanilla ones. If a model attachment cannot be made, the twin location falls back to the vanilla attachment: the slot still works, and the two items overlap.

### Hotbar

`ISHotbar` is wrapped, not copied (`ATWOB_Hotbar.lua`), so other hotbar mods keep working:

- **`haveThisSlot`**: `refresh()` drops every slot that is not the back slot or one a worn item provides. It checks that through `haveThisSlot(type, list)`, the only call with a list, so the wrapper keeps "Back 2" there, like the back slot.
- **`loadPosition`**: adds "Back 2" after "Back" on a new character, and to saves made without the mod, or takes it away when the character is below the required Strength. Items save both their slot index and their slot type, so the indices of the slots that moved are matched to their type again (and synced in MP). The same happens when the slot comes or goes while playing.
- **`attachItem` / `canBeAttached`**: vanilla moves back items beside a worn bag only for slots named "Back" (the bag's `AttachmentReplacement`). "Back 2" is not named "Back", or vanilla would use the same bag locations as the first slot. The wrapper does the same move with the mirrored "with Bag" locations, and refuses items that cannot be on the back with a bag (guitars).

- **`refresh`** (wrapped at boot, after every other mod): an item saves both its slot number and its slot type, and vanilla's update drops any item whose slot number points at a slot that cannot hold it. Other hotbar mods can mix the numbers up, so after every refresh, items whose number does not match their slot type are matched to their slots by type again.

The slot's item types are copied from the vanilla back slot at boot, so items other mods add to it work on "Back 2" too, as long as they use a vanilla back location.

### Compatibility

- **Reorder The Hotbar** (workshop 2903771337) replaces `refresh`. Before a full refresh (whenever worn items change, and when loading) it moves every slot except "Back" and the worn items' slots to the end, since those are about to be removed. Back 2 stays, so its `reorderTheHotbar` then sorts the slots back into the player's order, but matches the items to them by their old numbers. With a belt on, the Back 2 item and the belt items then pointed at the wrong slots and came off the hotbar. The `refresh` wrapper above puts them back, and `tests/test_compat.lua` runs that mod's own code when it is installed.
- **Equipment UI** wraps `refresh` and calls the original, so it works as is.

## Layout

```
Contents/mods/PZAttachTwoWeaponsOnBack/
  42/mod.info
  common/media/lua/
    shared/AttachTwoWeaponsOnBack/ATWOB_Shared.lua   locations and model attachments
    client/AttachTwoWeaponsOnBack/ATWOB_Hotbar.lua   the "Back 2" hotbar slot
    shared/Translate/EN/IG_UI.json
    shared/Translate/EN/Sandbox.json
  common/media/sandbox-options.txt
tests/                                               Kahlua test runner and tests
```

## Tests

```
tests/run_tests.sh
```

The tests run on Kahlua from the game's jar and load the vanilla hotbar code (`ISHotbar`, the attach and detach actions, the slot and location definitions) and the body models from the game folder, so they check the mod against the game's own code. `test_compat.lua` also loads other hotbar mods from the Steam Workshop folder next to the game, and skips them when they are not installed. Set `PZ_DIR` if the game is not in `D:/Games/Steam/steamapps/common/ProjectZomboid`.
