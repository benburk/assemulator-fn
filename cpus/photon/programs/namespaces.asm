; Includes greeting.asm under `lib`, so its `greet` and this file's are two
; labels, and the labels after the include are this file's again.
lib:    .include "greeting.asm"

greet:  .strz "Hello from the program\n"

main:   mov a, lib::greet
        jsr lib::print
        mov a, greet
        jsr lib::print
