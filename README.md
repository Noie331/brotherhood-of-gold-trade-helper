# Brotherhood of Gold - Trade Helper

A WoW Forever addon for levelling professions: what each recipe costs to craft (AH and vendor prices), what it sells
for, which recipes make a profit, and every recipe of a profession
with where to get it (trainer, vendor, drop with drop chance, quest) and a map pin on the nearest one.

Test build - thanks for trying it.

## Install

1. Open **Releases** (right-hand side of this page) and download `BrotherhoodOfGold_TradeHelper-vX.Y.Z.zip`.
2. Unzip it into `World of Warcraft\_forever_\Interface\AddOns\` so you get
   `...\AddOns\BrotherhoodOfGold_TradeHelper\BrotherhoodOfGold_TradeHelper.toc`.
3. Restart the game (or `/reload`).

To update, delete the old `BrotherhoodOfGold_TradeHelper` folder and unzip the new one.

## Use

- Open a profession, then click the gold tab on the side of the profession window, or type `/bog`.
- At the auction house, click **Scan AH** for prices (once every 15 minutes).


## Help fill in where recipes come from

While you play, the addon notes vendors, drops and trainers it doesn't know yet (npc ids, item ids, prices and map
positions - no character, realm or account names). `/bog record off` turns this off, `/bog record on` back on.

To send it: type `/bog export`, press Ctrl+C, then open **Issues → New issue → Recipe data report** here and paste it.
Sending again later is fine; only your latest report counts.

## Problems

Open an issue with what you did, what happened, and the `/bog probe` output (and any Lua error text).

Data credits: trainer, vendor, drop and quest data from cMaNGOS classic-db (GPL-3.0); some recipe sources from
Warcraft Wiki (warcraft.wiki.gg, CC BY-SA 3.0).
