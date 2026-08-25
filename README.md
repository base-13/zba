# ZBA

ZBA is a [Game Boy Advance](https://en.wikipedia.org/wiki/Game_Boy_Advance) emulator written in Zig

**Note:** This project is currently under-development

**Current State:** it is capable of decoding and executing ARMv4 instructions excluding coprocessor instructions which will not be implemented as GBA doesn't include any coprocessors.

## Build and Run:

Requires Zig 0.16.0

```
$ zig build run
```

## License:

Distributed under the GPL-3.0 [License](LICENSE).
