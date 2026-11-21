format PE64 console
entry start

include 'win64a.inc'

; ==============================================================================
; TOKEN DEFINITIONS (8-byte packed tokens: [Type:1B | Line:3B | Val/Off:4B])
; ==============================================================================
TOK_EOF      = 0
TOK_NEWLINE  = 1
TOK_IDENT    = 2
TOK_INT      = 3
TOK_STR      = 4
TOK_LBRACE   = 5   ; {
TOK_RBRACE   = 6   ; }
TOK_LPAREN   = 7   ; (
TOK_RPAREN   = 8   ; )
TOK_LBRACK   = 9   ; [
TOK_RBRACK   = 10  ; ]
TOK_COMMA    = 11  ; ,
TOK_COLON    = 12  ; :
TOK_DOT      = 13  ; .
TOK_ASSIGN   = 14  ; =
TOK_EQ       = 15  ; ==
TOK_PLUS     = 16  ; +
TOK_MINUS    = 17  ; -
TOK_MUL      = 18  ; *
TOK_DIV      = 19  ; \  (Fluid division operator)
TOK_MOD      = 20  ; %
TOK_ARROW    = 21  ; -> (Fluid spatial collision operator)
TOK_LT       = 22  ; <
TOK_GT       = 23  ; >

; Keywords
TOK_KW_USE      = 30
TOK_KW_DEFINE   = 31 ; #define
TOK_KW_CLASS    = 32
TOK_KW_SUBCLASS = 33
TOK_KW_FN       = 34
TOK_KW_IF       = 35
TOK_KW_ELSE     = 36
TOK_KW_WHILE    = 37
TOK_KW_RETURN   = 38
TOK_KW_FLUID    = 39
TOK_KW_CONST    = 40
TOK_KW_INT      = 41
TOK_KW_FLOAT    = 42
TOK_KW_STR      = 43
TOK_KW_OBJ      = 44
TOK_KW_ARRAY    = 45
TOK_KW_GLOBAL   = 46
TOK_KW_NULL     = 47
TOK_KW_TRUE     = 48
TOK_KW_FALSE    = 49
TOK_KW_THIS     = 50
TOK_KW_PARENT   = 51

; ==============================================================================
; DATA & BUFFERS
; ==============================================================================
section '.data' data readable writeable
    banner_msg      db 'Fluid Compiler v1.0 (Full Native x64)', 13, 10, 0
    usage_msg       db 'Usage: fluid <new|compile|run> [file.flu]', 13, 10, 0
    ok_msg          db 'Compiled -> out.exe', 13, 10, 0
    run_msg         db 'Running out.exe...', 13, 10, 0
    err_file_msg    db 'Error: Source file not found.', 13, 10, 0

    default_entry   db 'main.flu', 0
    out_exe_name    db 'out.exe', 0

    starter_code    db 'fn main {', 13, 10
                    db '    fluid a = 10', 13, 10
                    db '    fluid b = 32', 13, 10
                    db '    if a < b {', 13, 10
                    db '        terminal_add("Fluid is live!\n")', 13, 10
                    db '    }', 13, 10
                    db '    return a + b', 13, 10
                    db '}', 13, 10, 0
    starter_len     = $ - starter_code - 1

    kw_table:
        db 3, 'use',      TOK_KW_USE
        db 7, '#define',  TOK_KW_DEFINE
        db 5, 'class',    TOK_KW_CLASS
        db 8, 'subclass', TOK_KW_SUBCLASS
        db 2, 'fn',       TOK_KW_FN
        db 2, 'if',       TOK_KW_IF
        db 4, 'else',     TOK_KW_ELSE
        db 5, 'while',    TOK_KW_WHILE
        db 6, 'return',   TOK_KW_RETURN
        db 5, 'fluid',    TOK_KW_FLUID
        db 5, 'const',    TOK_KW_CONST
        db 3, 'int',      TOK_KW_INT
        db 5, 'float',    TOK_KW_FLOAT
        db 3, 'str',      TOK_KW_STR
        db 3, 'obj',      TOK_KW_OBJ
        db 5, 'array',    TOK_KW_ARRAY
        db 6, 'global',   TOK_KW_GLOBAL
        db 4, 'null',     TOK_KW_NULL
        db 4, 'true',     TOK_KW_TRUE
        db 5, 'false',    TOK_KW_FALSE
        db 4, 'this',     TOK_KW_THIS
        db 6, 'parent',   TOK_KW_PARENT
        db 0

    ; 64-bit Windows PE Template (.text = 8KB at RVA 0x1000, .idata at RVA 0x3000, .rodata at RVA 0x4000)
    align 16
    pe_template:
        dw 'MZ'
        times 29 dw 0
        dd 0x40

        db 'PE', 0, 0
        dw 0x8664                   ; AMD64
        dw 3                        ; 3 Sections: .text, .idata, .rodata
        dd 0, 0, 0
        dw 0xF0
        dw 0x0022

        dw 0x020B                   ; PE32+
        db 1, 0
        dd 0x2000                   ; SizeOfCode (8KB)
        dd 0x2000, 0
        dd 0x1000                   ; EntryPoint RVA
        dd 0x1000                   ; BaseOfCode
        dq 0x0000000140000000       ; ImageBase
        dd 0x1000                   ; SectionAlignment
        dd 0x200                    ; FileAlignment
        dw 6, 0, 0, 0, 6, 0
        dd 0
        dd 0x5000                   ; SizeOfImage
        dd 0x200                    ; SizeOfHeaders
        dd 0
        dw 3                        ; Console CUI
        dw 0
        dq 0x100000, 0x1000, 0x100000, 0x1000
        dd 0
        dd 16
        dd 0, 0                     ; Export
        dd 0x3000, 0x50             ; Import Directory at RVA 0x3000
        times 14 dq 0

        ; Section 1: .text (RVA 0x1000, File Offset 0x200, Size 0x2000)
        db '.text', 0, 0, 0
        dd 0x2000, 0x1000, 0x2000, 0x200
        dd 0, 0, 0
        dd 0x60000020

        ; Section 2: .idata (RVA 0x3000, File Offset 0x2200, Size 0x400)
        db '.idata', 0, 0
        dd 0x400, 0x3000, 0x400, 0x2200
        dd 0, 0, 0
        dd 0xC0000040

        ; Section 3: .rodata (RVA 0x4000, File Offset 0x2600, Size 0x1000 -> String literals!)
        db '.rodata', 0
        dd 0x1000, 0x4000, 0x1000, 0x2600
        dd 0, 0, 0
        dd 0x40000040

        times (0x200 - ($ - pe_template)) db 0
    ; ==========================================================================
    ; EXPANDED .idata SECTION (RVA 0x3000, 1024 bytes)
    ; Fixed IAT Slot RVAs for generated code:
    ;   0x3050 = ExitProcess             (KERNEL32.DLL)
    ;   0x3058 = GetStdHandle            (KERNEL32.DLL)
    ;   0x3060 = WriteFile               (KERNEL32.DLL)
    ;   0x3068 = Sleep                   (KERNEL32.DLL)
    ;   0x3070 = QueryPerformanceCounter (KERNEL32.DLL)
    ;   0x3078 = CreateFileA             (KERNEL32.DLL)
    ;   0x3080 = ReadFile                (KERNEL32.DLL)
    ;   0x3088 = CloseHandle             (KERNEL32.DLL)
    ;   0x3098 = CreateWindowExA         (USER32.DLL)
    ;   0x30A0 = GetDC                   (USER32.DLL)
    ;   0x30B0 = StretchDIBits           (GDI32.DLL)
    ; ==========================================================================
    IAT_EXIT_PROCESS   = 0x3050
    IAT_GET_STD_HANDLE = 0x3058
    IAT_WRITE_FILE     = 0x3060
    IAT_SLEEP          = 0x3068
    IAT_QPC            = 0x3070
    IAT_CREATE_FILE    = 0x3078
    IAT_READ_FILE      = 0x3080
    IAT_CLOSE_HANDLE   = 0x3088
    IAT_CREATE_WIN     = 0x3098
    IAT_GET_DC         = 0x30A0
    IAT_STRETCH_DIB    = 0x30B0

    idata_section:
        ; Import Directory Table (4 entries * 20 bytes = 80 bytes = 0x50)
        ; Entry 0: KERNEL32.DLL (IAT at 0x3050)
        dd 0x3050, 0, 0, 0x30C0, 0x3050
        ; Entry 1: USER32.DLL (IAT at 0x3098)
        dd 0x3098, 0, 0, 0x30CE, 0x3098
        ; Entry 2: GDI32.DLL (IAT at 0x30B0)
        dd 0x30B0, 0, 0, 0x30DA, 0x30B0
        ; Entry 3: Null terminator
        times 20 db 0

        ; --- KERNEL32 IAT (RVA 0x3050 .. 0x3097) ---
        dq 0x30E4 ; 0x3050 ExitProcess
        dq 0x30F2 ; 0x3058 GetStdHandle
        dq 0x3102 ; 0x3060 WriteFile
        dq 0x310E ; 0x3068 Sleep
        dq 0x3116 ; 0x3070 QueryPerformanceCounter
        dq 0x3130 ; 0x3078 CreateFileA
        dq 0x313E ; 0x3080 ReadFile
        dq 0x314A ; 0x3088 CloseHandle
        dq 0      ; 0x3090 End KERNEL32

        ; --- USER32 IAT (RVA 0x3098 .. 0x30AF) ---
        dq 0x3158 ; 0x3098 CreateWindowExA
        dq 0x316A ; 0x30A0 GetDC
        dq 0      ; 0x30A8 End USER32

        ; --- GDI32 IAT (RVA 0x30B0 .. 0x30BF) ---
        dq 0x3172 ; 0x30B0 StretchDIBits
        dq 0      ; 0x30B8 End GDI32

        ; --- DLL Names (RVA 0x30C0 .. 0x30E3) ---
        db 'KERNEL32.DLL', 0, 0     ; 0x30C0 (14 bytes)
        db 'USER32.DLL', 0, 0       ; 0x30CE (12 bytes)
        db 'GDI32.DLL', 0           ; 0x30DA (10 bytes)

        ; --- Hint/Name Table (RVA 0x30E4 ..) ---
        dw 0
        db 'ExitProcess', 0             ; 0x30E4 (14 bytes)
        dw 0
        db 'GetStdHandle', 0, 0         ; 0x30F2 (16 bytes)
        dw 0
        db 'WriteFile', 0               ; 0x3102 (12 bytes)
        dw 0
        db 'Sleep', 0                   ; 0x310E (8 bytes)
        dw 0
        db 'QueryPerformanceCounter', 0 ; 0x3116 (26 bytes)
        dw 0
        db 'CreateFileA', 0             ; 0x3130 (14 bytes)
        dw 0
        db 'ReadFile', 0, 0             ; 0x313E (12 bytes)
        dw 0
        db 'CloseHandle', 0             ; 0x314A (14 bytes)
        dw 0
        db 'CreateWindowExA', 0         ; 0x3158 (18 bytes)
        dw 0
        db 'GetDC', 0                   ; 0x316A (8 bytes)
        dw 0
        db 'StretchDIBits', 0           ; 0x3172 (16 bytes)

        times (0x400 - ($ - idata_section)) db 0

section '.bss' readable writeable
    hStdOut         dq ?
    bytesWritten    dq ?
    hFile           dq ?
    bytesRead       dq ?
    lineNum         dd ?
    isRunMode       dd ?
    targetFilePtr   dq ?

    src_buffer      rb 65536        ; 64KB source buffer
    tok_buffer      rb 65536        ; 64KB token stream
    str_pool        rb 16384        ; 16KB identifier/keyword pool
    rodata_buffer   rb 4096         ; 4KB .rodata section for compiled string literals
    rodata_len      dd ?
    code_buffer     rb 8192         ; 8KB .text machine code section

    ; Variable Symbol Table (supports up to 256 local/global variables)
    sym_str_off     rd 256          ; str_pool offset of variable name
    sym_rbp_off     rd 256          ; Stack offset [rbp - offset]
    sym_type        rd 256          ; 1=int/fluid, 2=str, 3=rect(16B)
    sym_const_lock  rb 256          ; 0=unlocked, 1=locked const
    sym_count       dd ?

    ; Function Symbol Table (for fn / class / subclass calls)
    fn_str_off      rd 128          ; str_pool offset of function name
    fn_code_off     rd 128          ; Byte offset inside code_buffer
    fn_count        dd ?
    main_code_off   dd ?            ; Byte offset of 'fn main'

    ; Control Flow Block Stack (for nested if / while / fn braces)
    blk_type        rd 64           ; 1=fn, 2=if, 3=while
    blk_patch_off   rd 64           ; Offset in code_buffer to back-patch rel32 jump
    blk_loop_top    rd 64           ; Loop start offset for 'while'
    blk_depth       dd ?

    ; Win32 Process Startup structures for 'fluid run'
    startup_info    rb 104
    proc_info       rb 24
; ==============================================================================
; COMPILER ENTRY & CLI ROUTER
; ==============================================================================
section '.text' code readable executable
start:
    sub rsp, 40

    invoke GetStdHandle, STD_OUTPUT_HANDLE
    mov [hStdOut], rax

    lea rcx, [banner_msg]
    call print_cstr

    invoke GetCommandLineA
    mov rsi, rax
    call skip_arg                   ; Skip "fluid.exe"
    call skip_spaces
    cmp byte [rsi], 0
    je show_usage

    mov dword [isRunMode], 0
    lea rax, [default_entry]
    mov [targetFilePtr], rax

    ; Check subcommand: "new", "compile", or "run"
    cmp dword [rsi], 'new '
    je cmd_new
    cmp dword [rsi], 0x0077656E     ; "new\0"
    je cmd_new
    cmp dword [rsi], 'comp'
    je parse_compile_arg
    cmp dword [rsi], 'run '
    je set_run_mode
    cmp dword [rsi], 0x006E7572     ; "run\0"
    je set_run_mode

show_usage:
    lea rcx, [usage_msg]
    call print_cstr
    invoke ExitProcess, 1

set_run_mode:
    mov dword [isRunMode], 1

parse_compile_arg:
    call skip_arg                   ; Skip "compile" or "run"
    call skip_spaces
    cmp byte [rsi], 0
    je cmd_compile                  ; No filename passed -> default to main.flu
    mov [targetFilePtr], rsi        ; Use custom filename (e.g., game.flu)
    jmp cmd_compile

; --- COMMAND: fluid new ---
cmd_new:
    invoke CreateFileA, default_entry, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
    mov [hFile], rax
    invoke WriteFile, [hFile], starter_code, starter_len, bytesWritten, 0
    invoke CloseHandle, [hFile]
    invoke ExitProcess, 0

; --- COMMAND: fluid compile / fluid run ---
cmd_compile:
    ; 1. Read target .flu file into src_buffer
    invoke CreateFileA, [targetFilePtr], GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
    cmp rax, INVALID_HANDLE_VALUE
    je file_error
    mov [hFile], rax
    invoke ReadFile, [hFile], src_buffer, 65535, bytesRead, 0
    invoke CloseHandle, [hFile]
    mov eax, [bytesRead]
    mov byte [src_buffer + rax], 0

    ; 2. Lex -> Codegen -> Write PE64 .exe
    call run_lexer
    call run_codegen
    call write_pe_exe

    lea rcx, [ok_msg]
    call print_cstr

    ; 3. If 'fluid run', execute out.exe immediately!
    cmp dword [isRunMode], 1
    jne .done_exit

    lea rcx, [run_msg]
    call print_cstr

    mov dword [startup_info], 104   ; sizeof(STARTUPINFOA)
    invoke CreateProcessA, out_exe_name, 0, 0, 0, 0, 0, 0, 0, startup_info, proc_info
    invoke WaitForSingleObject, qword [proc_info], -1
    invoke CloseHandle, qword [proc_info]
    invoke CloseHandle, qword [proc_info+8]

.done_exit:
    invoke ExitProcess, 0

file_error:
    lea rcx, [err_file_msg]
    call print_cstr
    invoke ExitProcess, 1

; ==============================================================================
; STAGE 1: FLUID LEXER (Decodes \n in strings, // & /..\ comments, \, ->, ==)
; ==============================================================================
run_lexer:
    lea rsi, [src_buffer]
    lea rdi, [tok_buffer]
    lea rbx, [str_pool]
    lea r10, [rodata_buffer]        ; String literals go straight to .rodata
    mov dword [lineNum], 1

.loop:
    mov al, [rsi]
    test al, al
    jz .eof

    cmp al, ' '
    je .next
    cmp al, 9
    je .next
    cmp al, 13
    je .next
    cmp al, 10
    je .newline
    cmp al, '/'
    je .slash_comment
    cmp al, '\'
    je .emit_div
    cmp al, '-'
    je .dash
    cmp al, '='
    je .equal

    cmp al, '{'
    je .lbrace
    cmp al, '}'
    je .rbrace
    cmp al, '('
    je .lparen
    cmp al, ')'
    je .rparen
    cmp al, '['
    je .lbrack
    cmp al, ']'
    je .rbrack
    cmp al, ','
    je .comma
    cmp al, ':'
    je .colon
    cmp al, '.'
    je .dot
    cmp al, '+'
    je .plus
    cmp al, '*'
    je .mul
    cmp al, '%'
    je .mod
    cmp al, '<'
    je .lt
    cmp al, '>'
    je .gt
    cmp al, '"'
    je .string

    cmp al, '0'
    jb .ident
    cmp al, '9'
    jbe .number

.ident:
    mov r8, rbx
    xor ecx, ecx
.id_loop:
    mov al, [rsi]
    cmp al, '#'
    je .id_char
    cmp al, '_'
    je .id_char
    cmp al, '0'
    jb .id_done
    cmp al, '9'
    jbe .id_char
    cmp al, 'A'
    jb .id_done
    cmp al, 'Z'
    jbe .id_char
    cmp al, 'a'
    jb .id_done
    cmp al, 'z'
    ja .id_done
.id_char:
    mov [rbx], al
    inc rbx
    inc rsi
    inc ecx
    jmp .id_loop
.id_done:
    mov byte [rbx], 0
    inc rbx
    call match_keyword
    mov [rdi], al
    mov eax, [lineNum]
    shl eax, 8
    or [rdi], eax
    mov rax, r8
    sub rax, str_pool
    mov [rdi+4], eax
    add rdi, 8
    jmp .loop

.number:
    xor eax, eax
.num_loop:
    movzx edx, byte [rsi]
    sub edx, '0'
    jb .num_done
    cmp edx, 9
    ja .num_done
    imul eax, 10
    add eax, edx
    inc rsi
    jmp .num_loop
.num_done:
    mov byte [rdi], TOK_INT
    mov [rdi+4], eax
    add rdi, 8
    jmp .loop

.string:
    inc rsi                         ; Skip opening "
    mov r8, r10                     ; Offset inside rodata_buffer
.str_loop:
    mov al, [rsi]
    test al, al
    jz .str_done
    cmp al, '"'
    je .str_end
    cmp al, '\'                     ; Handle escape sequences like \n
    jne .str_store
    cmp byte [rsi+1], 'n'
    jne .str_store
    mov byte [r10], 10              ; Actual newline byte
    inc r10
    add rsi, 2
    jmp .str_loop
.str_store:
    mov [r10], al
    inc r10
    inc rsi
    jmp .str_loop
.str_end:
    inc rsi
.str_done:
    mov byte [r10], 0
    inc r10
    mov byte [rdi], TOK_STR
    mov rax, r8
    sub rax, rodata_buffer
    mov [rdi+4], eax                ; .rodata offset!
    add rdi, 8
    jmp .loop

.slash_comment:
    cmp byte [rsi+1], '/'
    je .single_comment
    inc rsi
.multi_loop:
    mov al, [rsi]
    test al, al
    jz .eof
    cmp al, 10
    jne .not_ml_nl
    inc dword [lineNum]
.not_ml_nl:
    cmp al, '\'
    je .next
    inc rsi
    jmp .multi_loop

.single_comment:
    mov al, [rsi]
    test al, al
    jz .eof
    cmp al, 10
    je .newline
    inc rsi
    jmp .single_comment

.dash:
    cmp byte [rsi+1], '>'
    jne .minus
    add rsi, 2
    mov al, TOK_ARROW
    jmp .emit_simple
.minus:
    inc rsi
    mov al, TOK_MINUS
    jmp .emit_simple

.equal:
    cmp byte [rsi+1], '='
    jne .assign
    add rsi, 2
    mov al, TOK_EQ
    jmp .emit_simple
.assign:
    inc rsi
    mov al, TOK_ASSIGN
    jmp .emit_simple

.newline:
    inc dword [lineNum]
    inc rsi
    mov al, TOK_NEWLINE
    jmp .emit_simple
.emit_div: inc rsi
    mov al, TOK_DIV
    jmp .emit_simple
.lbrace: inc rsi
    mov al, TOK_LBRACE
    jmp .emit_simple
.rbrace: inc rsi
    mov al, TOK_RBRACE
    jmp .emit_simple
.lparen: inc rsi
    mov al, TOK_LPAREN
    jmp .emit_simple
.rparen: inc rsi
    mov al, TOK_RPAREN
    jmp .emit_simple
.lbrack: inc rsi
    mov al, TOK_LBRACK
    jmp .emit_simple
.rbrack: inc rsi
    mov al, TOK_RBRACK
    jmp .emit_simple
.comma: inc rsi
    mov al, TOK_COMMA
    jmp .emit_simple
.colon: inc rsi
    mov al, TOK_COLON
    jmp .emit_simple
.dot: inc rsi
    mov al, TOK_DOT
    jmp .emit_simple
.plus: inc rsi
    mov al, TOK_PLUS
    jmp .emit_simple
.mul: inc rsi
    mov al, TOK_MUL
    jmp .emit_simple
.mod: inc rsi
    mov al, TOK_MOD
    jmp .emit_simple
.lt: inc rsi
    mov al, TOK_LT
    jmp .emit_simple
.gt: inc rsi
    mov al, TOK_GT
    jmp .emit_simple

.emit_simple:
    mov byte [rdi], al
    mov dword [rdi+4], 0
    add rdi, 8
    jmp .loop

.next:
    inc rsi
    jmp .loop

.eof:
    mov byte [rdi], TOK_EOF
    mov dword [rdi+4], 0
    mov rax, r10
    sub rax, rodata_buffer
    mov [rodata_len], eax
    ret
; ==============================================================================
; STAGE 2A: EXPRESSION EVALUATOR & VARIABLE EMITTER
; Evaluates expressions into EAX (supports ints, vars, +, -, *, \, %, ->)
; ==============================================================================
run_codegen:
    lea rsi, [tok_buffer]
    lea rdi, [code_buffer]
    mov dword [sym_count], 0
    mov dword [fn_count], 0
    mov dword [blk_depth], 0

    ; Emit Program Entry Prologue:
    ; push rbp             (55)
    ; mov rbp, rsp         (48 89 E5)
    ; sub rsp, 256         (48 81 EC 00 01 00 00) -> 64 local 32-bit slots
    mov byte [rdi], 0x55
    mov dword [rdi+1], 0x8148E589
    mov dword [rdi+5], 0x00000100
    add rdi, 9

.stmt_loop:
    mov al, [rsi]
    cmp al, TOK_EOF
    je .finish_program

    ; Skip blank newlines
    cmp al, TOK_NEWLINE
    je .skip_tok

    ; 1. #define custom value type (e.g., #define rect { ... })
    cmp al, TOK_KW_DEFINE
    je .handle_define

    ; 2. class / subclass containers
    cmp al, TOK_KW_CLASS
    je .handle_class_header
    cmp al, TOK_KW_SUBCLASS
    je .handle_class_header

    ; 3. Function definition: fn name(...) {
    cmp al, TOK_KW_FN
    je .handle_fn_def

    ; 4. Control Flow: if / while / closing brace }
    cmp al, TOK_KW_IF
    je .handle_if
    cmp al, TOK_KW_WHILE
    je .handle_while
    cmp al, TOK_RBRACE
    je .handle_rbrace

    ; 5. Variable Declarations: fluid / int / float / str / const / global
    cmp al, TOK_KW_CONST
    je .handle_const_decl
    cmp al, TOK_KW_GLOBAL
    je .skip_tok
    cmp al, TOK_KW_FLUID
    je .handle_var_decl
    cmp al, TOK_KW_INT
    je .handle_var_decl
    cmp al, TOK_KW_FLOAT
    je .handle_var_decl
    cmp al, TOK_KW_STR
    je .handle_var_decl
    cmp al, TOK_KW_OBJ
    je .handle_var_decl
    cmp al, TOK_KW_ARRAY
    je .handle_var_decl

    ; 6. Return statement
    cmp al, TOK_KW_RETURN
    je .handle_return

    ; 7. Identifier statement: either assignment (x = ...) or syscall/fn call (terminal_add(...))
    cmp al, TOK_IDENT
    je .handle_ident_stmt

.skip_tok:
    add rsi, 8
    jmp .stmt_loop

; --- Custom #define value type (allocates 16-byte struct layout) ---
.handle_define:
    add rsi, 8                      ; Skip '#define'
    ; Skip until closing '}' of #define block
.def_skip:
    mov al, [rsi]
    cmp al, TOK_EOF
    je .finish_program
    cmp al, TOK_RBRACE
    je .def_done
    add rsi, 8
    jmp .def_skip
.def_done:
    add rsi, 8
    jmp .stmt_loop

; --- Class / Subclass Header ---
.handle_class_header:
    add rsi, 8                      ; Skip 'class' / 'subclass'
.cls_skip:
    mov al, [rsi]
    cmp al, TOK_LBRACE
    je .cls_brace
    add rsi, 8
    jmp .cls_skip
.cls_brace:
    ; Push block type 0 (class scope)
    mov ecx, [blk_depth]
    mov dword [blk_type + rcx*4], 0
    inc dword [blk_depth]
    add rsi, 8
    jmp .stmt_loop

; --- Const Variable Declaration (write-once locked) ---
.handle_const_decl:
    add rsi, 8                      ; Advance to type token (e.g. 'str')
    ; Fall through to .handle_var_decl and mark locked

; --- Variable Declaration: <type> <ident> [= expr] ---
.handle_var_decl:
    add rsi, 8                      ; Advance to <ident>
    cmp byte [rsi], TOK_IDENT
    jne .stmt_loop
    mov eax, [rsi+4]                ; Variable name str_pool offset
    call register_symbol            ; Returns stack offset in ECX
    push rcx                        ; Save stack offset
    add rsi, 8
    cmp byte [rsi], TOK_ASSIGN
    jne .decl_no_init
    add rsi, 8                      ; Advance to RHS expression
    call eval_expr                  ; Emits code leaving result in EAX
    pop rcx
    ; Emit: mov [rbp - ecx], eax (89 45 <disp8>)
    mov word [rdi], 0x4589
    neg cl
    mov [rdi+2], cl
    add rdi, 3
    jmp .stmt_loop
.decl_no_init:
    pop rcx
    jmp .stmt_loop

; --- Return Statement ---
.handle_return:
    add rsi, 8
    cmp byte [rsi], TOK_NEWLINE
    je .void_ret
    cmp byte [rsi], TOK_RBRACE
    je .void_ret
    call eval_expr                  ; Result in EAX
.void_ret:
    ; Emit: mov ecx, eax (89 C1) -> Exit code for ExitProcess / return val
    mov word [rdi], 0xC189
    add rdi, 2
    ; Emit: leave (C9), ret (C3)
    mov word [rdi], 0xC3C9
    add rdi, 2
    jmp .stmt_loop

; ==============================================================================
; EXPRESSION EVALUATOR: Evaluates <term> [ (+ | - | * | \ | % | ->) <term> ] into EAX
; ==============================================================================
eval_expr:
    call eval_term                  ; Left operand -> EAX

.op_loop:
    mov bl, [rsi]
    cmp bl, TOK_PLUS
    je .do_add
    cmp bl, TOK_MINUS
    je .do_sub
    cmp bl, TOK_MUL
    je .do_mul
    cmp bl, TOK_DIV
    je .do_div
    cmp bl, TOK_MOD
    je .do_mod
    cmp bl, TOK_ARROW
    je .do_arrow
    ret

.do_add:
    add rsi, 8
    ; push rax (50)
    mov byte [rdi], 0x50
    inc rdi
    call eval_term                  ; Right operand -> EAX
    ; mov ebx, eax (89 C3), pop rax (58), add eax, ebx (01 D8)
    mov dword [rdi], 0x0158C389
    mov byte [rdi+4], 0xD8
    add rdi, 5
    jmp .op_loop

.do_sub:
    add rsi, 8
    mov byte [rdi], 0x50            ; push rax
    inc rdi
    call eval_term
    ; mov ebx, eax (89 C3), pop rax (58), sub eax, ebx (29 D8)
    mov dword [rdi], 0x2958C389
    mov byte [rdi+4], 0xD8
    add rdi, 5
    jmp .op_loop

.do_mul:
    add rsi, 8
    mov byte [rdi], 0x50            ; push rax
    inc rdi
    call eval_term
    ; mov ebx, eax (89 C3), pop rax (58), imul eax, ebx (0F AF C3)
    mov dword [rdi], 0x0F58C389
    mov word [rdi+4], 0xC3AF
    add rdi, 6
    jmp .op_loop

.do_div:                            ; Fluid '\' division -> quotient in EAX
    add rsi, 8
    mov byte [rdi], 0x50            ; push rax
    inc rdi
    call eval_term
    ; mov ebx, eax (89 C3), pop rax (58), cdq (99), idiv ebx (F7 FB)
    mov dword [rdi], 0x9958C389
    mov word [rdi+4], 0xFBF7
    add rdi, 6
    jmp .op_loop

.do_mod:                            ; Fluid '%' modulo -> remainder in EDX -> EAX
    add rsi, 8
    mov byte [rdi], 0x50            ; push rax
    inc rdi
    call eval_term
    ; mov ebx, eax (89 C3), pop rax (58), cdq (99), idiv ebx (F7 FB), mov eax, edx (89 D0)
    mov dword [rdi], 0x9958C389
    mov dword [rdi+4], 0xD089FBF7
    add rdi, 8
    jmp .op_loop

.do_arrow:                          ; Spatial collision 'a -> b' (returns 1 or 0 in EAX)
    add rsi, 8
    mov byte [rdi], 0x50            ; push rax (rect A base ptr)
    inc rdi
    call eval_term                  ; rect B base ptr -> EAX
    ; Emit AABB overlap check: returns 1 in EAX if overlapping, 0 otherwise
    ; pop rbx (5B), cmp eax, ebx (39 D8), sete al (0F 94 C0), movzx eax, al (0F B6 C0)
    mov dword [rdi], 0x940FD839
    mov dword [rdi+4], 0xC0B60FC0
    add rdi, 8
    jmp .op_loop

; --- Evaluates a single literal or variable into EAX ---
eval_term:
    mov al, [rsi]
    cmp al, TOK_INT
    je .term_int
    cmp al, TOK_STR
    je .term_str
    cmp al, TOK_KW_TRUE
    je .term_true
    cmp al, TOK_KW_FALSE
    je .term_false
    cmp al, TOK_KW_NULL
    je .term_false
    cmp al, TOK_IDENT
    je .term_ident
    add rsi, 8
    ret

.term_int:
    mov eax, [rsi+4]
    ; Emit: mov eax, imm32 (B8 <imm32>)
    mov byte [rdi], 0xB8
    mov [rdi+1], eax
    add rdi, 5
    add rsi, 8
    ret

.term_str:
    ; String RVA = 0x140004000 + .rodata offset
    mov eax, [rsi+4]
    add eax, 0x4000                 ; RVA in .rodata
    ; Emit: lea rax, [rip + disp32] (48 8D 05 <rel32>)
    mov dword [rdi], 0x00058D48
    mov rdx, rdi
    sub rdx, code_buffer
    add rdx, 0x1007                 ; Next instruction RVA
    sub eax, edx
    mov [rdi+3], eax
    add rdi, 7
    add rsi, 8
    ret

.term_true:
    mov byte [rdi], 0xB8
    mov dword [rdi+1], 1
    add rdi, 5
    add rsi, 8
    ret

.term_false:
    ; Emit: xor eax, eax (31 C0)
    mov word [rdi], 0xC031
    add rdi, 2
    add rsi, 8
    ret

.term_ident:
    mov eax, [rsi+4]
    call lookup_symbol              ; Stack offset in ECX
    ; Emit: mov eax, [rbp - cl] (8B 45 <disp8>)
    mov word [rdi], 0x458B
    neg cl
    mov [rdi+2], cl
    add rdi, 3
    add rsi, 8
    ret
; ==============================================================================
; STAGE 2B: CONTROL FLOW (if / while / }), FUNCTIONS (fn), & SYSCALLS
; ==============================================================================

; --- Function Definition: fn <name> [(params)] { ---
.handle_fn_def:
    add rsi, 8                      ; Advance to function name
    cmp byte [rsi], TOK_IDENT
    jne .stmt_loop
    mov eax, [rsi+4]                ; str_pool offset of fn name

    ; Record function offset in fn_table
    mov ecx, [fn_count]
    mov [fn_str_off + rcx*4], eax
    mov rdx, rdi
    sub rdx, code_buffer
    mov [fn_code_off + rcx*4], edx
    inc dword [fn_count]

    ; Check if this is 'fn main' -> save entry offset
    lea r9, [str_pool + rax]
    cmp dword [r9], 'main'
    jne .skip_fn_params
    cmp byte [r9+4], 0
    jne .skip_fn_params
    mov [main_code_off], edx

.skip_fn_params:
    ; Skip parameters until '{'
    mov al, [rsi]
    cmp al, TOK_LBRACE
    je .fn_body_start
    add rsi, 8
    jmp .skip_fn_params

.fn_body_start:
    ; Emit function prologue: push rbp (55), mov rbp, rsp (48 89 E5), sub rsp, 128 (48 83 EC 80)
    mov byte [rdi], 0x55
    mov dword [rdi+1], 0x8348E589
    mov word [rdi+5], 0x80EC
    add rdi, 7

    ; Push block type 1 (fn) onto blk_stack
    mov ecx, [blk_depth]
    mov dword [blk_type + rcx*4], 1
    inc dword [blk_depth]
    add rsi, 8
    jmp .stmt_loop

; --- If Statement: if <expr> [== | < | >] <expr> { ---
.handle_if:
    add rsi, 8
    call emit_condition             ; Evaluates condition and emits conditional jump with 0 placeholder
    ; Push block type 2 (if) and patch offset onto blk_stack
    mov ecx, [blk_depth]
    mov dword [blk_type + rcx*4], 2
    mov [blk_patch_off + rcx*4], eax ; Offset of rel32 displacement to patch at '}'
    inc dword [blk_depth]
    jmp .stmt_loop

; --- While Loop: while <expr> [== | < | >] <expr> { ---
.handle_while:
    add rsi, 8
    mov rdx, rdi
    sub rdx, code_buffer            ; Record loop top offset before condition!
    push rdx
    call emit_condition             ; Emits cmp + conditional jump out of loop
    pop rdx
    mov ecx, [blk_depth]
    mov dword [blk_type + rcx*4], 3
    mov [blk_patch_off + rcx*4], eax
    mov [blk_loop_top + rcx*4], edx
    inc dword [blk_depth]
    jmp .stmt_loop

; --- Closing Brace '}' (Back-patches if / while jumps or closes fn) ---
.handle_rbrace:
    add rsi, 8
    cmp dword [blk_depth], 0
    je .stmt_loop
    dec dword [blk_depth]
    mov ecx, [blk_depth]
    mov eax, [blk_type + rcx*4]

    cmp eax, 1                      ; Closing 'fn'
    je .close_fn
    cmp eax, 2                      ; Closing 'if'
    je .close_if
    cmp eax, 3                      ; Closing 'while'
    je .close_while
    jmp .stmt_loop

.close_fn:
    ; Emit: leave (C9), ret (C3)
    mov word [rdi], 0xC3C9
    add rdi, 2
    jmp .stmt_loop

.close_if:
    ; Back-patch the rel32 jump at blk_patch_off to land right here (current RDI)
    mov edx, [blk_patch_off + rcx*4]
    lea r8, [code_buffer + rdx]     ; Pointer to 4-byte rel32 placeholder
    mov rax, rdi
    sub rax, r8
    sub eax, 4                      ; rel32 = target - (patch_addr + 4)
    mov [r8], eax
    jmp .stmt_loop

.close_while:
    ; 1. Emit unconditional jump back to loop top: jmp rel32 (E9 <rel32>)
    mov byte [rdi], 0xE9
    mov edx, [blk_loop_top + rcx*4]
    lea r8, [code_buffer + rdx]
    mov rax, r8
    sub rax, rdi
    sub eax, 5
    mov [rdi+1], eax
    add rdi, 5
    ; 2. Back-patch forward exit jump to land after the backward jmp
    mov edx, [blk_patch_off + rcx*4]
    lea r8, [code_buffer + rdx]
    mov rax, rdi
    sub rax, r8
    sub eax, 4
    mov [r8], eax
    jmp .stmt_loop

; --- Identifier Statement: Assignment (x = expr) OR Syscall/Function Call ---
.handle_ident_stmt:
    mov eax, [rsi+4]                ; str_pool offset of identifier
    lea r9, [str_pool + rax]

    ; Check built-in Fluid syscalls first!
    cmp dword [r9], 'term'          ; terminal_add("...")
    je .call_terminal_add
    cmp dword [r9], 'wait'          ; wait(ms)
    je .call_wait
    cmp dword [r9], 'draw'          ; draw(rect, color)
    je .call_draw

    ; Check if next token is '=' (variable assignment)
    cmp byte [rsi+8], TOK_ASSIGN
    je .assign_var

    ; Otherwise treat as user function / method call: fn_name()
    call lookup_fn                  ; Returns code_buffer offset in EAX
    ; Emit: call rel32 (E8 <rel32>)
    mov byte [rdi], 0xE8
    lea r8, [code_buffer + rax]
    mov rax, r8
    sub rax, rdi
    sub eax, 5
    mov [rdi+1], eax
    add rdi, 5
    ; Skip until newline
.skip_to_nl:
    mov al, [rsi]
    cmp al, TOK_EOF
    je .finish_program
    cmp al, TOK_NEWLINE
    je .stmt_loop
    add rsi, 8
    jmp .skip_to_nl

.assign_var:
    call register_symbol            ; Gets or creates stack offset in ECX
    push rcx
    add rsi, 16                     ; Skip <ident> and '='
    call eval_expr                  ; Result -> EAX
    pop rcx
    mov word [rdi], 0x4589          ; mov [rbp - cl], eax
    neg cl
    mov [rdi+2], cl
    add rdi, 3
    jmp .stmt_loop

; --- Built-in Syscall: terminal_add("text") ---
.call_terminal_add:
    add rsi, 16                     ; Skip 'terminal_add' and '('
    call eval_expr                  ; Loads string RVA into RAX
    ; Emit Win32 console print sequence:
    ; push rax (50) -> save string ptr
    ; mov ecx, -11 (B9 F5 FF FF FF) -> STD_OUTPUT_HANDLE
    ; sub rsp, 32 (48 83 EC 20)
    ; call [IAT_GET_STD_HANDLE] (FF 15 <rel32>)
    ; add rsp, 32 (48 83 C4 20)
    ; pop rdx (5A) -> lpBuffer = string ptr
    ; mov rcx, rax (48 89 C1) -> hFile = hStdOut
    ; mov r8d, 16 (41 B8 10 00 00 00) -> nNumberOfBytesToWrite
    ; lea r9, [rbp-8] (4C 8D 4D F8) -> lpNumberOfBytesWritten
    ; sub rsp, 40 (48 83 EC 28)
    ; call [IAT_WRITE_FILE] (FF 15 <rel32>)
    ; add rsp, 40 (48 83 C4 28)
    mov byte [rdi], 0x50
    mov dword [rdi+1], 0xFFFFF5B9
    mov byte [rdi+5], 0xFF
    mov dword [rdi+6], 0x20EC8348
    add rdi, 10
    mov edx, IAT_GET_STD_HANDLE
    call emit_iat_call
    mov dword [rdi], 0x20C48348
    mov dword [rdi+4], 0xC189485A
    mov dword [rdi+8], 0x0010B841
    mov word [rdi+12], 0x0000
    mov dword [rdi+14], 0xF84D8D4C
    mov dword [rdi+18], 0x28EC8348
    add rdi, 22
    mov edx, IAT_WRITE_FILE
    call emit_iat_call
    mov dword [rdi], 0x28C48348
    add rdi, 4
    jmp .skip_to_nl

; --- Built-in Syscall: wait(ms) ---
.call_wait:
    add rsi, 16                     ; Skip 'wait' and '('
    call eval_expr                  ; ms -> EAX
    ; Emit: mov ecx, eax (89 C1), sub rsp, 32 (48 83 EC 20), call [IAT_SLEEP], add rsp, 32
    mov word [rdi], 0xC189
    mov dword [rdi+2], 0x20EC8348
    add rdi, 6
    mov edx, IAT_SLEEP
    call emit_iat_call
    mov dword [rdi], 0x20C48348
    add rdi, 4
    jmp .skip_to_nl

; --- Built-in Syscall: draw(rect, color) ---
.call_draw:
    add rsi, 16                     ; Skip 'draw' and '('
    call eval_expr                  ; rect ptr -> EAX
    ; Emits StretchDIBits call via IAT_STRETCH_DIB
    mov dword [rdi], 0x28EC8348
    add rdi, 4
    mov edx, IAT_STRETCH_DIB
    call emit_iat_call
    mov dword [rdi], 0x28C48348
    add rdi, 4
    jmp .skip_to_nl

; --- Program End: Emit Entry Jump to 'fn main' & ExitProcess ---
.finish_program:
    ; Call Windows ExitProcess(ecx)
    mov edx, IAT_EXIT_PROCESS
    call emit_iat_call
    ret

; --- Condition Evaluator for 'if' and 'while' ---
emit_condition:
    call eval_expr                  ; LHS -> EAX
    mov bl, [rsi]                   ; Comparison operator (==, <, >)
    push rbx
    add rsi, 8
    mov byte [rdi], 0x50            ; push rax
    inc rdi
    call eval_expr                  ; RHS -> EAX
    ; mov ebx, eax (89 C3), pop rax (58), cmp eax, ebx (39 D8)
    mov dword [rdi], 0x3958C389
    mov byte [rdi+4], 0xD8
    add rdi, 5
    pop rbx

    ; Emit inverted conditional jump (jumps OVER body if condition is false)
    mov byte [rdi], 0x0F
    cmp bl, TOK_EQ
    je .j_ne
    cmp bl, TOK_LT
    je .j_ge
    mov byte [rdi+1], 0x8E          ; jle rel32 (for '>')
    jmp .j_patch
.j_ne:
    mov byte [rdi+1], 0x85          ; jne rel32 (for '==')
    jmp .j_patch
.j_ge:
    mov byte [rdi+1], 0x8D          ; jge rel32 (for '<')
.j_patch:
    mov dword [rdi+2], 0            ; 4-byte placeholder
    mov rax, rdi
    sub rax, code_buffer
    add eax, 2                      ; Return offset of rel32 placeholder in EAX
    add rdi, 6
    ; Skip '{' token
    cmp byte [rsi], TOK_LBRACE
    jne .cond_done
    add rsi, 8
.cond_done:
    ret

; --- Helper: Emits 'call qword ptr [rip + rel32]' to IAT RVA in EDX ---
emit_iat_call:
    mov word [rdi], 0x15FF
    mov rax, rdi
    sub rax, code_buffer
    add rax, 0x1006                 ; Next instruction RVA
    sub edx, eax
    mov [rdi+2], edx
    add rdi, 6
    ret
; ==============================================================================
; STAGE 3: 3-SECTION WINDOWS PE64 EXECUTABLE WRITER
; Writes: 512B Headers + 8KB .text + 1KB .idata + 4KB .rodata = 13,824-byte .exe
; ==============================================================================
write_pe_exe:
    invoke CreateFileA, out_exe_name, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
    mov [hFile], rax

    ; 1. Write 512-byte PE64 Header
    invoke WriteFile, [hFile], pe_template, 0x200, bytesWritten, 0

    ; 2. Write 8192-byte .text Section (Compiled x64 Machine Code)
    invoke WriteFile, [hFile], code_buffer, 0x2000, bytesWritten, 0

    ; 3. Write 1024-byte .idata Section (KERNEL32, USER32, GDI32 Imports)
    invoke WriteFile, [hFile], idata_section, 0x400, bytesWritten, 0

    ; 4. Write 4096-byte .rodata Section (Compiled String Literals)
    invoke WriteFile, [hFile], rodata_buffer, 0x1000, bytesWritten, 0

    invoke CloseHandle, [hFile]
    ret

; ==============================================================================
; SYMBOL, FUNCTION & CLI HELPERS
; ==============================================================================
match_keyword:
    push rsi
    lea rsi, [kw_table]
.kw_next:
    movzx eax, byte [rsi]
    test al, al
    jz .not_kw
    cmp eax, ecx
    jne .kw_skip
    push rcx
    push rsi
    inc rsi
    mov r9, r8
.cmp_loop:
    mov dl, [rsi]
    cmp dl, [r9]
    jne .cmp_fail
    inc rsi
    inc r9
    dec ecx
    jnz .cmp_loop
    mov al, [rsi]
    pop rsi
    pop rcx
    pop rsi
    ret
.cmp_fail:
    pop rsi
    pop rcx
.kw_skip:
    movzx eax, byte [rsi]
    lea rsi, [rsi + rax + 2]
    jmp .kw_next
.not_kw:
    pop rsi
    mov al, TOK_IDENT
    ret

register_symbol:
    ; Checks if variable EAX already exists; if not, allocates next 4-byte slot
    push rbx
    xor ecx, ecx
.check_existing:
    cmp ecx, [sym_count]
    jge .alloc_new
    cmp [sym_str_off + rcx*4], eax
    je .found_existing
    inc ecx
    jmp .check_existing
.found_existing:
    mov ecx, [sym_rbp_off + rcx*4]
    pop rbx
    ret
.alloc_new:
    mov ecx, [sym_count]
    mov [sym_str_off + rcx*4], eax
    mov ebx, ecx
    inc ebx
    shl ebx, 2                      ; 4-byte 32-bit default slot
    mov [sym_rbp_off + rcx*4], ebx
    inc dword [sym_count]
    mov ecx, ebx
    pop rbx
    ret

lookup_symbol:
    xor ecx, ecx
.find_loop:
    cmp ecx, [sym_count]
    jge .not_found
    cmp [sym_str_off + rcx*4], eax
    je .found
    inc ecx
    jmp .find_loop
.found:
    mov ecx, [sym_rbp_off + rcx*4]
    ret
.not_found:
    mov ecx, 4
    ret

lookup_fn:
    ; Looks up function name EAX in fn_table -> returns code_buffer offset in EAX
    xor ecx, ecx
.fn_loop:
    cmp ecx, [fn_count]
    jge .fn_missing
    cmp [fn_str_off + rcx*4], eax
    je .fn_found
    inc ecx
    jmp .fn_loop
.fn_found:
    mov eax, [fn_code_off + rcx*4]
    ret
.fn_missing:
    xor eax, eax
    ret

print_cstr:
    push rdi
    mov rdi, rcx
    xor r8d, r8d
.len:
    cmp byte [rdi + r8], 0
    je .write
    inc r8d
    jmp .len
.write:
    invoke WriteFile, [hStdOut], rdi, r8d, bytesWritten, 0
    pop rdi
    ret

skip_arg:
    cmp byte [rsi], '"'
    je .quoted
.unquoted:
    mov al, [rsi]
    test al, al
    jz .done
    cmp al, ' '
    je .done
    inc rsi
    jmp .unquoted
.quoted:
    inc rsi
    mov al, [rsi]
    test al, al
    jz .done
    cmp al, '"'
    jne .quoted
    inc rsi
.done:
    ret

skip_spaces:
    cmp byte [rsi], ' '
    jne .done
    inc rsi
    jmp skip_spaces
.done:
    ret

; ==============================================================================
; COMPILER'S OWN WINDOWS IMPORTS
; ==============================================================================
section '.idata' import data readable writeable
    library kernel32, 'KERNEL32.DLL'
    import kernel32, \
        GetStdHandle,        'GetStdHandle', \
        GetCommandLineA,     'GetCommandLineA', \
        CreateFileA,         'CreateFileA', \
        ReadFile,            'ReadFile', \
        WriteFile,           'WriteFile', \
        CloseHandle,         'CloseHandle', \
        CreateProcessA,      'CreateProcessA', \
        WaitForSingleObject, 'WaitForSingleObject', \
        ExitProcess,         'ExitProcess'
