# buclarp

**buclarp** is a fast, organic, Buchla-inspired 16th-note generative arpeggiator for [monome norns](https://monome.org/docs/norns/).

Designed for performance and generative sound design, it transforms simple scales into living, breathing acoustic textures through controlled uncertainty, versatile step traversals, dynamic filtering, multi-waveform LFO modulation, and spatialized stereo panning.

---

## Features

- **Source of Uncertainty (CHAOS)**: Inspired by the Buchla 266, the `CHAOS` engine injects diatonic variations (3rds, 5ths, and octaves) rather than random noise, preserving harmonic context while evolving endlessly.
- **Dynamic Timbre Sparks**: Peak notes reaching Octave 4 automatically open the filter cutoff to maximum (`127`), creating sparkling accents over lower, darker ostinatos.
- **Multi-Waveform LFO Modulation**: Assignable LFO with 6 waveforms (`Sine`, `Triangle`, `Saw Down`, `Saw Up`, `Square`, `S&H Random`) routable to `Release`, `Cutoff`, `Resonance`, `Pan`, or any `Custom CC`.
- **Advanced Step Traversal**: 7 playback direction modes including `Forward`, `Reverse`, `Ping-Pong`, `2 Fwd / 1 Back`, `2 Fwd / 3 Back`, `Brownian (Drunk)`, and `Random`.
- **40+ Musical Scales**: Full library of scales via `musicutil` (Dorian, Lydian, Pentatonics, Blues, Japanese Hirajoshi/Kumoi/Insen, Indian Ragas, Whole Tone, and more).
- **Flexible Step Length**: Variable loop length from `1` to `16` steps. Setting length to `1` produces rapid glitchy machine-gun pulses modulated by Chaos.
- **Stereo Spatialization**: Alternating ping-pong or per-step custom pan positions with adjustable stereo width (`0%` to `100%`).
- **Hardware-Tailored MIDI Profiles**: Defaults to standard `General MIDI`, with instant presets for `Ambient Ø`, `microKORG 2`, `Nymphes`, `MicroFreak`, and user-defined `Custom`.
- **Anti-Stuck Note Engine**: Active note tracking and automatic panic sweeps prevent hanging notes on script reload, stop, or mode switches.
- **Minimalist OLED Interface**: Clean, uncluttered bar display with zero visual noise.

---

## Hardware Synthesizer Profiles

Select your target hardware directly from `PARAMETERS > SYNTH PROFILE & MIDI > Target Synth` (Defaults to **General MIDI**):

| Profile | Filter Cutoff | Amp Release / Decay | Resonance | Pan (Stereo) | Notes |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **General MIDI** *(Default)* | CC 74 | CC 72 | CC 71 | CC 10 | Standard GM implementation / VSTs |
| **SONICWARE LIVEN Ambient Ø** | CC 38 | CC 41 | CC 39 | CC 53 | Full custom CC mapping |
| **KORG microKORG 2** | CC 74 | CC 72 | CC 71 | CC 10 | Complete CC implementation |
| **Dreadbox Nymphes** | CC 74 | CC 72 | CC 71 | *Disabled* | Mono analog output safety |
| **Arturia MicroFreak** | CC 23 | CC 106 | CC 83 | *Disabled* | Mono output safety |
| **Custom** | *User defined*| *User defined* | *User defined*| *User defined*| Assignable in PARAMS |

---

## Interface & Controls

### Performance Mode (Default View)

The performance screen displays an uncluttered visual representation of active steps, note heights, and peak octave accents.

| Control | Action | Range / Values | Description |
| :--- | :--- | :--- | :--- |
| **K2** | Press | `RUN` / `STOP` | Start or stop sequence playback |
| **K3** | Press | — | Toggle between **Performance** and **Setup** mode |
| **E1** | Turn | `0%` – `100%` | **CHAOS** — Probability of harmonic 3rd/5th/octave leaps |
| **E2** | Turn | `1` – `4` | **OCTAVE** — Playable octave range |
| **E3** | Turn | `1` – `16` | **LENGTH** — Active step count (instant polyrhythms / 1-step repeat) |

### Setup Mode (Press K3)

| Control | Action | Range / Values | Description |
| :--- | :--- | :--- | :--- |
| **E1** | Turn | `C1` (24) – `C4` (60) | **ROOT NOTE** — Base pitch of the scale |
| **E2** | Turn | 40+ scales | **SCALE** — Select musical mode/scale |
| **E3** | Turn | `30` – `300` BPM | **TEMPO** — Directly adjust global BPM from the screen |
| **K3** | Press | — | Return to **Performance Mode** |

---

## Parameters Menu (`K1` + `E1`)

### `SYNTH PROFILE & MIDI`
- `Target Synth`: Select active synth preset (Default: `General MIDI`).
- `MIDI Device`: Select norns MIDI device port.
- `MIDI Channel`: Target MIDI channel (`1`–`16`).

### `PLAYBACK CONFIG`
- `Direction Mode`: 
  - `Forward`: Linear ascending (`1 → 2 → 3...`)
  - `Reverse`: Linear descending (`16 → 15 → 14...`)
  - `Ping-Pong`: Bounces back and forth between step limits (Default).
  - `2 Fwd / 1 Back`: Advances 2 steps, retreats 1 (`1, 2, 1, 2, 3, 2, 3...`).
  - `2 Fwd / 3 Back`: Advances 2 steps, retreats 3 (Pendulum-like displacement).
  - `Brownian`: Drunk walk (50% forward, 30% backward, 20% stationary).
  - `Random`: True arbitrary step selection.

### `PAN SETTINGS`
- `Pan Mode`:
  - `Ping-Pong Auto`: Alternates Left/Right with randomized depths per step.
  - `Step Pattern`: Reads individual pan values from `STEP PAN CONFIG`.
  - `Random`: Random pan position within width bounds.
  - `Off / Center`: Centers all notes (`64`).
- `Pan Width %`: Stereo spread (`0%` mono to `100%` wide stereo).
- `STEP PAN CONFIG (1-16)`: Individual pan positions (`0`–`127`) for each step.

### `LFO MODULATION`
- `Destination`: `Release / Decay`, `Cutoff`, `Resonance`, `Pan`, `Custom CC`, or `Off`.
- `Custom Target CC`: Target CC number (`1`–`127`) when Destination is set to `Custom CC`.
- `Waveform`: `Sine`, `Triangle`, `Saw Down`, `Saw Up`, `Square`, or `S&H (Random)`.
- `Rate`: LFO speed in Hz (`0.02 Hz` / 50s slow cycle to `10.0 Hz` rapid wobble).
- `Base / Center Value`: Midpoint CC value (Default: `0`).
- `Depth %`: Modulation swing intensity (`0%` to `100%`).

### `TIMING & DYNAMICS`
- `Gate Length %`: Note gate duration (`10%` tight staccato to `95%` legato).
- `Base Cutoff`: Resting filter cutoff level for Octaves 1–3 (`10`–`110`).

---

## Installation

1. Connect your norns via Wi-Fi and open [Maiden](https://monome.org/docs/norns/maiden/).
2. In the Maiden REPL prompt, run:
   ;install https://github.com/sumik-svg/buclarp
(Or create a directory named buclarp inside dust/code/ and place buclarp.lua inside).
3. Launch buclarp from the norns script selector.
Requirements
monome norns (standard or shield)
Any MIDI-compatible hardware synthesizer or USB-MIDI interface
