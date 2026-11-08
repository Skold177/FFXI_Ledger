# FFXI Ledger

FFXI Ledger is a gil tracker for Ashita v4, made for Phoenix XI. A small window shows your gil and how full your bags are. Click it to open the ledger: every gil change and where it came from, totals by day, your biggest earnings and spending, and all your characters added together.

It works from what the server already sends your client, the same messages that fill your chat log. The only thing it ever sends is an item move, when you drag an item between your bags yourself.

<img width="1225" height="1120" alt="image" src="https://github.com/user-attachments/assets/c0a44916-59cd-4a65-a3b7-e96acaf642e2" />

## Features

- **Gil display:** your gil and your Inventory and Mog Satchel counts in a small window you can put anywhere. A bag count changes colour when the bag is nearly full, and again when it's full.
- **Where your gil went:** every change is recorded with its source: monsters, training regimes, NPC shops, guild shops, the auction house, bazaars, player trades, the delivery box and NPC fees.
- **Overview:** earned, spent and net for the period, by category. Click a category to see its entries.
- **Days:** a chart and a table of what you earned and spent each day. Click a day to see its entries.
- **Top Sources:** your 25 biggest earners and your 25 biggest expenses.
- **Ledger:** every entry with its date, amount, category, details, zone and your balance afterwards, grouped under day headings. Filter it, sort it and search it.
- **Periods:** Session, Today, 7 Days, 30 Days, All, or any dates you pick on a calendar.
- **Gil per hour:** the Session period shows gil per hour, and New Session starts a fresh run.
- **All your characters:** look at another character's ledger, or add all of them together, with your account's total gil.
- **Bags and item search:** every bag on one screen, a search for any item or key item on all your characters, and drag and drop between bags.
- **Themes:** Phoenix's dark red, Classic, or any of the game's own window styles.
- **CSV export:** save the whole ledger for a spreadsheet.

## Installing

Requires [Ashita v4](https://github.com/AshitaXI/Ashita-v4beta).

1. Click **Code**, then **Download ZIP**, on this page and extract it.
2. Copy the `ledger` folder into your Ashita `addons` folder, so you end up with `addons/ledger/ledger.lua`.
3. In game, type `/addon load ledger`.

To load it every time you play, add `/addon load ledger` to your Ashita startup script. To update, replace the old folder. Your settings and your ledger are kept.

## Commands

| Command | What it does |
|---|---|
| `/ledger` | Show or hide the gil display |
| `/ledger show` / `/ledger hide` | Show or hide the gil display |
| `/ledger open` | Open or close the ledger. Clicking the gil display does the same |
| `/ledger gil [on\|off]` | Show or hide the gil amount on the display |
| `/ledger session` | Start a new session, for a fresh gil per hour |
| `/ledger bags` | Open the ledger on your bags |
| `/find <name>` | Find an item or key item on all your characters |
| `/ledger find <name>` | Same as `/find` |
| `/ledger theme <name>` | Switch theme: `phoenix`, `classic`, `lines`, `silver`, `violet`, `stone`, `gray`, `parchment` or `teal` |
| `/ledger scale <0.5-3>` | Change the size of both windows |
| `/ledger lock` / `/ledger unlock` | Stop or allow dragging the windows |
| `/ledger reset` | Put both windows back where they started |
| `/ledger export` | Save the whole ledger as a CSV file |
| `/ledger help` | List the commands in game |

## The gil display

- Click it to open or close the ledger. Drag it to move it.
- Right-click it for Gil Ledger, Gil Amount, Gil Per Character, Bag Counts, Lock Window, Theme, Reset Position, Hide, Scale and Opacity.
- **Gil Per Character** lists the gil on each of your characters with the total underneath. Other characters show the gil they had the last time you played them with Ledger loaded.
- You can turn off the gil amount or the bag counts, but not both. To hide the whole display, type `/ledger`.

## The ledger

Along the top are the character list, that character's gil, **Back** and **Close**. Back undoes your last change of view or period, so after clicking into a day you can go straight back to where you were.

Under that are the views (Overview, Days, Top Sources, Ledger and Bags) and the periods. A line under the periods says which dates you're looking at, for example `Since Thu 10/15/2026 (24 days)`. The four tiles show Earned, Spent and Net, then Per Hour for the session, Entries for a single day, or Per Day for anything longer.

The footer has the number of entries, the Theme list, Options and Export CSV.

### Periods

- **Session:** since you logged in or loaded the addon. **New Session** restarts it from now, for a gil per hour run. Nothing is removed from the ledger.
- **Today:** since midnight on your computer's clock.
- **7 Days** and **30 Days:** the last 7 or 30 days, up to now.
- **All:** everything Ledger has recorded.
- **Dates:** opens a calendar. Each day is tinted green or red by that day's net. Click one day, or two days for a range. Today, This Month and Last Month pick those for you.

### The Ledger view

- Filter by category, show gains only or spending only, and sort by newest, oldest or largest. The search box matches the details or the zone.
- Each day starts with a heading showing that day's net, its number of entries, what was earned and spent, and the balance at the end of the day.
- Hover an entry to see the price of each item, your balance before and after, the zone and the exact time.
- Right-click the column headings to show or hide Category, Zone and Balance. Zone starts hidden.

## Where gil is tracked from

| Category | What counts |
|---|---|
| Monsters | Gil dropped by monsters, named after the monster |
| Training Regimes | Field of Valor training regime rewards |
| NPC Shops | Buying from and selling to NPC shops, with the item and the NPC |
| Guild Shops | Buying from and selling to guild shops |
| Auction House | Purchases, listing fees, and sale money collected from the delivery box |
| Bazaars | Buying from other players' bazaars, and sales from yours |
| Player Trades | Gil traded with another player |
| Delivery Box | Gil sent or received through the delivery box |
| NPCs & Services | Gil paid to or received from an NPC, like a teleport fee or a quest reward |
| Untracked | Your gil changed while Ledger wasn't running. It counts in All and in dates, but not in Session |
| Other | A change Ledger couldn't match to a source |

## All your characters

Each character keeps its own ledger. Once you've played more than one character with Ledger loaded on the same PC, the name at the top of the ledger becomes a list.

- Pick another character to see their ledger and their gil.
- Pick **All characters** to add everyone together. Each entry shows which character it belongs to, and the Balance column and the day headings show the total gil across all your characters at that point. The gil at the top is your account total.
- Gil you move between your own characters by trade or through the delivery box is left out of the totals, since it was neither earned nor spent. The Overview says how many of those transfers were left out.
- Other characters' ledgers are reread every 10 seconds, so two characters played at the same time on one PC both stay up to date.

So if one character buys the materials and another sells what was crafted, All characters shows the real profit.

## Bags and item search

The Bags view shows Inventory, Mog Satchel, Mog Safe, Storage and Mog Locker (once you have one) together on one screen. Hover an item to see its name and count.

- **Search:** type in the search box, or use `/find <name>`. It matches the item's short or full name (`flask of distilled water`), key items, item numbers, and `*` wildcards like `*crystal`. Matching items are outlined and the rest are dimmed.
- It searches every bag, including Mog Case, Mog Sack, Mog Safe 2, the wardrobes and temporary items, on all your characters. Each other character shows how long ago their bags were saved.
- Your bags are saved every 30 seconds when something changes, and when you zone or unload the addon.

## Moving items

In the Bags view, drag an item onto another bag, or right-click it and pick **Move to** any bag that's open. The whole stack moves to the first free space, one item at a time.

- **Inventory and Mog Satchel:** anywhere.
- **Mog Safe and Storage:** in your own Mog House.
- **Mog Locker:** wherever your lease lets you use it, as the server tells your client each time you zone.

Bags you can't use where you are stay on screen, greyed out with `(locked here)` next to their name. Hover one to see why.

Ledger never sends a move the server would refuse. It won't move anything:

- while zoning, in a cutscene, or just after talking to or trading with an NPC
- during a trade with a player, while synthesizing, or while selling to a shop
- if the item is equipped, locked, for sale in your bazaar, or waiting to be sold at a shop you're talking to
- if the bag it's going to is full

When a move can't happen, a line under the bags says why. Turn moving off with **Move items between bags** in Options. The bags are still shown, and nothing is ever sent.

## Themes

Pick a theme from the Theme list at the bottom of the ledger, Theme in the right-click menu, or `/ledger theme <name>`. It applies to both windows.

- **Phoenix** (the default): dark red windows with rounded corners.
- **Classic:** the game's deep blue window style, with olive-gold lines.
- **Lines**, **Silver**, **Violet**, **Stone**, **Gray**, **Parchment**, **Teal:** the game's other window styles, drawn the way the game draws them.

The game themes use the window art from your own FFXI install, read when you switch to them. If a file can't be read, you get a message in chat and a plain background instead.

## Your data

Everything is saved in `config/addons/ledger/` inside your Ashita folder, with one set of files per character:

| File | What's in it |
|---|---|
| `<Name>_<id>_ledger.tsv` | Every entry, added as it happens |
| `<Name>_<id>_balance.txt` | Your last gil balance |
| `<Name>_<id>_items.tsv` | Your bags, so your other characters can search them |
| `<Name>_<id>_ledger.csv` | Written when you use Export CSV or `/ledger export` |

Settings are saved per character, in a folder with the character's name and ID.

## What it reads and sends

Ledger reads the packets the server sends your client (gil changes, gil messages, and shop, auction house, delivery box, trade and bazaar windows) and the ones your own client sends when you buy, sell or bid. It never changes or blocks any of them.

The only packet Ledger sends is an item move, when you drag or right-click an item yourself. It's the same packet the game sends when you move an item in its own menus. With **Move items between bags** turned off, Ledger sends nothing at all.
