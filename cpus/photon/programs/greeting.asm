        .include "ports.asm"

; A library included under a name: its labels are read as `name::label`
; from outside, so they cannot collide with the including file's own.

greet:  .strz "Hello from the library\n"

; Prints a null-terminated string
; arg a: pointer to string
; clobbers b
print:
        jmp .start
.loop:  pst b, char     ; print char
.start: pop b, a        ; load char
        bt b, .loop     ; loop while char != 0
        ret
