<p align="center">
  <img src="assets/logo.png" alt="MR X" width="220">
</p>

<h1 align="center">X AI Dispatch</h1>

<p align="center">
  A smart emergency dispatch system for FiveM — automatic alerts, 911 triage, nearest-unit assignment and a living city of incidents.<br>
  <b>Developed by MR X &nbsp;•&nbsp; Published by X Studio</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.0-blue" alt="version">
  <img src="https://img.shields.io/badge/FiveM-Lua%205.4-orange" alt="fivem">
  <img src="https://img.shields.io/badge/Qbox%20%7C%20QBCore%20%7C%20ESX-supported-success" alt="frameworks">
  <img src="https://img.shields.io/badge/ox__lib-required-lightgrey" alt="ox_lib">
  <img src="https://img.shields.io/badge/license-Commercial-black" alt="license">
</p>

---

## ✨ Features

- 🚨 **Dispatch panel** — priority-sorted call list with distance, units, reports, GPS, respond and close (default key **F6**)
- 🧠 **Smart ("AI") engine** — rule-based, runs entirely on your server, no external service:
  - **911 triage:** `/911 <message>` is classified by keywords into the right service and priority
  - **Call merging:** repeated reports of the same event within a radius become one call with a report count
  - **Auto-assign:** the nearest available unit of each service is assigned to high-priority calls
  - **Incident generator:** adaptive, weighted scenarios keep the city busy while responders are online
- 🔫 **Automatic alerts** — gunshots (silenced handled separately), carjacking, fights, reckless driving; positions come from the server, with witness delay, cooldowns, chance and no-alert zones
- 🆘 **Panic button** — `/panic` alerts every service at the responder's location
- 🗺️ **Map** — flashing call blips with radius, live on-duty unit blips
- 🪪 **Status & callsigns** — available / busy, custom callsign
- 🧾 **History** — every closed call is stored in `x_dispatch_history`; optional Discord webhook
- 🔌 **Framework bridge** — Qbox, QBCore, ESX or standalone (ACE permissions), auto-detected
- 🌍 **Localization**, **exports** and an **admin command**

## 📦 Requirements

| Dependency | Notes |
| --- | --- |
| [ox_lib](https://github.com/overextended/ox_lib) | required |
| [oxmysql](https://github.com/overextended/oxmysql) | required |
| Qbox / QBCore / ESX | optional (standalone uses ACE) |

## 🚀 Installation

1. Drop the `x_aidispatch` folder into your `resources` directory.
2. Import `sql/install.sql` (the table is also created on first start).
3. Add to `server.cfg` **after** `ox_lib`, `oxmysql` and your framework:
   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure x_aidispatch
   ```
4. Edit `config.lua`: set your job names under `Config.Services`.
5. **Standalone only:** grant access with ACE, for example
   ```cfg
   add_ace group.police xdispatch.police allow
   add_ace group.ems xdispatch.ems allow
   ```
6. (Optional) set your language: `setr ox:locale "en"`.

## ⚙️ Configuration

Everything lives in [`config.lua`](config.lua).

| Option | Description |
| --- | --- |
| `Services` | Service names, framework jobs, duty requirement, unit blip color |
| `AutoAssign` | Enable auto-assignment and the highest priority number it applies to |
| `MergeSeconds` / `MergeRadius` | Call merging window |
| `CallExpireMinutes` / `MaxCallMinutes` | Call lifetime |
| `Alerts` | Automatic alert types: text, priority, chance, cooldown |
| `IgnoreWeapons` / `IgnoreZones` | Weapons and areas that never raise alerts |
| `Triage` | Keyword rules used by `/911` |
| `Panic` | Panic button text and toggle |
| `AI` | Incident generator timing, minimum responders, max open calls |
| `Scenarios` | Generated incidents: weight, cooldown, descriptions, locations |
| `Webhook` | Discord webhook URL for logs |

> Call titles and descriptions come from `config.lua`, so translate them there; UI text lives in `locales/*.json`.

## 🎮 Commands & keys

| Command / key | Who | Description |
| --- | --- | --- |
| `F6` or `/dispatch` | Responders | Open the dispatch panel |
| `/dstatus` | Responders | Set status (available / busy) |
| `/callsign` | Responders | Set your callsign |
| `/911 <message>` | Everyone | Call emergency services |
| `/panic` | Responders | Send a priority-1 panic alert |
| `/dispatchclear` | Admins (`group.admin`) | Clear all active calls |

### Server exports

```lua
exports.x_aidispatch:CreateCall({
    type = 'bank_alarm', title = 'Bank alarm', desc = 'Silent alarm triggered.',
    coords = vec3(150.0, -1040.0, 29.3), priority = 1, services = { 'police' },
})
exports.x_aidispatch:GetCalls()
exports.x_aidispatch:CloseCall(callId)
```

## 🔐 Security notes

- Clients only send an alert *type*; the server picks the position, enforces cooldowns, chance and no-alert zones.
- Every responder action checks job/duty (or ACE) on the server, and only assigned units can close a call.
- Never commit your webhook URL to a public repository.

## 🗂️ Project structure

```
x_aidispatch/
├─ assets/logo.png
├─ client/main.lua
├─ server/bridge.lua      # framework abstraction
├─ server/main.lua
├─ locales/en.json
├─ sql/install.sql
├─ config.lua
├─ fxmanifest.lua
├─ LICENSE
└─ CHANGELOG.md
```

## ❓ FAQ

**Is this real AI / an LLM?** No. The "AI" is a deterministic rule-based engine (triage, merging, nearest-unit assignment, weighted incident generation). It needs no API keys and has no external dependencies.

**How do I add a job?** Add its framework job name to `jobs` in `Config.Services`. For a new service, add an entry there and reference it in alerts, triage and scenarios.

**Can other resources create calls?** Yes — use the `CreateCall` export.

## 💬 Support

- Developer: **MR X**
- Studio: **X Studio**
- Discord: **mr_xdev** — <https://discord.com/users/1019985047178182758>

Please include your server artifact version, framework and console errors when requesting support.

## 📄 License

Commercial license — see [LICENSE](LICENSE). © X Studio / MR X. All rights reserved.

<p align="center"><sub>Made with ❤️ by MR X • X Studio</sub></p>
