[README.md](https://github.com/user-attachments/files/34735899/README.md)
# AIPOCALYPSE

A fully self-contained Commodore 64 demo written in 6502 assembly (ACME syntax).

**PAL only · No external assets required · Assembles to a single PRG**

![C64](https://img.shields.io/badge/Platform-Commodore%2064-blue) ![Assembler](https://img.shields.io/badge/Assembler-ACME-orange) ![Music](https://img.shields.io/badge/SID-Rob%20Hubbard-purple)

## What it does

- Overlapping multi-colour raster bars moving in a sinusoidal pattern
- Sprite-based scrolling text with soft fade
- Animated logo that bounces and collides with the bars
- Stable raster timing, sprite multiplexing and open vertical border
- Embedded Rob Hubbard music (*One Man and His Droid*)

Everything (code, font, logo bitmap, music data) is contained in a single `.asm` file.

## How this code was created

This entire program was written **exclusively through AI prompting**. No human-written assembly was added.

### Process

1. **Initial prompt** (Perplexity chat + Claude Sonnet):
   > “Write a Commodore 64 assembly program with overlapping raster bars that move up and down the screen in a sinusoidal pattern, then give it to me as a PRG file that I can run in VICE.”

2. The first result produced raster bars that were **not correctly timed**.

3. Over the following **4–5 hours** I iteratively asked the AI to:
   - Fix timing and stabilise the raster effects
   - Add a scrolling text message
   - Implement a bouncing logo with collision against the bars
   - Add music
   - Open the vertical border
   - Handle sprite multiplexing and colour-table switching
   - Polish cycle-exact kernels

4. The conversation later moved to Perplexity’s **“Computer”** mode. In that mode the AI first used **Claude Opus**, then switched to **OpenAI o1**.

The final result is the file you see in this repository.

## Building

Requirements:

- [ACME](https://github.com/meonwax/acme) cross-assembler

```bash
acme --strict-segments -f cbm -o aipocalypse.prg aipocalypse.asm
```

## Running

Any PAL Commodore 64 emulator works. Recommended:

```bash
x64sc aipocalypse.prg          # VICE (accurate)
# or
x64 aipocalypse.prg
```

## Technical notes

- Cycle-exact raster bar kernel
- Two stable sprite kernels (logo + scroller)
- Open vertical border (opened once at boot and kept open)
- Double-buffered sprite shifting for the scroller
- Music player and data embedded at `$1000`
- Font at `$3000`, logo sprites at `$2C00`

## Credits

- **Code**: Generated entirely by AI (Claude Sonnet → Claude Opus → OpenAI o1) under iterative human prompting
- **Music**: Rob Hubbard – *One Man and His Droid* (HVSC)
- **Font**: Derived from the font used in *Attack of the Mutant Camels* (public domain / freely available)
- **Inspiration / references**: Classic C64 demoscene techniques (raster bars, sprite multiplexing, open border)

## License

The assembly source is released as-is.  
Music data remains under the original author’s rights (Rob Hubbard). Use responsibly.

---

*“When the bars touch the logo there is no room for a separate IRQ…”*  
— a comment written by the AI during development
