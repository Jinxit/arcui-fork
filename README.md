# ArcUI (Fork)

A maintained fork of [ArcUI](https://www.curseforge.com/wow/addons/arc-ui) — buff/debuff tracking bars, resource bars, cooldown bars, timer bars, and Cooldown Manager integration for World of Warcraft (retail).

## What's different?

This fork adds quality-of-life improvements on top of the upstream addon:

- **Health as a resource bar source** — track health alongside mana/rage/energy
- **Texture-based borders** — 8-slice backdrop renderer replacing the single-quad LSM border
- **Border inset controls** — hover preview, inset slider, extended range
- **CDM group anchor rework** — 9-point source/dest anchoring with percentage-based sizing

Custom changes are kept minimal and isolated to survive upstream merges. See individual PRs for details.

## Installation

Download the latest release from the [Releases](../../releases) page and extract into your `Interface/AddOns/` directory, or point [WowUp](https://wowup.io/) at this repo.

## Upstream

Upstream releases from [CurseForge](https://www.curseforge.com/wow/addons/arc-ui) are automatically synced into the `upstream` branch and merged into `main`. Custom patches are designed to layer on top without modifying upstream files where possible.

## License

This fork is maintained with permission from the original author. See [LICENSE.txt](LICENSE.txt) for the upstream license terms.
