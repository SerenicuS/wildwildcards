
# 🤠 Wild Wild Cards

### Reload. Shield. Shoot. Only one gunslinger walks away.

**Wild Wild Cards** is a fast-paced, Western-themed dueling game built with **Godot 4**, where every decision can mean the difference between victory and defeat.

Inspired by a classic schoolyard game of prediction and timing, Wild Wild Cards transforms three simple actions into a psychological showdown of risk, deception, and quick thinking.

There are no complicated weapon statistics, no elaborate combat combos, and no pay-to-win advantages.

Just you, your opponent, and three choices.

**RELOAD. SHIELD. SHOOT.**

Outthink your opponent. Survive the duel. Become a legend.

---

## 🎮 About the Game

Wild Wild Cards is a simultaneous-action strategy game where two gunslingers face each other in a Western showdown.

Both players secretly choose an action before the timer expires. Their actions are then revealed and resolved simultaneously.

The challenge isn't simply knowing when to shoot.

It's predicting what your opponent will do next.

Will they reload? Will they shield? Or are they about to pull the trigger?

A single wrong decision can end everything.

### Core Features

- Fast-paced simultaneous-action dueling
- Three-action combat system
- Randomized bot personalities
- Adjustable turn timers
- Solo duels against AI gunslingers
- Endless Gauntlet survival mode
- Local two-player multiplayer
- Multiple Western-themed arenas
- Character and revolver customization
- Cosmetic victory finishers
- Customizable WANTED posters
- Match history and replay system
- Persistent player profiles and statistics
- Offline Tournament Circuit with 8, 16, or 32 participants
- Tournament-specific gunslinger dossiers, statistics, and rankings
- Accelerated AI tournament simulation and spectator mode
- The Frontier career mode with four territories, travel, regional tournaments, and a career journal
- Searchable tournament Gunslinger Registry and participant dossiers

---

## 🔫 How to Play

Each turn, both gunslingers secretly choose one action.

| Action | Effect |
|--------|--------|
| 🔄 RELOAD | Adds one bullet to your revolver |
| 🛡️ SHIELD | Protects you against an incoming shot |
| 🔫 SHOOT | Fires one bullet if ammunition is available |

### Combat Rules

**Reload**
- Gain one bullet.
- Reloading leaves you vulnerable to an opponent's shot.

**Shield**
- Blocks incoming bullets for the current turn.
- Can only be used three consecutive times.
- Choosing another action resets your consecutive shield count.

**Shoot**
- Consumes one bullet when ammunition is available.
- Defeats an opponent who isn't shielding or simultaneously firing an armed shot.
- Attempting to shoot without ammunition produces an empty click.

**Simultaneous Shootout**
- If both gunslingers fire with ammunition, their shots cancel each other.
- Both bullets are consumed.
- The duel continues.

### Example

| Player 1 | Player 2 | Result |
|----------|----------|--------|
| RELOAD | RELOAD | Both gain ammunition |
| SHOOT | RELOAD | Player 1 wins if armed |
| SHOOT | SHIELD | Player 2 blocks the shot |
| SHOOT | SHOOT | Armed shootout; duel continues |
| SHIELD | RELOAD | Player 2 gains ammunition |
| RELOAD | SHOOT | Player 2 wins if armed |

**The winner isn't always the fastest player. It's the one who makes the right prediction.**

---

## ⏱️ Difficulty Settings

Difficulty determines how much time you have to select your action.

| Difficulty | Turn Timer |
|------------|------------|
| Easy | 2 seconds |
| Medium | 1.5 seconds |
| Hard | 1 second |

Bot intelligence does not receive artificial advantages at higher difficulties.

The challenge comes from making decisions under pressure.

---

## 🎯 Game Modes

### 🤠 Quick Play (Solo Duel)

Face an AI-controlled gunslinger in a classic one-on-one showdown.

Each opponent uses randomized personality modifiers that influence their decision-making.

Some gunslingers are aggressive.

Others are cautious.

Some prefer to stockpile ammunition.

Every duel presents a different psychological challenge.

### 💀 Endless Gauntlet

How many gunslingers can you defeat before someone finally takes you down?

Endless Gauntlet is a survival mode featuring consecutive duels against randomly generated opponents.

- Defeat an opponent to advance.
- Face a new gunslinger after every victory.
- Fight across randomized arenas.
- Build your consecutive victory streak.
- Track your personal best.
- Lose once, and your run ends.

Every new duel starts with fresh ammunition and shield counters.

**No checkpoints. No second chances. Just survival.**

### 👥 Local Multiplayer

Challenge another player on the same computer.

Both players select their actions simultaneously using separate keyboard controls.

Local multiplayer preserves the same combat rules as solo play.

No internet connection is required.

### 🏆 Tournament Circuit

Enter an offline single-elimination championship against a field of AI gunslingers.

Choose between **8, 16, or 32 participants**, with 32 selected by default. Every tournament includes one human competitor and a full roster of unique AI opponents.

| Tournament size | AI opponents | Rounds | Total matches |
|-----------------|-------------:|-------:|--------------:|
| 8 entrants | 7 | 3 | 7 |
| 16 entrants | 15 | 4 | 15 |
| 32 entrants | 31 | 5 | 31 |

- Play your matches using the standard Reload / Shield / Shoot rules.
- Follow the single-elimination bracket from the opening round to the championship.
- Face opponents with consistent names, personalities, and cosmetics throughout that tournament.
- View tournament-specific participant profiles, W/L statistics, and placements.
- Watch other AI matchups catch up through accelerated **4×**, **8×**, or **Instant** simulation.
- After elimination, spectate the rest of the competition or finish it instantly to reveal the champion.
- Review tournament records and archived results.

**All bot-versus-bot matches use the existing combat rules and AI decision-making.** Their winners are not simply chosen by a coin flip.

#### Tournament Gunslinger Profiles & Rankings

Each tournament maintains its own isolated roster of gunslingers and records. A participant dossier includes their name, appearance, revolver cosmetics, temperament, current status, and tournament results.

Tracked records include:

- Overall wins and losses
- Wins and losses against the human player
- Wins and losses against AI opponents
- Elimination round and eliminator
- Tournament placement

Rankings reflect **how far a participant advances in the bracket**, not just their win percentage. For a completed 32-player tournament, placements are **#1 champion**, **#2 runner-up**, **tied #3**, **tied #5**, **tied #9**, and **tied #17**.

These profiles and rankings are **exclusive to their own tournament**. Solo Duel, Endless Gauntlet, and other tournaments do not contribute to their records. Participant dossiers are accessible through the bracket and the searchable Gunslinger Registry.

### 🌵 The Frontier (Career Mode)

Travel across **Nevada, California, Texas, and Mississippi** through a lightweight, map-based career mode. Visit territory hubs, enter regional tournaments using the existing Tournament Circuit, and review your progress in the Frontier Journal.

- Choose a territory and travel between destinations.
- Enter regional tournaments whose results are attributed to that territory.
- Track visited territories, tournament entries, and regional championships.
- Resume an active tournament through the shared tournament system.

**Current scope:** Territory travel and regional tournament records are implemented. Regional champions, saloon activities, reputation, quests, and legendary titles remain future plans. The Frontier is not an open-world 3D game.

---

## 🎮 Controls

### Quick Play (Solo Duel)

| Action | Input |
|--------|-------|
| Reload | Select RELOAD |
| Shield | Select SHIELD |
| Shoot | Select SHOOT |

### Local Multiplayer

| Action | Player 1 | Player 2 |
|--------|----------|----------|
| Reload | A | J |
| Shield | S | K |
| Shoot | D | L |

> Input bindings and available menu controls may depend on the current build.

---

## 🧠 Gunslinger AI

Wild Wild Cards uses a weighted decision-making system rather than a fixed sequence of actions.

Bot behavior is influenced by factors such as:

- Current ammunition
- Available actions
- Previous opponent behavior
- Consecutive shields
- Aggression
- Caution
- Greed

Personality modifiers are randomized between opponents.

Bots do not inspect the player's hidden action before choosing their own.

This preserves the fairness of simultaneous decision-making.

A bot may make a risky decision, play defensively, or misjudge the situation.

Just like a real opponent.

---

## 🌵 Western Arenas

Take your duels across different locations in the Wild Wild Cards universe.

### Dusty Main Street
A classic frontier town showdown surrounded by wooden storefronts and desert dust.

### The Last Call Saloon
Settle your differences inside a Western saloon.

### Iron Horse Station
Duel beside the railroad as the frontier moves forward.

### Ghost Town
Face your opponent among the remains of an abandoned settlement.

Arenas are cosmetic environments and do not provide gameplay advantages.

---

## 🎩 Gunslinger Customization

Create your own frontier identity.

Customize your gunslinger using:

- Western hats and headwear
- Clothing and outerwear
- Ponchos, coats, and waistcoats
- Bandanas and accessories
- Outfit color combinations
- Saved cosmetic presets

Appearance customization is cosmetic-only.

### Revolver Customization

Choose from different revolver styles:

- Peacemaker
- Schofield
- Python
- Cobra

Customize your weapon with finishes and grips, including:

**Finishes**
- Classic Iron
- Blued Steel
- Polished Silver
- Ornate Gold

**Grips**
- Walnut
- Ebony
- Ivory-style
- Engraved

Your revolver's appearance does not change its combat performance.

**Style wins hearts. Strategy wins duels.**

---

## 🃏 Victory Finishers

Winning a duel deserves a memorable ending.

Wild Wild Cards includes cinematic, cosmetic victory finishers.

### WANTED: ELIMINATED
A classic Western wanted-poster elimination.

### Dead Man's Hand
A playing-card-inspired victory featuring the infamous black aces and eights.

### High Noon
A dramatic Western sunset showdown.

### Smoke & Mirrors
A smoky cinematic victory reveal.

Players can customize their preferred finisher.

All finishers are cosmetic and have no influence on combat.

---

## 📜 WANTED Posters & Gunslinger Identity

Every gunslinger deserves a legend worth remembering.

Wild Wild Cards features customizable WANTED posters that can showcase a player's:

- Gunslinger name
- Character appearance
- Equipped cosmetics
- Nameplate or earned title
- Western-themed presentation

Posters are designed to be screenshot-friendly and shareable.

Future expansions will extend this system to legendary championships, historical title holders, and the Hall of Legends.

One day, your WANTED poster might be proof that you ruled an entire territory.

---

## 🎞️ Match History & Replays

Relive your greatest victories and most embarrassing defeats.

The replay system records completed duels and allows players to revisit their decisions.

Features include:

- Match history
- Turn-by-turn action records
- Replay navigation
- Playback controls
- Ammunition and shield state tracking
- Gauntlet match history
- Arena and cosmetic snapshots

Replays reproduce recorded outcomes instead of recalculating AI decisions.

Every duel tells a story.

Even the ones you'd rather forget.

---

## 💾 Player Profiles & Career Records

Wild Wild Cards supports persistent player profiles.

Profile data includes supported settings and records such as:

- Player identity
- Character appearance
- Revolver customization
- Preferred finisher
- Mode-specific career statistics and match records, where supported
- Gauntlet records
- Saved cosmetic presets

The game also uses versioned save data and recovery safeguards. Statistics may vary with the game version and available historical records.

Tournament completion includes recovery and duplicate-award protections; unexpected shutdowns and storage failures are still worth reporting.

---

## 🛠️ Built With

- **Engine:** Godot 4.x
- **Language:** GDScript
- **Genre:** Simultaneous-action strategy / Western dueling
- **Primary Platform:** Windows
- **Multiplayer:** Local offline multiplayer
- **Rendering:** Lightweight, compatible with integrated graphics

The project prioritizes accessible performance and responsive gameplay.

---

## 📥 Installation

### Playing a Release Build

1. Visit the repository's Releases section.
2. Download the available build for your platform.
3. Extract the downloaded archive if necessary.
4. Launch the game executable.

> If the Releases page has no downloadable build yet, use the source instructions below. Only download builds from the official repository.

### Running From Source

1. Install a compatible version of Godot 4.
2. Clone the repository:

```bash
git clone https://github.com/<YOUR_USERNAME>/Wild-Wild-Cards.git
```

3. Open Godot.
4. Import the project's `project.godot` file.
5. Allow the editor to import project resources.
6. Run the project.

Replace `<YOUR_USERNAME>` with the actual repository owner before publishing this README.

---

# 🗺️ Development Roadmap

Wild Wild Cards is an evolving independent project. The roadmap below distinguishes **implemented features** from ideas that are not yet playable. Features and availability may change between builds.

### ✅ Implemented foundations

- [x] Simultaneous Reload / Shield / Shoot combat and weighted bot personalities
- [x] Quick Play, Endless Gauntlet, and local two-player duels
- [x] Player identity, cosmetic customization, revolvers, arenas, and finishers
- [x] Match history and turn-by-turn replays
- [x] Offline 8-, 16-, and 32-player Tournament Circuit
- [x] Tournament bracket, participant dossiers, rankings, searchable registry, archives, and spectator catch-up
- [x] Tournament completion recovery and duplicate-award safeguards
- [x] Frontier foundation: map, four territories, travel, hubs, regional tournaments, and journal

### 🛠️ Ongoing improvements

- [ ] Navigation, presentation, and accessibility polish
- [ ] Expanded and verified career statistics across modes
- [ ] Manual end-to-end testing and release packaging

### 🌵 Planned expansions — not yet implemented

- **Regional champions and recurring rivals:** memorable opponents and territory-specific challenges
- **Legendary Gunslingers:** title challenges, title lineages, and Hall of Legends
- **Frontier activities:** saloons, optional encounters, and narrative events
- **Online multiplayer:** remote duels, matchmaking, and possible competitive events
- **Frontier Chronicle:** historical newspaper-style records and champion stories
- **Bounty Board and story content:** optional character-driven challenges
- **Fantasy Frontier:** experimental supernatural Western ideas, separate from standard competitive rules where needed

These are development intentions, not promises of delivery or release dates.

---

## 🎯 Development Philosophy

Wild Wild Cards follows a simple philosophy:

**Easy to understand. Difficult to master.**

The combat system is intentionally small.

The depth comes from prediction, uncertainty, timing, and the psychology of your opponent.

Future updates aim to expand the world around the duel rather than burying it beneath unnecessary complexity.

No matter how large the Frontier becomes, its foundation remains the same:

**RELOAD. SHIELD. SHOOT.**

---

## 🤝 Contributing

Wild Wild Cards is an evolving independent game project.

Feedback, bug reports, balancing suggestions, and feature ideas are welcome.

If you encounter an issue, consider including:

- A description of the problem
- Steps to reproduce it
- Your game version
- Relevant debug logs
- Screenshots when applicable

---

## 🤖 AI-Assisted Development Disclosure

Wild Wild Cards has been developed with the assistance of generative AI tools, including AI coding assistants, for tasks such as brainstorming, code generation, debugging, documentation, and development planning.

AI-generated suggestions and code are incorporated into the project through an iterative development process. **The project maintainer is responsible for deciding what to include, reviewing and testing changes, and maintaining the released project.** AI assistance does not mean every generated change has been independently verified or is free of bugs.

This disclosure is intended to be transparent about the development process, not to suggest that the game's opponents use a generative language model. In-game gunslinger opponents use a weighted decision-making system described above.

Contributors should disclose substantial AI-assisted contributions when relevant and verify that their submissions can legally be distributed under the project's license.

---

## ⚠️ Development Disclaimer

Wild Wild Cards is an independent project under active development. Builds may contain bugs, incomplete features, balancing changes, or save-format updates. Back up important save data before trying experimental releases.

Any third-party assets, fonts, audio, libraries, or other material included in the repository may be subject to their own licenses. Consult applicable attribution or asset notices before reusing them.

---

## 📄 License

The original project source code is released under the **MIT License**. See [LICENSE](LICENSE) for the full license text.

You may use, modify, distribute, and sublicense MIT-licensed portions of the project, including commercially, provided you retain the required copyright and permission notices. The software is provided **as is**, without warranty.

**Important:** The MIT License does not override separate terms for third-party assets or other content that the project maintainer does not have rights to relicense.

---

## 🤠 Final Words

Every gunslinger starts somewhere.

Some survive a single duel.

Some survive a hundred.

Some become champions.

And a few become legends whose names are remembered long after their final showdown.

**Welcome to Wild Wild Cards.**

*Draw wisely, partner.*
