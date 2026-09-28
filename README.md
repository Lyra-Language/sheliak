# Sheliak

A Sega Genesis / Mega Drive emulator written in [Lyra](https://github.com/Lyra-Language/lyra),
aiming to run any cartridge ROM, playable, and built to serve Vega's editors and debugger.

**Proprietary** — see `LICENSE`.

## Building and testing

Sheliak lives in the Lyra workspace beside the compiler:

```bash
../lyra/build.sh     # builds lyrac with std/ beside it
tests/cpu.sh         # fetches the 68000 test suite once, builds, runs every test
```
