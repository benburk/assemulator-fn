# assemulator-fn

An assembler and emulator for toy CPUs, written in
[Faun](https://github.com/benburk/faun-lang). It ports the Rust
[assemulator](https://github.com/benburk/assemulator): to support a new CPU you
write a few small functions, and you get a two-pass assembler, an emulator and
a command line.

Three CPUs come with it, and they run the Rust repo's example programs
unchanged, with the same output and the same assembled bytes:

- [RiSC-16](cpus/risc16/README.md): 16-bit, 8 opcodes, 8 registers
- [Photon](cpus/photon/README.md): 8-bit words, 16-bit instructions, one flag,
  about 40 opcodes
- [Mira](cpus/mira/README.md): an 8-bit accumulator machine, 24 opcodes,
  instructions of one to three bytes, memory operands, and ports at memory
  addresses

Each CPU builds to one program, which assembles a file and runs it. Build one
with the `faun` the flake's dev shell provides,
`faun build -o build/<cpu> cpus/<cpu>/main.fn`:

```console
$ faun build -o build/photon cpus/photon/main.fn
wrote build/photon
$ ./build/photon run cpus/photon/programs/hello_world.asm
Hello, World!
$ ./build/mira run cpus/mira/programs/collatz.asm
19
58
...
$ ./build/risc16 run cpus/risc16/programs/sieve.asm
2
3
5
...
$ ./build/photon run cpus/photon/programs/games/guessing_game.asm
$ ./build/risc16 assemble cpus/risc16/programs/multiplication.asm
$ ./build/risc16 run cpus/risc16/programs/countdown.asm --debug
```

`just build` builds every CPU into `build/`, `just demo` gives a short tour, `just` lists the recipes, and `just test` runs the library's `expect`s and then
every example program, checking each against its `.out` file.

## Assembler features

- Global labels, and local labels (`.loop`) scoped between global labels
- Macros with parameters: `MOVI: .macro dest, x` ... `.endm`
- Expressions: `(1 + label) * 4`, `($x >> 6) & 0x3ff`, `'a'`, `0b1010_0101`
- Includes, optionally namespaced: `string: .include "string.asm"`
- Directives: `.u8 .i8 .u16 .i16 .u32 .i32 .zero .strz .set .if .else .endif`
  `.abort`
- Errors that show the line, and the macro call they came from:

```text
error: cpus/risc16/programs/bad.asm:3: undefined label `tickr`
  |
3 |         sw $src, [tickr]
cpus/risc16/programs/bad.asm:6: in expansion of this macro
  |
6 |         PRINT r1
```

## Emulator features

- Port 0 prints a character, or reads the next character of a typed line
- Port 1 prints a number, or reads a typed line as one
- Interactive input: a read with nothing typed stalls the CPU until a line
  arrives, so the games work at a terminal or with piped input
- `--debug` prints the CPU's state before each step and waits for enter

## Adding a CPU

A CPU is one Faun file. It supplies a value whose type meets the
`InstructionSet` bound, which tells the assembler about registers and encoding:

```ruby
Isa : [Risc16].(
  register : (Isa, Str) -> Result(Nat, [NotRegister])
  opcodes : Isa -> List(Str)
  encode : (Isa, U64, Str, List(Argument)) -> Result(List(U8), Str)
  big_endian : Isa -> Bool
  boot : (Isa, U64, List(U8), List(U8)) -> Cpu
)
```

`boot` builds a processor from the start address, program and data, and the
processor meets `Processor`:

```ruby
Cpu : State.(
  step : (Cpu, Ports) -> (Cpu, Ports, Step)
  show : Cpu -> Str
)
```

`step` is pure: it gets the ports and returns them, and the runner does the
I/O. `Step` is `Continue`, `Halt`, `Blocked` (a port read found no input) or
`Fault(message)`. Encoding is pattern matching on the opcode and its arguments,
which reads much like the Rust version's `match`:

```ruby
encoded(_, "add", [Reg(a), Reg(b), Reg(c)]) -> fmt1(0, a, b, c)
encoded(_, "add", [Reg(a), Reg(b), Imm(k)]) -> fmt2(1, a, b, k)
encoded(_, "lw", [Reg(a), MemReg(b, k)]) -> fmt2(4, a, b, halved(k))
encoded(address, "beq", [Reg(a), Reg(b), Imm(target)]) -> fmt2(6, a, b, halved(target - address))
```

Then `main!(host) -> assemulator!(host, Risc16)` gives it the shared command
line. See [cpus/risc16/main.fn](cpus/risc16/main.fn), about 170 lines.

## Layout

| Path                        | What it holds                                |
| --------------------------- | -------------------------------------------- |
| `assemulator/lexer.fn`      | tokens, numbers, strings                     |
| `assemulator/expression.fn` | expression evaluation on 64-bit words        |
| `assemulator/symbols.fn`    | labels, local scopes, include namespaces     |
| `assemulator/assembler.fn`  | the two passes, directives, macros           |
| `assemulator/ports.fn`      | the character and number ports               |
| `assemulator/run.fn`        | the command line, file loading, the stepping |
| `cpus/*/main.fn`            | one CPU each                                 |

## How it differs from the Rust version

- Faun is pure, so `step` returns the ports rather than printing, and port
  reads stall the CPU instead of blocking inside it.
- Faun's file access only reaches files beneath the working directory, so the
  emulator runs from the repo root (as the `just` recipes do), and includes
  like `../ports.asm` are resolved against the including file's path.
- A local label is looked up in its own scope, then in the scope before it.
- About 50 million emulated instructions a second, against the Rust version's
  300 million. `step` hands back the processor without keeping the old one, so
  each register write is made in place rather than copied.
- No bitmap screen or real-time buttons yet, as in the Rust version's plans.

## Faun

The flake builds Faun from the local faun-lang checkout's `main`, which carries
these changes from writing this:

- Programs of more than a few hundred functions failed to build with
  `` `exit!` requires Word, but its argument needs Natural ``: the walk that
  bounds numbers gave up after a fixed 32 rounds and forgot every bound.
- That build error now names who handed the number, and says when the walk
  gave up.
- `--symbols` keeps frame pointers on x86-64, so `perf record -g` shows call
  stacks.
- A step's result of about twenty machine words is returned flat instead of in
  a heap cell made and freed every step: 2.4 times as fast.
- Faun no longer has loops, and a name bound again shadows the one before to
  the end of its block. This repo was written with 21 loops and rewritten as
  recursion, folds and clauses, which came out 11% shorter and runs the same
  instructions; that comparison is in faun-lang's `notes/iteration.md`.

Once faun-lang's `main` is pushed, point the flake's `faun` input at
`github:benburk/faun-lang`.
