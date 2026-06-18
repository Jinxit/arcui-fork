## 3.7.2.a

### New Features

- **Castbar**: A brand-new player cast bar, with per-cast-type profiles, an optional Auto Share toggle so one cast type's look carries across the others, full support for empowered spells (proper stage segments and timing), and threshold-based color changes. Big thanks to Sadraii, who created the original cast bar module this was expanded from.
- **Dynamic Cooldowns**: A new per-group option that compacts your cooldown icons the same way Dynamic Auras does: icons drop out and the rest slide together based on whether they're ready or on cooldown. Works hand-in-hand with Dynamic Auras.
- **Smooth Movement**: When a dynamic group rearranges, icons now glide smoothly into their new spot instead of snapping, with an adjustable speed. Opt-in per group.
- **Icon Order: First Come, First Served**: Choose how a dynamic group orders its icons: classic Priority order, or First Come First Served, where the icon that became active first keeps its spot and new ones line up after it instead of everything reshuffling.
- **Custom Icon Stacks: Start Full & Recharge**: Custom timer icons can now show full stacks from the start before the first cast, plus a new "Timer Complete" generator with "Recharge until full" to build charge-style stack behavior.
- **What's New Window**: ArcUI now shows a changelog after each update so you always know what changed. Toggle it off in Settings.

### Improvements

- **Bar Performance**: The buff/debuff/stack bar tracking engine was rebuilt from the ground up for smoother updates and noticeably lower CPU use, especially when tracking lots of auras at once.
- **Lower CPU Spikes**: Big reductions in the CPU hitch when leaving combat and when players join your party or raid.
- **Cleaner Custom Icon Options**: The Custom Icons (timer) settings panel now only shows options that actually apply to timers, with the Active / Not Active states behaving correctly and "Hide at 0" working properly for stacks.
- **Totem Dynamic Placement**: Empty totem slots now collapse and compact with Dynamic Auras, keeping your totem icons tidy.

### Bug Fixes

- **Reverse Swipe While Aura Active**: Fixed the swipe reverting to its normal direction when you left combat while the aura was still active; it now stays reversed for the full duration.
- **Charge Spell Placement**: Fixed dynamic placement sometimes failing on charge spells, where an icon wouldn't collapse or return as a charge was spent or came back.
- **Hide CDM Icon staying hidden**: Fixed the Blizzard cooldown frame coming back when a bar had "Hide CDM Icon" turned on, after logging in or reloading, when entering or leaving combat, and when opening the options panel. It now stays hidden at all times, including free-floating icons.
