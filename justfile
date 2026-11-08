set dotenv-load
set lazy

# Display available recipes
default:
    just --list --unsorted

alias fmt := format

# Format the code and docs
format:
    just --fmt
    dprint fmt
    fd -e nix -X nixfmt
    # The trailing `.` is required: with no path, ripgrep reads stdin when
    # stdin is not a TTY and blocks forever instead of searching the tree.
    rg -l '[^\n]\z' --multiline . | xargs -r sed -i -e '$a\\'

# Check formatting and that every processor compiles, without changing files
check:
    just --fmt --check
    dprint check
    @fd -e md --hidden -E .git -X awk '/^[[:space:]]*[|]/ && length($0) > 80 {print FILENAME ":" FNR ": table row is " length($0) " chars (>80)"; bad=1} END {exit bad}'
    fd -e nix -X nixfmt --check
    ! rg -l '[^\n]\z' --multiline .
    fd main.fn cpus -x faun check

# Build each processor's assembler and emulator into build/
build:
    mkdir -p build
    fd main.fn cpus -x sh -c 'faun build -o build/$(basename {//}) {}'

# Run the library's expectations, then every example program
test: expectations examples

# Check every `expect` in the assemulator library
expectations:
    faun test assemulator/assemulator.fn

# Run every finished example program, checking the output of those with a .out file
examples: build
    #!/usr/bin/env bash
    set -euo pipefail
    root=$(pwd)
    status=0
    for program in $(fd -e asm -E wip -E ports.asm -E macros.asm . cpus | sort); do
        cpu=$(echo "$program" | cut -d/ -f2)
        expected="${program%.asm}.out"
        input="$root/${program%.asm}.in"
        [ -f "$input" ] || input=/dev/null
        if [ -f "$expected" ]; then
            ./build/$cpu run "$program" < "$input" | diff -u "$expected" - && echo "ok   $program" || { echo "FAIL $program"; status=1; }
        else
            ./build/$cpu assemble "$program" > /dev/null && echo "ok   $program" || { echo "FAIL $program"; status=1; }
        fi
    done
    exit $status

# Run a program on a processor, e.g. `just run photon cpus/photon/programs/hello_world.asm`
run cpu file *args: build
    ./build/{{ cpu }} run {{ file }} {{ args }}

# Print a program's assembled bytes, e.g. `just assemble risc16 cpus/risc16/programs/hello.asm`
assemble cpu file: build
    ./build/{{ cpu }} assemble {{ file }}
