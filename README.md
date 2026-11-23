# Brotherhood of Gold - Trade Helper

A WoW Forever addon for levelling professions and making gold from them. It shows:

- what each recipe costs to craft, using AH and vendor prices;
- what the crafted item sells for, and which recipes make a profit;
- every recipe of a profession, learned or not, and where to get it: trainer, vendor, drop (with drop chance), chest
  or quest. You get coordinates, distance and direction, and a map pin on the nearest one.

No other addon needed. Test build - thanks for trying it.

---

## Install

1. Download the latest zip from **[Releases](https://github.com/Noie331/brotherhood-of-gold-trade-helper/releases/latest)**.
   Under **Assets**, click `BrotherhoodOfGold_TradeHelper-vX.Y.Z.zip`. Don't use "Source code".
2. Unzip it into your AddOns folder:

   ```
   World of Warcraft\_forever_\Interface\AddOns\
   ```

   Check you end up with
   `...\AddOns\BrotherhoodOfGold_TradeHelper\BrotherhoodOfGold_TradeHelper.toc`.
   Not `...\AddOns\BrotherhoodOfGold_TradeHelper\BrotherhoodOfGold_TradeHelper\...`: if you see that, move the inner
   folder up one level.
3. Start the game, or type `/reload` if it's already running.
4. On the character screen, under **AddOns**, "Brotherhood of Gold - Trade Helper" should be ticked.

**Updating:** close the game (or `/reload` afterwards), delete the old `BrotherhoodOfGold_TradeHelper` folder, then
unzip the new one. Your settings and saved data are kept; they live in the `WTF` folder, not the addon folder.

The window title shows the version you have.

---

## Opening it

- **Gold coin tab:** open any profession. A gold coin tab sits on the right edge of the profession window. Click it to
  open the helper on that profession. You can drag the coin up or down the edge, and it remembers where you put it.
- **`/bog`:** opens or closes the helper anywhere.
- **Moving it:** drag the helper by its title bar. It remembers where you leave it.

**Open each profession once after installing.** That's how the addon learns your recipes. Until then the tab says
"Open <profession> once to load its recipes."

---

## Getting prices: Scan AH

At the auction house, click **Scan AH** in the helper.

- "Scanning... N%" counts up. The game doesn't freeze, and chat says **AH scan done** when it finishes.
- After a scan the button counts down from 15:00. That's a limit the game puts on full AH scans.
- "AH data: ..." shows how old your prices are. Prices are saved, so they're still there after you log out.
- If you close the AH mid-scan, your old prices are kept.

**Vendor prices** come from the game, and from any vendor you visit with the addon on (for example a thread or vial
vendor).

---

## The tabs

### Profession tabs (one per profession you've trained)

Every recipe you know, grouped by skill-up colour:

| Colour | Means |
|---|---|
| Orange | always a skill point |
| Yellow | likely a skill point |
| Green | sometimes a skill point |
| Grey (dimmed) | no skill points |

Under each recipe are its materials, each with an **AH** and a **V** (vendor) price; a tick marks the cheaper one.

The right side shows **AH +x | V -y**:

- the profit (green) or loss (red) from selling the crafted item on the AH, and to a vendor;
- "-" means there's no price for it;
- "<=" means a material has no price yet, so the real profit is at most that.

**Sort by:**

- **Cheapest** puts the cheapest skill-up in each colour first. Use it for levelling.
- **AH profit** or **Vendor profit** puts the most profitable first.

Your choice is remembered.

### Money Maker

Recipes from **all** your professions in one list, most profitable first.

- **Sort by AH profit / Vendor profit:** pick where you plan to sell.
- **One tick box per profession:** untick one to hide its recipes. This is remembered.

Losses show in red.

### Recipes

Every recipe of a profession, **learned or not**, lowest skill first. The header says how many you've learned
(e.g. "Learned 84 of 212").

- **Switching profession:** use the buttons under the tabs. A profession appears there after you've opened it once.
- **Not learned only:** tick this box, under the profession buttons, to hide the recipes you already know. It's
  handy for finding what's left to learn. It works with the search box, and stays ticked until you untick it.
- **Each row:** "Name (skill needed)". The second line says where to get the recipe:
  - **Trainer** (or "any of N trainers")
  - **Vendor**, with the price; "(limited)" means limited supply
  - **Drop**, with drop chance, highest first, or **world drop**
  - **Chest** or **Quest**
  - **Learned with the profession**
  - Newer WoW Forever recipes show a line from Warcraft Wiki instead.
- **Your faction:** you see your own faction's trainers and vendors. Ones that only the other faction has are marked
  "(Horde only)" or "(Alliance only)".

**Hover a recipe** to see the recipe tooltip and a **Where to get it** list. Each trainer, vendor and drop mob gets a
line like:

```
Vendor: Qia (Alliance)
Winterspring, Kalimdor  61.2, 37.4  -  1,240 yd NE
```

That's the zone, continent, map coordinates, and how far away it is and which direction from where you stand. "(walks a route - may be nearby)" means that NPC patrols. For vendors and trainers that walk a long way (like
Zixil), clicking the recipe also draws the route on the world map: a yellow line, with orange squares where they
stop and wait. Places
on another continent show no distance. Dungeon mobs show "Inside <dungeon>".

**Click a recipe** to list every location in chat and put a **map pin with an arrow** on the nearest one.

- The pin goes to your own faction's trainers and vendors, or to neutral ones and drop mobs.
- It skips the other faction's, even when they're closer.
- It only points at the other faction when they're the only source.
- Once you're in the right zone, the pin goes to a place you've visited there yourself.

**Search box** (top right of the Recipes tab). Type and the list narrows as you go; the header says how many match.
You can search by:

| Search by | Example |
|---|---|
| recipe or item name | `runecloth` |
| a material it uses | `wool cloth` |
| a stat or effect of what it makes | `stamina`, `well fed`, `fire resistance` |
| an enchant | `crusader` |
| where to get it | `Qia`, `drop`, `trainer` |

Every word must match, in any order: `well fed spirit` needs both "well fed" and "spirit". **Esc** or the **X**
clears it. Hover the search box for a reminder. Items the game hasn't loaded yet may show up a moment later.

### Quests

Profession quests, one button per profession you have, including Herbalism, Skinning, Mining and Fishing. You only
see your own faction's quests and neutral ones.

- **Each row:** "Quest name (level 20, skill 50)", with **Done**, **In quest log** or **Not done** on the right. The
  header says how many you've done (e.g. "Done 3 of 12"). Done quests are greyed.
- **Second line:** who starts it, or the object or item that starts it, and "After: ..." when another quest comes
  first.
- **Hover** to see what the quest asks for, and where its quest giver stands, with distance and direction.
- **Click** to list the quest giver in chat and put a map pin on them.

The quest list comes from classic 1.12 data, so a quest that WoW Forever changed or added may be missing or differ.

---

## Hovering and linking

- **Hover** a recipe or material on any tab to see its game tooltip.
- **Shift-click** a recipe or a material with the chat box open (press Enter first) to link it in chat.
  - This works for crafted items, materials and Recipes-tab recipes.
  - On the Recipes tab, a shift-click with the chat box closed still sets the map pin.

---

## Commands

| Command | Does |
|---|---|
| `/bog` | open / close the helper |
| `/bog export` | show your recipe data report, ready to copy (see below) |
| `/bog record off` | stop recording recipe data |
| `/bog record on` | start recording again (it's on by default) |
| `/bog probe` | print details about your game client, for bug reports |

---

## Help fill in where recipes come from

The recipe data comes from classic 1.12 data, so some WoW Forever vendors, drops and recipes are missing. You can
help fill the gaps.

While you play, the addon quietly notes recipe vendors, recipe drops and trainers it doesn't know yet. It also notices when a vendor or trainer it does know is standing somewhere else, more than 100 yards away or in
another zone. Your hover and map pin then use where you actually saw it, and the move goes into your report so
everyone's data gets fixed. It saves NPC
and item ids, prices, drop counts and where you stood. It saves **no character, realm or account names**.

**To send it:**

1. In game, type `/bog export`. A window opens with one long line starting `BOG1 {`, already selected.
2. Press **Ctrl+C** to copy it.
3. Open **[New data report](https://github.com/Noie331/brotherhood-of-gold-trade-helper/issues/new?template=data-report.yml)**.
   The title and label are already filled in.
4. Click in the **Report** box, press **Ctrl+V**, then click **Create**.

You need a free GitHub account to send a report. Send one whenever you've visited new vendors or looted recipes.
Sending again is fine, because every report you send is combined. Reports are merged into the data for the next
release, and your issue is closed when that's done.

---

## Problems

[Open an issue](https://github.com/Noie331/brotherhood-of-gold-trade-helper/issues/new) and include:

- what you did, and what happened;
- the text from `/bog probe`;
- any Lua error text. Type `/console scriptErrors 1` to show Lua errors.

---

Data credits: trainer, vendor, drop and quest data from cMaNGOS classic-db (GPL-3.0); some recipe sources from
Warcraft Wiki (warcraft.wiki.gg, CC BY-SA 3.0).
