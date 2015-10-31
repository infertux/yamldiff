; Diff two YAML files based on their keys

; yamldiff
; Copyright (C) 2015 Cédric Félizard
;
; GPLv3+ License
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.

BITS 64 ; make sure we assemble in 64-bit mode

; from /usr/include/asm/unistd_64.h
SYS_READ  equ 0
SYS_WRITE equ 1
SYS_OPEN  equ 2
SYS_CLOSE equ 3
SYS_EXIT  equ 60

; from /usr/include/asm-generic/fcntl.h
O_RDONLY  equ 0

; for syscall arguments, `man 2` is your friend

; other constants
STDIN     equ 0
STDOUT    equ 1
STDERR    equ 2

LF               equ 10
FILENAME_MAX_LEN equ 256 ; assume filenames aren't over 256 byte long
KEY_MAX_LEN      equ 256 ; assume YAML keys aren't over 256 byte long

%macro exit 1 ; void : exit_code
    mov di, %1
    mov rax, SYS_EXIT
    syscall ; THE END
%endmacro

%macro debug 1 ; void : addr
    mov rsi, %1
    add [rsi], dword '0' ; convert to ASCII

    mov rax, SYS_WRITE
    mov rdi, STDERR
    mov rdx, 1
    syscall

    exit 42
%endmacro

%macro fgetc 0 ; defined as a macro to avoid code duplication
    push rdx
    push rcx

    mov rax, SYS_READ
    mov rdx, 1
    syscall

    pop rcx
    pop rdx

    test rax, rax
    jz .read_key_eof
    js .read_key_err

    cmp [rsi], byte LF
%endmacro

section .data
    help_msg:  db ' <filename1> <filename2>', LF, LF
               db 'Diff two YAML files based on their keys', 0

section .bss
    tmp_1    resb 1
    tmp_8    resq 1
    f1_name  resb FILENAME_MAX_LEN
    f2_name  resb FILENAME_MAX_LEN
    f1_fd    resq 1 ; assume FD isn't over 64 bit long
    f2_fd    resq 1
    f1_key   resb KEY_MAX_LEN
    f2_key   resb KEY_MAX_LEN

section .text
    global _start

_start:
.check_argc:
    pop rax
    cmp rax, 2+1 ; expect 2 arguments (+1 for argv[0])
    pop rax ; pop argv[0]
    jne help

.store_filenames:
    pop rax
    mov [f1_name], rax

    pop rax
    mov [f2_name], rax

    xor ax, ax
    push ax ; set exit status to zero

.open_files:
    mov rdi, [f1_name]
    call fopen
    mov [f1_fd], rax

    mov rdi, [f2_name]
    call fopen
    mov [f2_fd], rax

.read_keys:
    mov rdi, [f1_fd]
    mov rsi, tmp_1
    mov rdx, f1_key
    call .read_key

    mov rdi, [f2_fd]
    mov rsi, tmp_1
    mov rdx, f2_key
    call .read_key

.diff_keys:
    mov al, [f1_key]
    or al, [f2_key]
    jz .close_files ; if both keys are null, we've hit EOF on both files
    mov edi, f1_key
    mov esi, f2_key
    mov ecx, KEY_MAX_LEN
    repe cmpsb
    jecxz .read_keys ; jump back if keys are identical

.inc_diff_counter:
    pop ax
    inc ax ; inc exit status
    push ax

    cmp ax, 1
    jnz .diff_f1_key ; don't print filenames if already done

.print_filenames:
    mov [tmp_8], dword '--- '
    mov rdi, tmp_8
    call print

    mov rdi, [f1_name]
    call print.n

    mov [tmp_8], dword '+++ '
    mov rdi, tmp_8
    call print

    mov rdi, [f2_name]
    call print.n

.diff_f1_key:
    cmp [f1_key], byte 0
    jz .diff_f2_key ; don't print key if null

    mov [tmp_1], word '-'
    mov rdi, tmp_1
    call print
    mov rdi, f1_key
    call print.n

.diff_f2_key:
    cmp [f2_key], byte 0
    jz .read_keys ; don't print key if null

    mov [tmp_1], word '+'
    mov rdi, tmp_1
    call print
    mov rdi, f2_key
    call print.n

    jmp .read_keys

.read_key: ; void : rdi = FD, rsi = buffer, rdx = key
    mov rcx, KEY_MAX_LEN
.read_key_clear:
    mov [rdx+rcx-1], byte 0
    dec rcx
    jnz .read_key_clear
.read_key_scan:
    fgetc
    je .read_key ; reset rcx and restart scan if EOL

    mov al, byte[rsi]
    mov [rdx+rcx], al ; copy key in buffer
    inc rcx

    cmp [rsi], byte ':' ; end of key?
    jne .read_key_scan

    mov [rdx+rcx-1], byte 0 ; set last byte to NULL

.read_key_until_eol:
    ; seek forward until EOL or EOF in case there's another colon on this line
    fgetc
    jne .read_key_until_eol
    ret

.read_key_eof:
    mov [rdx], byte 0
    ret

.read_key_err:
    exit ax

.close_files:
    mov rdi, [f1_fd]
    call fclose

    mov rdi, [f2_fd]
    call fclose

    pop ax
    exit ax

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Secondary routines below:

help:
    mov rdi, rax
    call print
    mov rdi, help_msg
    call print.n
    exit 1

fclose: ; void : rdi
    mov rax, SYS_CLOSE
    syscall

    test rax, rax
    jnz .err
    ret
.err:
    exit ax

fopen: ; rax : rdi
    mov rax, SYS_OPEN
    mov rsi, O_RDONLY
    syscall

    ; check we got a valid (>= 0) FD (typically > 2 = STDERR)
    test rax, rax
    js .err
    ret
.err:
    exit ax

; like `print` but prints an extra \n
print.n: ; void : rdi
    std ; direction flag won't be overriden by strlen code below

print: ; void : rdi
    ; no BOF check - make sure your string is zero terminated
    mov rdx, -1
.strlen:
    inc rdx
    cmp [rdi+rdx], byte 0
    jne .strlen

    mov rax, SYS_WRITE
    mov rsi, rdi
    mov rdi, STDOUT
    syscall

    ; get direction flag
    pushf
    pop ax
    push ax
    popf
    and ax, 0x400 ; DF is bit 10
    jz .ret

    mov rax, SYS_WRITE
    mov rdi, STDOUT
    mov [tmp_1], byte LF
    mov rsi, tmp_1
    mov rdx, 1
    syscall

.ret:
    cld
    ret

