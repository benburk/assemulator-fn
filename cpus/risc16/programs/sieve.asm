        .include "ports.asm"
        .include "macros.asm"

; Sieve of Eratosthenes: prints the primes below 128.
; RiSC-16 has no comparison, so `j < 128` asks whether j & 0xff80 is 0.
; r1: i
; r2: j, a multiple of i
; r3: scratch
; r4: the mask 0xff80
; r5: the end, 128

main:   MOVI r4, 0xff80
        MOVI r5, 128
        add r1, r0, 2           ; i = 2
.outer: beq r1, r5, .end
        lw r3, [sieve+r1]
        beq r3, r0, .prime      ; unmarked: a prime
        JMP .step
.prime: sw r1, [ticker]
        add r2, r1, r1          ; j = 2i
.inner: AND r3, r2, r4
        beq r3, r0, .mark       ; j < 128
        JMP .step
.mark:  sw r1, [sieve+r2]       ; anything but 0 marks j
        add r2, r1              ; j += i
        JMP .inner
.step:  add r1, 1
        JMP .outer
.end:

sieve:  .zero 256               ; 128 words, all unmarked
