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
TOK_FLOAT    = 4   ; 32-bit IEEE-754 float literal
TOK_STR      = 5
TOK_CHAR     = 6   ; Single character literal (e.g., '<', 'a')
TOK_LBRACE   = 7   ; {
TOK_RBRACE   = 8   ; }
TOK_LPAREN   = 9   ; (
TOK_RPAREN   = 10  ; )
TOK_LBRACK   = 11  ; [
TOK_RBRACK   = 12  ; ]
TOK_COMMA    = 13  ; ,
TOK_COLON    = 14  ; :
TOK_DOT      = 15  ; .
TOK_ASSIGN   = 16  ; =
TOK_EQ       = 17  ; ==
TOK_PLUS     = 18  ; +
TOK_MINUS    = 19  ; -
TOK_MUL      = 20  ; *
TOK_DIV      = 21  ; \  (Fluid division operator)
TOK_MOD      = 22  ; %
TOK_ARROW    = 23  ; -> (Fluid spatial collision operator)
TOK_LT       = 24  ; <
TOK_GT       = 25  ; >

; Keywords
TOK_KW_USE      = 30
TOK_KW_DEFINE   = 31 ; #define (custom primitive value type constructor)
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
TOK_KW_CHR      = 44
TOK_KW_OBJ      = 45
TOK_KW_ARRAY    = 46
TOK_KW_GLOBAL   = 47
TOK_KW_NULL     = 48
TOK_KW_TRUE     = 49
TOK_KW_FALSE    = 50
TOK_KW_THIS     = 51
TOK_KW_PARENT   = 52

; Runtime Type Tags (stored at +16 in every 24-byte variable slot)
TYPE_NULL    = 0
TYPE_INT     = 1
TYPE_FLOAT   = 2
TYPE_STR     = 3
TYPE_CHR     = 4
TYPE_ARRAY   = 5
TYPE_CUSTOM  = 6   ; Custom #define primitive value type (e.g., rect)
TYPE_OBJ     = 7   ; Subtractive prototype instance (e.g., obj m = fish)
; ==============================================================================
; DATA & BUFFERS
; ==============================================================================
section '.data' data readable writeable
    banner_msg      db 'Fluid Compiler v3.2 (Full Native x64 - UOP Fast)', 13, 10, 0
    usage_msg       db 'Usage: fluid <new|compile|run> [file.flu]', 13, 10, 0
    ok_msg          db 'Compiled -> out.exe', 13, 10, 0
    run_msg         db 'Running out.exe...', 13, 10, 0
    err_file_msg    db 'Error: Source file not found.', 13, 10, 0
    err_const_msg   db 'Error: Cannot reassign const variable.', 13, 10, 0
    err_del_msg     db 'Error: Variable or class member was deleted.', 13, 10, 0
    err_dup_main    db 'Error: Class cannot define multiple main functions.', 13, 10, 0
    err_main_msg    db 'Error: Entry function fn main not found.', 13, 10, 0

    default_entry   db 'main.flu', 0
    out_exe_name    db 'out.exe', 0

    starter_code    db '#define rect{', 13, 10
                    db '    float,32:x', 13, 10
                    db '    float,32:y', 13, 10
                    db '    int,32:width', 13, 10
                    db '    int,32:height', 13, 10
                    db '}', 13, 10, 13, 10
                    db 'fn main {', 13, 10
                    db '    fluid x = 42', 13, 10
                    db '    if x == int {', 13, 10
                    db '        terminal_add("x is an int!\n")', 13, 10
                    db '    }', 13, 10
                    db '    x = null', 13, 10
                    db '    if x == null {', 13, 10
                    db '        terminal_add("x is now null!\n")', 13, 10
                    db '    }', 13, 10
                    db '    return 0', 13, 10
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
        db 3, 'chr',      TOK_KW_CHR
        db 3, 'obj',      TOK_KW_OBJ
        db 5, 'array',    TOK_KW_ARRAY
        db 6, 'global',   TOK_KW_GLOBAL
        db 4, 'null',     TOK_KW_NULL
        db 4, 'true',     TOK_KW_TRUE
        db 5, 'false',    TOK_KW_FALSE
        db 4, 'this',     TOK_KW_THIS
        db 6, 'parent',   TOK_KW_PARENT
        db 0
    ; 64-bit Windows PE Template (4 Sections):
    ;   .text   at RVA 0x1000 (16KB, File Offset 0x200)
    ;   .idata  at RVA 0x5000 (1KB,  File Offset 0x4200)
    ;   .rodata at RVA 0x6000 (4KB,  File Offset 0x4600)
    ;   .bss    at RVA 0x7000 (1.5MB virtual -> Globals, Heap Arena, Framebuffer)
    align 16
    pe_template:
        dw 'MZ'
        times 29 dw 0
        dd 0x40

        db 'PE', 0, 0
        dw 0x8664                   ; AMD64
        dw 4                        ; 4 Sections: .text, .idata, .rodata, .bss
        dd 0, 0, 0
        dw 0xF0
        dw 0x0022

        dw 0x020B                   ; PE32+
        db 1, 0
        dd 0x4000                   ; SizeOfCode (16KB)
        dd 0x1400, 0x180000
        dd 0x1000                   ; EntryPoint RVA
        dd 0x1000                   ; BaseOfCode
        dq 0x0000000140000000       ; ImageBase
        dd 0x1000                   ; SectionAlignment
        dd 0x200                    ; FileAlignment
        dw 6, 0, 0, 0, 6, 0
        dd 0
        dd 0x187000                 ; SizeOfImage (0x7000 + 0x180000)
        dd 0x200                    ; SizeOfHeaders
        dd 0
        dw 3                        ; Console CUI
        dw 0
        dq 0x100000, 0x1000, 0x100000, 0x1000
        dd 0
        dd 16
        dd 0, 0                     ; [0] Export
        dd 0x5000, 0x50             ; [1] Import Directory at RVA 0x5000
        times 10 dq 0               ; [2..11] Resource..BoundImport
        dd 0x50E0, 0xA0             ; [12] IAT Directory at RVA 0x50E0 (160 bytes)
        times 3 dq 0                ; [13..15] DelayImport, CLR, Reserved

        ; Section 1: .text (RVA 0x1000, File Offset 0x200, Size 0x4000)
        db '.text', 0, 0, 0
        dd 0x4000, 0x1000, 0x4000, 0x200
        dd 0, 0, 0
        dd 0x60000020

        ; Section 2: .idata (RVA 0x5000, File Offset 0x4200, Size 0x400)
        db '.idata', 0, 0
        dd 0x400, 0x5000, 0x400, 0x4200
        dd 0, 0, 0
        dd 0xC0000040

        ; Section 3: .rodata (RVA 0x6000, File Offset 0x4600, Size 0x1000)
        db '.rodata', 0
        dd 0x1000, 0x6000, 0x1000, 0x4600
        dd 0, 0, 0
        dd 0x40000040

        ; Section 4: .bss (RVA 0x7000, VirtualSize 0x180000, SizeOfRawData 0 -> Uninitialized RW)
        db '.bss', 0, 0, 0, 0
        dd 0x180000, 0x7000, 0, 0
        dd 0, 0, 0
        dd 0xC0000080

        times (0x200 - ($ - pe_template)) db 0
    ; ==========================================================================
    ; EXPANDED .idata SECTION (RVA 0x5000, 1024 bytes)
    ; Separated ILT (0x5050) and IAT (0x50E8) for strict PE32+ compliance
    ; Fixed IAT Slot RVAs for generated code:
    ;   0x50E8 = ExitProcess             (KERNEL32.DLL)
    ;   0x50F0 = GetStdHandle            (KERNEL32.DLL)
    ;   0x50F8 = WriteFile               (KERNEL32.DLL)
    ;   0x5100 = Sleep                   (KERNEL32.DLL)
    ;   0x5108 = QueryPerformanceCounter (KERNEL32.DLL)
    ;   0x5110 = CreateFileA             (KERNEL32.DLL)
    ;   0x5118 = ReadFile                (KERNEL32.DLL)
    ;   0x5120 = CloseHandle             (KERNEL32.DLL)
    ;   0x5128 = DeleteFileA             (KERNEL32.DLL)
    ;   0x5138 = CreateWindowExA         (USER32.DLL)
    ;   0x5140 = GetDC                   (USER32.DLL)
    ;   0x5148 = PeekMessageA            (USER32.DLL)
    ;   0x5150 = GetAsyncKeyState        (USER32.DLL)
    ;   0x5158 = GetCursorPos            (USER32.DLL)
    ;   0x5160 = ScreenToClient          (USER32.DLL)
    ;   0x5170 = StretchDIBits           (GDI32.DLL)
    ; ==========================================================================
    IAT_EXIT_PROCESS   = 0x50E8
    IAT_GET_STD_HANDLE = 0x50F0
    IAT_WRITE_FILE     = 0x50F8
    IAT_SLEEP          = 0x5100
    IAT_QPC            = 0x5108
    IAT_CREATE_FILE    = 0x5110
    IAT_READ_FILE      = 0x5118
    IAT_CLOSE_HANDLE   = 0x5120
    IAT_DELETE_FILE    = 0x5128
    IAT_CREATE_WIN     = 0x5138
    IAT_GET_DC         = 0x5140
    IAT_PEEK_MSG       = 0x5148
    IAT_GET_KEY_STATE  = 0x5150
    IAT_GET_CURSOR_POS = 0x5158
    IAT_SCREEN_CLIENT  = 0x5160
    IAT_STRETCH_DIB    = 0x5170

    ; Target Executable (.exe) .bss Virtual Memory Layout (RVA 0x7000 ..):
    BSS_HWND           = 0x7000
    BSS_HDC            = 0x7008
    BSS_WIN_W          = 0x7010
    BSS_WIN_H          = 0x7018
    BSS_BMI            = 0x7020
    BSS_MSG            = 0x7050
    BSS_HEAP_PTR       = 0x7080
    BSS_KEY_BUF        = 0x7088
    BSS_POINT          = 0x7090
    BSS_NUM_BUF        = 0x7098
    BSS_PATH_BUF       = 0x70C0
    BSS_GLOBALS        = 0x7200
    BSS_HEAP_ARENA     = 0x8A00
    BSS_FRAMEBUF       = 0x18A00

    ; Pre-seeded .rodata strings (RVA 0x6000 ..)
    RODATA_STATIC_CLS  = 0x6000     ; "STATIC\0"
    RODATA_WIN_TITLE   = 0x6008     ; "Fluid App\0"
    RODATA_SPACE       = 0x6014     ; " \0"
    RODATA_NEWLINE     = 0x6016     ; "\n\0"
    RODATA_USER_START  = 0x6018     ; User string literals begin here

    idata_section:
        ; Import Directory Table (4 entries * 20 bytes = 80 bytes = 0x50)
        dd 0x5050, 0, 0, 0x5180, 0x50E8 ; Entry 0: KERNEL32.DLL
        dd 0x50A0, 0, 0, 0x518E, 0x5138 ; Entry 1: USER32.DLL
        dd 0x50D8, 0, 0, 0x519A, 0x5170 ; Entry 2: GDI32.DLL
        times 20 db 0                   ; Entry 3: Null terminator

        ; --- Import Lookup Table (ILT: RVA 0x5050 .. 0x50E7) ---
        dq 0x51A4 ; ExitProcess
        dq 0x51B2 ; GetStdHandle
        dq 0x51C2 ; WriteFile
        dq 0x51CE ; Sleep
        dq 0x51D6 ; QueryPerformanceCounter
        dq 0x51F0 ; CreateFileA
        dq 0x51FE ; ReadFile
        dq 0x520A ; CloseHandle
        dq 0x5218 ; DeleteFileA
        dq 0      ; End KERNEL32 ILT

        dq 0x5226 ; CreateWindowExA
        dq 0x5238 ; GetDC
        dq 0x5240 ; PeekMessageA
        dq 0x5250 ; GetAsyncKeyState
        dq 0x5264 ; GetCursorPos
        dq 0x5274 ; ScreenToClient
        dq 0      ; End USER32 ILT

        dq 0x5286 ; StretchDIBits
        dq 0      ; End GDI32 ILT

        ; --- Import Address Table (IAT: RVA 0x50E8 .. 0x517F) ---
        dq 0x51A4 ; 0x50E8 ExitProcess
        dq 0x51B2 ; 0x50F0 GetStdHandle
        dq 0x51C2 ; 0x50F8 WriteFile
        dq 0x51CE ; 0x5100 Sleep
        dq 0x51D6 ; 0x5108 QueryPerformanceCounter
        dq 0x51F0 ; 0x5110 CreateFileA
        dq 0x51FE ; 0x5118 ReadFile
        dq 0x520A ; 0x5120 CloseHandle
        dq 0x5218 ; 0x5128 DeleteFileA
        dq 0      ; 0x5130 End KERNEL32 IAT

        dq 0x5226 ; 0x5138 CreateWindowExA
        dq 0x5238 ; 0x5140 GetDC
        dq 0x5240 ; 0x5148 PeekMessageA
        dq 0x5250 ; 0x5150 GetAsyncKeyState
        dq 0x5264 ; 0x5158 GetCursorPos
        dq 0x5274 ; 0x5160 ScreenToClient
        dq 0      ; 0x5168 End USER32 IAT

        dq 0x5286 ; 0x5170 StretchDIBits
        dq 0      ; 0x5178 End GDI32 IAT

        ; --- DLL Names (RVA 0x5180 .. 0x51A3) ---
        db 'KERNEL32.DLL', 0, 0     ; 0x5180 (14 bytes)
        db 'USER32.DLL', 0, 0       ; 0x518E (12 bytes)
        db 'GDI32.DLL', 0           ; 0x519A (10 bytes)

        ; --- Hint/Name Table (RVA 0x51A4 ..) ---
        dw 0
        db 'ExitProcess', 0             ; 0x51A4 (14 bytes)
        dw 0
        db 'GetStdHandle', 0, 0         ; 0x51B2 (16 bytes)
        dw 0
        db 'WriteFile', 0               ; 0x51C2 (12 bytes)
        dw 0
        db 'Sleep', 0                   ; 0x51CE (8 bytes)
        dw 0
        db 'QueryPerformanceCounter', 0 ; 0x51D6 (26 bytes)
        dw 0
        db 'CreateFileA', 0             ; 0x51F0 (14 bytes)
        dw 0
        db 'ReadFile', 0, 0             ; 0x51FE (12 bytes)
        dw 0
        db 'CloseHandle', 0             ; 0x520A (14 bytes)
        dw 0
        db 'DeleteFileA', 0             ; 0x5218 (14 bytes)
        dw 0
        db 'CreateWindowExA', 0         ; 0x5226 (18 bytes)
        dw 0
        db 'GetDC', 0                   ; 0x5238 (8 bytes)
        dw 0
        db 'PeekMessageA', 0, 0         ; 0x5240 (16 bytes)
        dw 0
        db 'GetAsyncKeyState', 0, 0     ; 0x5250 (20 bytes)
        dw 0
        db 'GetCursorPos', 0, 0         ; 0x5264 (16 bytes)
        dw 0
        db 'ScreenToClient', 0, 0       ; 0x5274 (18 bytes)
        dw 0
        db 'StretchDIBits', 0           ; 0x5286 (16 bytes)

        times (0x400 - ($ - idata_section)) db 0
section '.bss' readable writeable
    hStdOut         dq ?
    bytesWritten    dq ?
    hFile           dq ?
    bytesRead       dq ?
    lineNum         dd ?
    isRunMode       dd ?
    targetFilePtr   dq ?

    src_buffer      rb 65536        ; 64KB source buffer (after 'use' splicing)
    use_tmp_buffer  rb 32768        ; 32KB temp buffer for 'use file.flu'
    tok_buffer      rb 65536        ; 64KB token stream
    str_pool        rb 16384        ; 16KB identifier/keyword pool
    rodata_buffer   rb 4096         ; 4KB .rodata section
    rodata_len      dd ?
    code_buffer     rb 16384        ; 16KB .text machine code section

    ; String literal length lookup (indexed by .rodata offset)
    str_len_table   rd 4096
    last_str_len    dd ?
    expr_type_tag   dd ?            ; Tracks evaluated TYPE_* tag of last expression
    expr_custom_idx dd ?            ; Tracks custom #define index (-1 if primitive)

    ; --- Custom #define Primitive Value Type Table (up to 32 types e.g. 'rect') ---
    def_name_off    rd 32           ; str_pool offset of custom primitive type name
    def_byte_size   rd 32           ; Total packed byte size (e.g., 16 for rect)
    def_field_cnt   rd 32           ; Number of fields (up to 8 per type)
    def_fld_name    rd 256          ; 32 * 8 field str_pool offsets
    def_fld_type    rb 256          ; 1=int, 2=float
    def_fld_bits    rb 256          ; 8, 16, 32, or 64
    def_fld_off     rd 256          ; Byte offset inside packed value
    def_count       dd ?

    ; --- Class / Subclass Prototype Schema Table (up to 64 classes) ---
    cls_name_off    rd 64           ; str_pool offset of class/subclass name
    cls_parent_idx  rd 64           ; Parent class index (-1 if top-level)
    cls_fld_cnt     rd 64           ; Number of fields (up to 16 per class)
    cls_fld_name    rd 1024         ; 64 * 16 field str_pool offsets
    cls_fld_type    rb 1024         ; Default TYPE_* tag for each field
    cls_main_off    rd 64           ; code_buffer offset of class 'fn main' (-1 if none)
    cls_count       dd ?
    cur_cls_idx     dd ?            ; Enclosing class index during compilation (-1 if none)

    ; --- Universal 24-Byte Variable Symbol Table ---
    sym_str_off     rd 256          ; str_pool offset of variable name
    sym_offset      rd 256          ; Local: RBP byte offset (24, 48, ...); Global: BSS RVA
    sym_is_global   rb 256          ; 1 = global (.bss), 0 = local ([rbp - disp])
    sym_is_fluid    rb 256          ; 1 = declared with 'fluid' (can morph into any type!)
    sym_type_tag    rb 256          ; Current static/initial TYPE_* tag
    sym_custom_idx  rd 256          ; Index into def_table or cls_table (-1 if none)
    sym_const_lock  rb 256          ; 1 = locked const
    sym_deleted     rb 256          ; 1 = deleted via delete_var(x)
    sym_obj_del_msk rq 256          ; Compile-time bitmask of fields deleted via delete_var_class
    sym_count       dd ?
    global_sym_cnt  dd ?
    in_fn_scope     dd ?
    next_local_off  dd ?            ; Starts at 24 ([rbp - 16] = scratch), increments by 24
    decl_is_const   dd ?

    ; --- Function Symbol Table (for fn & class.method calls) ---
    fn_str_off      rd 256
    fn_code_off     rd 256
    fn_count        dd ?
    main_code_off   dd ?            ; Top-level 'fn main' offset (-1 if missing)

    ; --- Control Flow Block Stack (0=class, 1=fn, 2=if, 3=while, 4=else) ---
    blk_type        rd 64
    blk_patch_off   rd 64
    blk_loop_top    rd 64
    blk_cls_prev    rd 64
    blk_depth       dd ?

    startup_info    rb 104
    proc_info       rb 24
; ==============================================================================
; COMPILER ENTRY, CLI ROUTER, & 'use' FILE PREPROCESSOR
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
    je cmd_compile
    mov [targetFilePtr], rsi
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
    invoke CreateFileA, [targetFilePtr], GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
    cmp rax, INVALID_HANDLE_VALUE
    je file_error
    mov [hFile], rax
    invoke ReadFile, [hFile], use_tmp_buffer, 32767, bytesRead, 0
    invoke CloseHandle, [hFile]
    mov eax, dword [bytesRead]
    mov byte [use_tmp_buffer + rax], 0

    call expand_use_imports
    call run_lexer
    call run_codegen
    test eax, eax
    jnz compile_failed
    call write_pe_exe

    lea rcx, [ok_msg]
    call print_cstr

    cmp dword [isRunMode], 1
    jne .done_exit

    lea rcx, [run_msg]
    call print_cstr

    mov dword [startup_info], 104
    invoke CreateProcessA, out_exe_name, 0, 0, 0, 0, 0, 0, 0, startup_info, proc_info
    invoke WaitForSingleObject, qword [proc_info], -1
    invoke CloseHandle, qword [proc_info]
    invoke CloseHandle, qword [proc_info+8]

.done_exit:
    invoke ExitProcess, 0

compile_failed:
    invoke ExitProcess, 1

file_error:
    lea rcx, [err_file_msg]
    call print_cstr
    invoke ExitProcess, 1

; --- Preprocessor: Splices 'use game.flu' files into src_buffer ---
expand_use_imports:
    lea rsi, [use_tmp_buffer]
    lea rdi, [src_buffer]
.scan_line:
    mov al, [rsi]
    test al, al
    jz .done
    cmp dword [rsi], 'use '
    jne .copy_char
    add rsi, 4
    call skip_spaces
    sub rsp, 72
    lea r8, [rsp]
    xor ecx, ecx
.fn_char:
    mov al, [rsi]
    test al, al
    jz .fn_end
    cmp al, ' '
    je .fn_end
    cmp al, 13
    je .fn_end
    cmp al, 10
    je .fn_end
    cmp al, '/'
    je .fn_end
    mov [r8 + rcx], al
    inc rcx
    inc rsi
    cmp ecx, 60
    jl .fn_char
.fn_end:
    mov byte [r8 + rcx], 0
.skip_use_rest:
    mov al, [rsi]
    test al, al
    jz .open_inc
    inc rsi
    cmp al, 10
    jne .skip_use_rest
.open_inc:
    push rsi
    push rdi
    invoke CreateFileA, r8, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
    pop rdi
    pop rsi
    cmp rax, INVALID_HANDLE_VALUE
    je .inc_cleanup
    mov [hFile], rax
    push rsi
    invoke ReadFile, [hFile], rdi, 32767, bytesRead, 0
    invoke CloseHandle, [hFile]
    pop rsi
    mov eax, dword [bytesRead]
    add rdi, rax
    mov byte [rdi], 10
    inc rdi
.inc_cleanup:
    add rsp, 72
    jmp .scan_line

.copy_char:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .scan_line
.done:
    mov byte [rdi], 0
    ret
; ==============================================================================
; STAGE 1: FLUID LEXER (Hex 0x, IEEE-754 Float32, 'char', Escapes, & Lengths)
; ==============================================================================
run_lexer:
    lea rsi, [src_buffer]
    lea rdi, [tok_buffer]
    lea rbx, [str_pool]
    lea r10, [rodata_buffer]
    mov dword [lineNum], 1

    ; Pre-seed .rodata:
    ;   0x00 = "STATIC\0"
    ;   0x08 = "Fluid App\0"
    ;   0x14 = " \0"
    ;   0x16 = "\n\0"
    mov dword [r10], 'STAT'
    mov dword [r10+4], 0x00004349
    mov dword [r10+8], 'Flui'
    mov dword [r10+12], 'd Ap'
    mov dword [r10+16], 0x00000070
    mov word [r10+20], 0x0020       ; RVA 0x6014: " \0"
    mov word [r10+22], 0x000A       ; RVA 0x6016: "\n\0"
    add r10, 0x18                   ; User strings start at RVA 0x6018

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
    cmp al, "'"
    je .char_lit

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
; --- Number Literal: Supports Hex (0xFF0000), Float (3.0, 7.5), and Int ---
.number:
    cmp byte [rsi], '0'
    jne .dec_number
    cmp byte [rsi+1], 'x'
    je .hex_number
    cmp byte [rsi+1], 'X'
    je .hex_number

.dec_number:
    xor eax, eax
.int_loop:
    movzx edx, byte [rsi]
    sub edx, '0'
    jb .chk_float_dot
    cmp edx, 9
    ja .chk_float_dot
    imul eax, 10
    add eax, edx
    inc rsi
    jmp .int_loop

.chk_float_dot:
    cmp byte [rsi], '.'
    jne .emit_int_tok
    inc rsi                         ; Skip '.'
    xor ecx, ecx
    mov r8d, 1
.frac_loop:
    movzx edx, byte [rsi]
    sub edx, '0'
    jb .encode_f32
    cmp edx, 9
    ja .encode_f32
    imul ecx, 10
    add ecx, edx
    imul r8d, 10
    inc rsi
    jmp .frac_loop
.encode_f32:
    cvtsi2ss xmm0, eax
    cvtsi2ss xmm1, ecx
    cvtsi2ss xmm2, r8d
    divss xmm1, xmm2
    addss xmm0, xmm1
    movd eax, xmm0
    mov byte [rdi], TOK_FLOAT
    mov [rdi+4], eax
    add rdi, 8
    jmp .loop

.emit_int_tok:
    mov byte [rdi], TOK_INT
    mov [rdi+4], eax
    add rdi, 8
    jmp .loop

.hex_number:
    add rsi, 2
    xor eax, eax
.hex_loop:
    movzx edx, byte [rsi]
    cmp dl, '0'
    jb .emit_int_tok
    cmp dl, '9'
    jbe .hex_digit
    cmp dl, 'A'
    jb .emit_int_tok
    cmp dl, 'F'
    jbe .hex_upper
    cmp dl, 'a'
    jb .emit_int_tok
    cmp dl, 'f'
    ja .emit_int_tok
    sub edx, 'a' - 10
    jmp .hex_accum
.hex_upper:
    sub edx, 'A' - 10
    jmp .hex_accum
.hex_digit:
    sub edx, '0'
.hex_accum:
    shl eax, 4
    or eax, edx
    inc rsi
    jmp .hex_loop
; --- Single Character Literal: '<', 'a', '\n' ---
.char_lit:
    inc rsi
    movzx eax, byte [rsi]
    cmp al, '\'
    jne .char_store
    inc rsi
    cmp byte [rsi], 'n'
    jne .char_esc_raw
    mov eax, 10
    jmp .char_store
.char_esc_raw:
    movzx eax, byte [rsi]
.char_store:
    inc rsi
    cmp byte [rsi], "'"
    jne .emit_char_tok
    inc rsi
.emit_char_tok:
    mov byte [rdi], TOK_CHAR
    mov [rdi+4], eax
    add rdi, 8
    jmp .loop

; --- String Literal ---
.string:
    inc rsi
    mov r8, r10
.str_loop:
    mov al, [rsi]
    test al, al
    jz .str_done
    cmp al, '"'
    je .str_end
    cmp al, '\'
    jne .str_store
    cmp byte [rsi+1], 'n'
    jne .str_store
    mov byte [r10], 10
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
    mov rcx, r10
    sub rcx, r8
    mov byte [r10], 0
    inc r10
    mov byte [rdi], TOK_STR
    mov rax, r8
    sub rax, rodata_buffer
    mov [rdi+4], eax
    mov [str_len_table + rax*4], ecx
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
; STAGE 2A-1: STATEMENT DISPATCHER, #define PRIMITIVE TYPE BUILDER, & CLASSES
; ==============================================================================
run_codegen:
    lea rsi, [tok_buffer]
    lea rdi, [code_buffer]
    mov dword [def_count], 0
    mov dword [cls_count], 0
    mov dword [cur_cls_idx], -1
    mov dword [sym_count], 0
    mov dword [global_sym_cnt], 0
    mov dword [in_fn_scope], 0
    mov dword [next_local_off], 24  ; [rbp - 16] reserved for scratch! (24B universal slots)
    mov dword [fn_count], 0
    mov dword [blk_depth], 0
    mov dword [main_code_off], -1
    mov dword [decl_is_const], 0

    ; Emit Program Entry Stub at RVA 0x1000:
    ; sub rsp, 40             (48 83 EC 28) -> 16-byte stack alignment + shadow space
    ; call rel32              (E8 00 00 00 00) -> Patched at end to call top-level 'fn main'
    ; mov ecx, eax            (89 C1)       -> Exit code
    ; call [IAT_EXIT_PROCESS] (FF 15 <rel32>)
    mov dword [rdi], 0x28EC8348
    mov byte [rdi+4], 0xE8
    mov dword [rdi+5], 0
    mov word [rdi+9], 0xC189
    add rdi, 11
    mov edx, IAT_EXIT_PROCESS
    call emit_iat_call

.stmt_loop:
    mov al, [rsi]
    cmp al, TOK_EOF
    je finish_program

    cmp al, TOK_NEWLINE
    je .skip_tok

    ; 1. #define custom primitive value type constructor (not a struct/class!)
    cmp al, TOK_KW_DEFINE
    je .handle_define

    ; 2. class / subclass prototype schemas
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

    ; 5. Array Declaration: array a = []9  OR  array edge = [width, height]2
    cmp al, TOK_KW_ARRAY
    je .handle_array_decl

    ; 6. Variable Declarations: fluid / int / float / str / chr / obj / const / global
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
    cmp al, TOK_KW_CHR
    je .handle_var_decl
    cmp al, TOK_KW_OBJ
    je .handle_obj_decl

    ; 7. Return statement
    cmp al, TOK_KW_RETURN
    je .handle_return

    ; 8. Identifier statement: custom type decl (rect x = ...), assignment, or call
    cmp al, TOK_IDENT
    je .handle_ident_stmt

.skip_tok:
    add rsi, 8
    jmp .stmt_loop
; ==============================================================================
; #define <name> { <type>,<bits>:<field_name> ... }
; Registers a raw fixed-width packed primitive value type (like int or float)
; ==============================================================================
.handle_define:
    add rsi, 8                      ; Skip '#define'
    cmp byte [rsi], TOK_IDENT
    jne .stmt_loop
    mov r8d, [def_count]
    mov eax, [rsi+4]
    mov [def_name_off + r8*4], eax
    mov dword [def_byte_size + r8*4], 0
    mov dword [def_field_cnt + r8*4], 0
    inc dword [def_count]
    add rsi, 8
    cmp byte [rsi], TOK_LBRACE
    jne .stmt_loop
    add rsi, 8                      ; Skip '{'

.def_field_loop:
    mov al, [rsi]
    cmp al, TOK_EOF
    je finish_program
    cmp al, TOK_RBRACE
    je .def_done
    cmp al, TOK_NEWLINE
    je .def_next_tok

    mov bl, 1                       ; Default int
    cmp al, TOK_KW_FLOAT
    jne .def_chk_comma
    mov bl, 2                       ; float
.def_chk_comma:
    add rsi, 8
    mov cl, 32                      ; Default 32 bits
    cmp byte [rsi], TOK_COMMA
    jne .def_chk_colon
    add rsi, 8
    cmp byte [rsi], TOK_INT
    jne .def_chk_colon
    mov cl, [rsi+4]
    add rsi, 8
.def_chk_colon:
    cmp byte [rsi], TOK_COLON
    jne .def_next_tok
    add rsi, 8
    cmp byte [rsi], TOK_IDENT
    jne .def_next_tok

    mov edx, [def_field_cnt + r8*4]
    mov eax, r8d
    shl eax, 3
    add eax, edx
    mov r9d, [rsi+4]
    mov [def_fld_name + rax*4], r9d
    mov [def_fld_type + rax], bl
    mov [def_fld_bits + rax], cl
    mov r9d, [def_byte_size + r8*4]
    mov [def_fld_off + rax*4], r9d

    movzx ecx, cl
    shr ecx, 3
    add [def_byte_size + r8*4], ecx
    inc dword [def_field_cnt + r8*4]
    add rsi, 8
    jmp .def_field_loop

.def_next_tok:
    add rsi, 8
    jmp .def_field_loop

.def_done:
    add rsi, 8                      ; Skip '}'
    jmp .stmt_loop

; ==============================================================================
; class / subclass <name> { ... }
; Registers subtractive prototype schema & hierarchy
; ==============================================================================
.handle_class_header:
    add rsi, 8
    cmp byte [rsi], TOK_IDENT
    jne .stmt_loop
    mov r8d, [cls_count]
    mov eax, [rsi+4]
    mov [cls_name_off + r8*4], eax
    mov eax, [cur_cls_idx]
    mov [cls_parent_idx + r8*4], eax
    mov dword [cls_fld_cnt + r8*4], 0
    mov dword [cls_main_off + r8*4], -1
    inc dword [cls_count]

    mov ecx, [blk_depth]
    mov dword [blk_type + rcx*4], 0
    mov eax, [cur_cls_idx]
    mov [blk_cls_prev + rcx*4], eax
    mov [cur_cls_idx], r8d
    inc dword [blk_depth]

    add rsi, 8
    cmp byte [rsi], TOK_LBRACE
    jne .stmt_loop
    add rsi, 8
    jmp .stmt_loop
; ==============================================================================
; STAGE 2A-2: ARRAY, PROTOTYPE OBJ, & UNIVERSAL FLUID / TYPED DECLARATIONS
; ==============================================================================

; --- Array Declaration: array a = []9   OR   array edge = [width, height]2 ---
.handle_array_decl:
    add rsi, 8                      ; Advance to <ident>
    cmp byte [rsi], TOK_IDENT
    jne .stmt_loop
    mov eax, [rsi+4]                ; Array variable name str_pool offset
    call register_symbol            ; Returns symbol index in EDX
    mov byte [sym_type_tag + rdx], TYPE_ARRAY
    push rdx                        ; Save symbol index
    add rsi, 8
    cmp byte [rsi], TOK_ASSIGN
    jne .arr_decl_empty_default
    add rsi, 8                      ; Advance to RHS ('[' or get_mouse_pos())

    cmp byte [rsi], TOK_LBRACK
    je .parse_array_literal
    call eval_expr                  ; e.g., get_mouse_pos() returns array ptr in RAX
    pop rdx
    mov bl, TYPE_ARRAY
    call emit_store_typed_symbol
    jmp .stmt_loop

.arr_decl_empty_default:
    mov ecx, 16                     ; Default capacity 16
    xor r12d, r12d                  ; Initial length 0
    jmp .emit_heap_array_alloc

.parse_array_literal:
    add rsi, 8                      ; Skip '['
    xor r12d, r12d                  ; Element count pushed onto stack
.arr_lit_items:
    cmp byte [rsi], TOK_RBRACK
    je .arr_lit_rbrack
    cmp byte [rsi], TOK_EOF
    je .arr_lit_rbrack
    call eval_expr                  ; Element value -> RAX
    mov byte [rdi], 0x50            ; push rax
    inc rdi
    inc r12d
    cmp byte [rsi], TOK_COMMA
    jne .arr_lit_items
    add rsi, 8                      ; Skip ','
    jmp .arr_lit_items

.arr_lit_rbrack:
    add rsi, 8                      ; Skip ']'
    mov ecx, r12d                   ; Default capacity = initial length
    cmp byte [rsi], TOK_INT
    jne .emit_heap_array_alloc
    mov ecx, [rsi+4]                ; Explicit capacity after ']' (e.g., []9 -> 9)
    add rsi, 8

.emit_heap_array_alloc:
    pop rdx
    call emit_alloc_array_from_stack
    jmp .stmt_loop

; --- Prototype Object Instance: obj m = fish ---
.handle_obj_decl:
    add rsi, 8                      ; Advance to <ident> (e.g., 'm')
    cmp byte [rsi], TOK_IDENT
    jne .stmt_loop
    mov eax, [rsi+4]
    call register_symbol            ; Returns symbol index in EDX
    mov byte [sym_type_tag + rdx], TYPE_OBJ
    push rdx
    add rsi, 8
    cmp byte [rsi], TOK_ASSIGN
    jne .obj_decl_done
    add rsi, 8
    cmp byte [rsi], TOK_IDENT
    jne .obj_decl_done
    mov eax, [rsi+4]                ; Prototype class name (e.g., 'fish')
    add rsi, 8
    call lookup_class               ; Returns class index in EAX
    pop rdx
    mov [sym_custom_idx + rdx*4], eax
    call emit_instantiate_obj       ; Allocates independent copy + 64-bit active bitmask!
    jmp .stmt_loop
.obj_decl_done:
    pop rdx
    jmp .stmt_loop

; --- Scalar / Universal Fluid Declarations: const / fluid / int / float / str / chr ---
.handle_const_decl:
    mov dword [decl_is_const], 1
    add rsi, 8
    jmp .handle_var_decl

.handle_var_decl:
    mov bl, TYPE_INT                ; Map keyword token to initial TYPE_* tag
    xor bh, bh                      ; bh = 1 if declared with 'fluid'
    cmp al, TOK_KW_FLOAT
    jne .chk_t_str
    mov bl, TYPE_FLOAT
.chk_t_str:
    cmp al, TOK_KW_STR
    jne .chk_t_chr
    mov bl, TYPE_STR
.chk_t_chr:
    cmp al, TOK_KW_CHR
    jne .chk_t_fluid
    mov bl, TYPE_CHR
.chk_t_fluid:
    cmp al, TOK_KW_FLUID
    jne .parse_var_ident
    mov bl, TYPE_NULL
    mov bh, 1                       ; Mark as universal 'fluid' variable!

.parse_var_ident:
    add rsi, 8                      ; Advance to <ident>
    cmp byte [rsi], TOK_IDENT
    jne .reset_const_flag
    mov eax, [rsi+4]                ; Variable name str_pool offset
    add rsi, 8

    ; If inside a class body (outside any fn), add field to class prototype schema!
    cmp dword [in_fn_scope], 0
    jne .decl_normal_var
    cmp dword [cur_cls_idx], -1
    je .decl_normal_var
    mov ecx, [cur_cls_idx]
    call add_class_proto_field
    mov dword [decl_is_const], 0
    jmp .stmt_loop

.decl_normal_var:
    push rbx
    call register_symbol            ; Returns symbol index in EDX
    pop rbx
    mov [sym_type_tag + rdx], bl
    mov [sym_is_fluid + rdx], bh    ; 1 = fluid (universal type morphing), 0 = static
    cmp dword [decl_is_const], 1
    jne .not_const_sym
    mov byte [sym_const_lock + rdx], 1
.not_const_sym:
    mov dword [decl_is_const], 0
    push rdx
    push rbx
    cmp byte [rsi], TOK_ASSIGN
    jne .decl_no_init
    add rsi, 8                      ; Advance to RHS expression
    call eval_expr                  ; Value -> RAX, runtime tag -> [expr_type_tag]
    pop rbx
    pop rdx
    ; If RHS evaluated to a 16-byte custom #define primitive (TYPE_CUSTOM), copy all 16 bytes!
    cmp dword [expr_type_tag], TYPE_CUSTOM
    jne .store_scalar_init
    mov ecx, [expr_custom_idx]
    mov [sym_custom_idx + rdx*4], ecx
    call emit_copy_custom_to_symbol ; Copies 16B from [rax] into slot EDX and sets tag=TYPE_CUSTOM
    jmp .stmt_loop
.store_scalar_init:
    mov bl, byte [expr_type_tag]
    call emit_store_typed_symbol
    jmp .stmt_loop
.decl_no_init:
    pop rbx
    pop rdx
    jmp .stmt_loop
.reset_const_flag:
    mov dword [decl_is_const], 0
    jmp .stmt_loop
; ==============================================================================
; STAGE 2B: FUNCTION DEFINITIONS, DESTRUCTURING PARAMS, & TYPE ANNOTATIONS
; ==============================================================================

; --- Return Statement ---
.handle_return:
    add rsi, 8
    cmp byte [rsi], TOK_NEWLINE
    je .void_ret
    cmp byte [rsi], TOK_RBRACE
    je .void_ret
    call eval_expr                  ; 64-bit result in RAX
    jmp .emit_ret_epilogue
.void_ret:
    mov word [rdi], 0xC031          ; xor eax, eax
    add rdi, 2
.emit_ret_epilogue:
    mov word [rdi], 0xC3C9          ; leave; ret
    add rdi, 2
    jmp .stmt_loop

; --- Function Definition: fn <name> [(params)] { ---
.handle_fn_def:
    add rsi, 8                      ; Advance to function name
    cmp byte [rsi], TOK_IDENT
    jne .stmt_loop
    mov eax, [rsi+4]                ; str_pool offset of fn name

    ; Snapshot global_sym_cnt on first function & reset local scope
    cmp dword [in_fn_scope], 0
    jne .already_in_fn_mode
    mov ecx, [sym_count]
    mov [global_sym_cnt], ecx
.already_in_fn_mode:
    mov dword [in_fn_scope], 1
    mov ecx, [global_sym_cnt]
    mov [sym_count], ecx            ; Discard previous function's local symbols!
    mov dword [next_local_off], 24  ; Locals start at [rbp - 24] ([rbp - 16] = scratch)

    ; Current code_buffer offset in EDX
    mov rdx, rdi
    sub rdx, code_buffer

    ; Check if inside a class/subclass -> mangle name & enforce single 'fn main' rule
    cmp dword [cur_cls_idx], -1
    je .top_level_fn_reg

    mov r8d, [cur_cls_idx]
    lea r9, [str_pool + rax]
    cmp dword [r9], 'main'
    jne .reg_mangled_method
    cmp byte [r9+4], 0
    jne .reg_mangled_method

    ; Class 'fn main' -> check that class doesn't already have one!
    cmp dword [cls_main_off + r8*4], -1
    jne .err_duplicate_class_main
    mov [cls_main_off + r8*4], edx

.reg_mangled_method:
    call register_class_method
    jmp .fn_emit_prologue

.top_level_fn_reg:
    mov ecx, [fn_count]
    mov [fn_str_off + rcx*4], eax
    mov [fn_code_off + rcx*4], edx
    inc dword [fn_count]

    ; Check if top-level 'fn main' -> save entry offset
    lea r9, [str_pool + rax]
    cmp dword [r9], 'main'
    jne .fn_emit_prologue
    cmp byte [r9+4], 0
    jne .fn_emit_prologue
    mov [main_code_off], edx

.fn_emit_prologue:
    ; Emit 64-bit function prologue (1536B local frame for 24B universal slots):
    ; push rbp (55), mov rbp, rsp (48 89 E5), sub rsp, 1536 (48 81 EC 00 06 00 00)
    mov byte [rdi], 0x55
    mov dword [rdi+1], 0x8148E589
    mov dword [rdi+5], 0x00000600
    add rdi, 9

    ; If inside a class method, hidden 'this' pointer arrives in RCX; user args start at RDX (idx 1)
    cmp dword [cur_cls_idx], -1
    je .parse_fn_params
    mov r12d, 1
    jmp .chk_param_lparen

.parse_fn_params:
    xor r12d, r12d                  ; User parameter register index (0=RCX, 1=RDX, 2=R8, 3=R9)

.chk_param_lparen:
    add rsi, 8                      ; Advance past fn name
    cmp byte [rsi], TOK_LPAREN
    jne .skip_to_fn_brace
    add rsi, 8                      ; Skip '('

.param_loop:
    mov al, [rsi]
    cmp al, TOK_RPAREN
    je .params_finished
    cmp al, TOK_EOF
    je finish_program
    cmp al, TOK_COMMA
    je .next_param_tok

    ; Check for Fluid array parameter destructuring: [sx, sy]2  OR  array[sx, sy]2
    cmp al, TOK_KW_ARRAY
    jne .chk_bracket_destructure
    add rsi, 8
    mov al, [rsi]
.chk_bracket_destructure:
    cmp al, TOK_LBRACK
    je .destructure_array_param

    ; Standard parameter: <name> [: <type>]
    cmp al, TOK_IDENT
    jne .next_param_tok
    mov eax, [rsi+4]
    call register_symbol            ; Returns stack offset in ECX, index in EDX
    mov byte [sym_type_tag + rdx], TYPE_INT
    mov byte [sym_is_fluid + rdx], 1
    add rsi, 8

    ; Optional ':type' annotation (e.g., rect:rect)
    cmp byte [rsi], TOK_COLON
    jne .spill_param_reg
    add rsi, 8                      ; Skip ':'
    call parse_type_annotation      ; Updates sym_type_tag / sym_custom_idx for RDX

.spill_param_reg:
    call emit_spill_arg_reg         ; Spills R12D-th arg reg (RCX/RDX/R8/R9) into [rbp - ECX]
    inc r12d
    jmp .param_loop

; --- Array Parameter Destructuring: [sx, sy]2 ---
.destructure_array_param:
    add rsi, 8                      ; Skip '['
    call emit_load_arg_reg_to_rax
    mov dword [rdi], 0xF8458948     ; mov [rbp - 8], rax
    add rdi, 4
    xor r13d, r13d
.destr_elem_loop:
    cmp byte [rsi], TOK_RBRACK
    je .destr_done
    cmp byte [rsi], TOK_EOF
    je finish_program
    cmp byte [rsi], TOK_IDENT
    jne .destr_next_tok
    mov eax, [rsi+4]
    call register_symbol
    mov byte [sym_type_tag + rdx], TYPE_INT
    mov dword [rdi], 0xF8458B48     ; mov rax, [rbp - 8]
    add rdi, 4
    mov eax, r13d
    shl eax, 3
    add eax, 8
    mov dword [rdi], 0x00808B48     ; mov rax, [rax + disp32]
    mov [rdi+3], eax
    add rdi, 7
    neg ecx
    mov dword [rdi], 0x00858948     ; mov [rbp - ecx], rax
    mov [rdi+3], ecx
    add rdi, 7
    inc r13d
.destr_next_tok:
    add rsi, 8
    jmp .destr_elem_loop
.destr_done:
    add rsi, 8                      ; Skip ']'
    cmp byte [rsi], TOK_INT
    jne .inc_destr_arg
    add rsi, 8
.inc_destr_arg:
    inc r12d
    jmp .param_loop

.next_param_tok:
    add rsi, 8
    jmp .param_loop

.params_finished:
    add rsi, 8                      ; Skip ')'

.skip_to_fn_brace:
    mov al, [rsi]
    cmp al, TOK_EOF
    je finish_program
    cmp al, TOK_LBRACE
    je .fn_body_start
    add rsi, 8
    jmp .skip_to_fn_brace

.fn_body_start:
    mov ecx, [blk_depth]
    mov dword [blk_type + rcx*4], 1
    inc dword [blk_depth]
    add rsi, 8
    jmp .stmt_loop

.err_duplicate_class_main:
    lea rcx, [err_dup_main]
    call print_cstr
    mov eax, 1
    ret
; ==============================================================================
; STAGE 2C-1: CONTROL FLOW (if / else / while / })
; ==============================================================================

; --- If Statement: if <expr> [== | < | >] <expr> { ---
.handle_if:
    add rsi, 8
    call emit_condition
    mov ecx, [blk_depth]
    mov dword [blk_type + rcx*4], 2
    mov [blk_patch_off + rcx*4], eax
    inc dword [blk_depth]
    jmp .stmt_loop

; --- While Loop: while <expr> [== | < | >] <expr> { ---
.handle_while:
    add rsi, 8
    mov rdx, rdi
    sub rdx, code_buffer
    push rdx
    call emit_condition
    pop rdx
    mov ecx, [blk_depth]
    mov dword [blk_type + rcx*4], 3
    mov [blk_patch_off + rcx*4], eax
    mov [blk_loop_top + rcx*4], edx
    inc dword [blk_depth]
    jmp .stmt_loop

; --- Closing Brace '}' (Supports class/subclass, fn, if, if-else, and while) ---
.handle_rbrace:
    add rsi, 8
    cmp dword [blk_depth], 0
    je .stmt_loop
    dec dword [blk_depth]
    mov ecx, [blk_depth]
    mov eax, [blk_type + rcx*4]

    cmp eax, 0                      ; Closing 'class' or 'subclass'
    je .close_class
    cmp eax, 1                      ; Closing 'fn'
    je .close_fn
    cmp eax, 2                      ; Closing 'if' (check for trailing 'else')
    je .close_if
    cmp eax, 3                      ; Closing 'while'
    je .close_while
    cmp eax, 4                      ; Closing 'else'
    je .close_else
    jmp .stmt_loop

.close_class:
    mov edx, [blk_cls_prev + rcx*4]
    mov [cur_cls_idx], edx
    jmp .stmt_loop

.close_fn:
    ; Default return 0: xor eax, eax (31 C0), leave (C9), ret (C3)
    mov dword [rdi], 0xC3C9C031
    add rdi, 4
    jmp .stmt_loop

.close_if:
    mov r11, rsi
.chk_else_nl:
    cmp byte [r11], TOK_NEWLINE
    jne .chk_else_tok
    add r11, 8
    jmp .chk_else_nl
.chk_else_tok:
    cmp byte [r11], TOK_KW_ELSE
    jne .close_if_only

    ; Emit forward jmp over 'else' body
    mov byte [rdi], 0xE9
    mov dword [rdi+1], 0
    mov rax, rdi
    sub rax, code_buffer
    inc eax
    add rdi, 5

    ; Patch 'if' jump to start of 'else' body
    mov edx, [blk_patch_off + rcx*4]
    lea r8, [code_buffer + rdx]
    mov r9, rdi
    sub r9, r8
    sub r9d, 4
    mov [r8], r9d

    mov dword [blk_type + rcx*4], 4
    mov [blk_patch_off + rcx*4], eax
    inc dword [blk_depth]
    lea rsi, [r11 + 8]
    cmp byte [rsi], TOK_LBRACE
    jne .stmt_loop
    add rsi, 8
    jmp .stmt_loop

.close_if_only:
    mov edx, [blk_patch_off + rcx*4]
    lea r8, [code_buffer + rdx]
    mov rax, rdi
    sub rax, r8
    sub eax, 4
    mov [r8], eax
    jmp .stmt_loop

.close_else:
    mov edx, [blk_patch_off + rcx*4]
    lea r8, [code_buffer + rdx]
    mov rax, rdi
    sub rax, r8
    sub eax, 4
    mov [r8], eax
    jmp .stmt_loop

.close_while:
    mov byte [rdi], 0xE9
    mov edx, [blk_loop_top + rcx*4]
    lea r8, [code_buffer + rdx]
    mov rax, r8
    sub rax, rdi
    sub eax, 5
    mov [rdi+1], eax
    add rdi, 5

    mov edx, [blk_patch_off + rcx*4]
    lea r8, [code_buffer + rdx]
    mov rax, rdi
    sub rax, r8
    sub eax, 4
    mov [r8], eax
    jmp .stmt_loop
; ==============================================================================
; STAGE 2C-2: IDENTIFIER STATEMENTS, #define PACKING, FILE I/O, & DELETE TRAPS
; ==============================================================================
.handle_ident_stmt:
    mov eax, [rsi+4]                ; str_pool offset of leading identifier
    lea r9, [str_pool + rax]

    ; 1. Check if identifier is a custom #define primitive type (e.g., 'rect x = 3.0, 2.0, 5, 5')
    call lookup_custom_def          ; Returns custom def index in ECX (-1 if not custom type)
    cmp ecx, -1
    jne decl_custom_type_var

    ; 2. Check built-in Fluid syscalls & runtime intrinsics
    cmp dword [r9], 'term'          ; terminal_add(...)
    je call_terminal_add
    cmp dword [r9], 'wait'          ; wait(ms)
    je call_wait
    cmp dword [r9], 'wind'          ; window(w, h)
    je call_window
    cmp dword [r9], 'draw'          ; draw(...) OR draw_tri(...) OR draw_line(...)
    je dispatch_draw_call
    cmp dword [r9], 'push'          ; push(arr, val)
    je call_push
    cmp dword [r9], 'init'          ; initiate(obj)
    je .call_initiate
    cmp dword [r9], 'crea'          ; create_file(path, filename, fileending)
    je call_create_file
    cmp dword [r9], 'dele'          ; delete_file(path) OR delete_var(x) OR delete_var_class(m.z)
    je .dispatch_delete_call

    ; 3. Check dotted member access/call: m.x = 12, game.obj g = phys, m.main(), dts.println(...)
    cmp byte [rsi+8], TOK_DOT
    je .handle_dotted_stmt

    ; 4. Check array index write: arr[i] = expr
    cmp byte [rsi+8], TOK_LBRACK
    je .assign_array

    ; 5. Check scalar / universal fluid variable assignment: x = expr (or x = null / x = rect_val)
    cmp byte [rsi+8], TOK_ASSIGN
    je .assign_var

    ; 6. Standalone expression / mutating intrinsic call (e.g., str(m.a), my_fn())
    call eval_expr
skip_to_nl:
    mov al, [rsi]
    cmp al, TOK_EOF
    je finish_program
    cmp al, TOK_NEWLINE
    je .stmt_loop
    add rsi, 8
    jmp skip_to_nl

; --- Dispatch 'draw' vs 'draw_tri' vs 'draw_line' ---
dispatch_draw_call:
    cmp dword [r9+4], '_tri'
    je call_draw_tri 
    cmp dword [r9+4], '_lin'
    je call_draw_line
    jmp call_draw

; --- Dispatch 'delete_file' vs 'delete_var_class' vs 'delete_var' ---
.dispatch_delete_call:
    cmp dword [r9+7], 'file'        ; delete_file(path)
    je call_delete_file
    cmp byte [r9+10], '_'           ; delete_var_class(m.z)
    je .do_delete_var_class

    ; delete_var(x): marks variable deleted at compile time
    add rsi, 16                     ; Skip 'delete_var' and '('
    cmp byte [rsi], TOK_IDENT
    jne skip_to_nl
    mov eax, [rsi+4]
    call lookup_symbol
    cmp edx, -1
    je skip_to_nl
    mov byte [sym_deleted + rdx], 1
    jmp skip_to_nl

.do_delete_var_class:
    ; delete_var_class(m.z): sets bit in compile-time sym_obj_del_msk AND emits runtime btr!
    add rsi, 16                     ; Skip 'delete_var_class' and '('
    cmp byte [rsi], TOK_IDENT
    jne skip_to_nl
    mov eax, [rsi+4]                ; Instance variable name ('m')
    call lookup_symbol              ; Symbol index in EDX
    cmp edx, -1
    je skip_to_nl
    cmp byte [sym_deleted + rdx], 1
    je .err_deleted_access
    add rsi, 8
    cmp byte [rsi], TOK_DOT
    jne skip_to_nl
    add rsi, 8                      ; Skip '.'
    cmp byte [rsi], TOK_IDENT
    jne skip_to_nl
    mov eax, [rsi+4]                ; Field name ('z')
    mov ecx, [sym_custom_idx + rdx*4]
    call lookup_class_field         ; Field bit index in ECX
    cmp ecx, -1
    je skip_to_nl
    mov rax, 1
    shl rax, cl
    or [sym_obj_del_msk + rdx*8], rax
    call emit_clear_obj_field_bit_idx
    jmp skip_to_nl

; --- Custom #define Primitive Type Declaration: rect x = 3.0, 2.0, 5, 5 ---
decl_custom_type_var:
    add rsi, 8                      ; Advance to variable name (e.g., 'x')
    cmp byte [rsi], TOK_IDENT
    jne .stmt_loop
    mov eax, [rsi+4]
    push rcx                        ; Save custom def index
    call register_symbol            ; Returns symbol index in EDX
    pop rcx
    mov byte [sym_type_tag + rdx], TYPE_CUSTOM
    mov [sym_custom_idx + rdx*4], ecx
    add rsi, 8
    cmp byte [rsi], TOK_ASSIGN
    jne .stmt_loop
    add rsi, 8                      ; Advance to comma-separated field values
    call emit_pack_custom_def       ; Packs field values into 16B payload + sets tag=TYPE_CUSTOM!
    jmp .stmt_loop

; --- initiate(g): invokes class g's single 'fn main' method ---
.call_initiate:
    add rsi, 16                     ; Skip 'initiate' and '('
    cmp byte [rsi], TOK_IDENT
    jne skip_to_nl
    mov eax, [rsi+4]
    call lookup_symbol
    cmp edx, -1
    je skip_to_nl
    cmp byte [sym_deleted + rdx], 1
    je .err_deleted_access
    call emit_call_obj_main
    jmp skip_to_nl

; --- push(arr, val): appends element to dynamic Fluid array up to capacity ---
call_push:
    add rsi, 16                     ; Skip 'push' and '('
    cmp byte [rsi], TOK_IDENT
    jne skip_to_nl
    mov eax, [rsi+4]
    call lookup_symbol
    push rdx
    add rsi, 8
    cmp byte [rsi], TOK_COMMA
    jne .push_eval_val
    add rsi, 8
.push_eval_val:
    call eval_expr
    pop rdx
    call emit_array_push
    jmp skip_to_nl

; --- Dotted Statement: m.x = 12, game.obj g = phys, or dts.println(...) ---
.handle_dotted_stmt:
    call emit_dotted_statement
    jmp .stmt_loop
; ==============================================================================
; STAGE 2C-3: UNIVERSAL FLUID & TYPED ASSIGNMENTS
; ==============================================================================
.assign_var:
    call register_symbol            ; Returns symbol index in EDX
    cmp byte [sym_deleted + rdx], 1
    je .err_deleted_access
    cmp byte [sym_const_lock + rdx], 1
    je .const_reassign_error
    push rdx
    add rsi, 16                     ; Skip <ident> and '='

    ; Check if variable is a custom type being assigned comma-packed custom literals:
    cmp byte [sym_type_tag + rdx], TYPE_CUSTOM
    jne .eval_scalar_rhs
    cmp byte [rsi], TOK_KW_NULL
    je .eval_scalar_rhs
    cmp byte [rsi], TOK_IDENT
    je .eval_scalar_rhs
    pop rdx
    mov ecx, [sym_custom_idx + rdx*4]
    call emit_pack_custom_def
    jmp .stmt_loop

.eval_scalar_rhs:
    call eval_expr                  ; Evaluates RHS -> RAX, sets [expr_type_tag] & [expr_custom_idx]
    pop rdx
    ; If RHS is another custom primitive variable (e.g., fluid x = my_rect), copy all 16 bytes!
    cmp dword [expr_type_tag], TYPE_CUSTOM
    jne .store_rhs_value
    mov ecx, [expr_custom_idx]
    mov [sym_custom_idx + rdx*4], ecx
    call emit_copy_custom_to_symbol
    jmp .stmt_loop

.store_rhs_value:
    mov dword [sym_custom_idx + rdx*4], -1
    mov bl, byte [expr_type_tag]
    call emit_store_typed_symbol    ; Updates both payload (0 if null!) and runtime tag at +16!
    jmp .stmt_loop

; --- Array Element Assignment: arr[i] = expr ---
.assign_array:
    push rax
    add rsi, 16                     ; Skip <ident> and '['
    call eval_expr                  ; Index -> RAX
    mov byte [rdi], 0x50            ; push rax
    inc rdi
    cmp byte [rsi], TOK_RBRACK
    jne .arr_wr_chk_eq
    add rsi, 8
.arr_wr_chk_eq:
    cmp byte [rsi], TOK_ASSIGN
    jne .arr_wr_eval_rhs
    add rsi, 8
.arr_wr_eval_rhs:
    call eval_expr                  ; RHS value -> RAX
    mov byte [rdi], 0x59            ; pop rcx (index)
    inc rdi
    pop rax
    call lookup_symbol
    call emit_array_elem_write
    jmp .stmt_loop

.const_reassign_error:
    lea rcx, [err_const_msg]
    call print_cstr
    mov eax, 1
    ret

.err_deleted_access:
    lea rcx, [err_del_msg]
    call print_cstr
    mov eax, 1
    ret
; ==============================================================================
; STAGE 2D-1A: 64-BIT EXPRESSION EVALUATOR (ADDITIVE & SPATIAL '->' TIERS)
; ==============================================================================
eval_expr:
    ; Fast-path compile-time constant folding for <TOK_INT> <op> <TOK_INT>
    cmp byte [rsi], TOK_INT
    jne .eval_add_runtime
    mov al, [rsi+8]
    cmp al, TOK_PLUS
    je .chk_fold_add
    cmp al, TOK_MINUS
    je .chk_fold_sub
    jmp .eval_add_runtime

.chk_fold_add:
    cmp byte [rsi+16], TOK_INT
    jne .eval_add_runtime
    mov eax, [rsi+4]
    add eax, [rsi+20]
    add rsi, 24
    mov byte [rdi], 0xB8            ; mov eax, folded_imm32
    mov [rdi+1], eax
    add rdi, 5
    mov dword [expr_type_tag], TYPE_INT
    jmp .add_loop

.chk_fold_sub:
    cmp byte [rsi+16], TOK_INT
    jne .eval_add_runtime
    mov eax, [rsi+4]
    sub eax, [rsi+20]
    add rsi, 24
    mov byte [rdi], 0xB8
    mov [rdi+1], eax
    add rdi, 5
    mov dword [expr_type_tag], TYPE_INT
    jmp .add_loop

.eval_add_runtime:
    call eval_mul                   ; Left operand -> RAX

.add_loop:
    mov bl, [rsi]
    cmp bl, TOK_PLUS
    je .do_add
    cmp bl, TOK_MINUS
    je .do_sub
    cmp bl, TOK_ARROW
    je .do_arrow
    ret

.do_add:
    add rsi, 8
    ; Fast immediate add if RHS is TOK_INT: add rax, imm32 (48 05 <imm32>)
    cmp byte [rsi], TOK_INT
    jne .do_add_reg
    mov eax, [rsi+4]
    add rsi, 8
    mov word [rdi], 0x0548
    mov [rdi+2], eax
    add rdi, 6
    mov dword [expr_type_tag], TYPE_INT
    jmp .add_loop
.do_add_reg:
    mov byte [rdi], 0x50            ; push rax
    inc rdi
    call eval_mul
    mov dword [rdi], 0xD801485B     ; pop rbx; add rax, rbx
    add rdi, 4
    mov dword [expr_type_tag], TYPE_INT
    jmp .add_loop

.do_sub:
    add rsi, 8
    ; Fast immediate sub if RHS is TOK_INT: sub rax, imm32 (48 2D <imm32>)
    cmp byte [rsi], TOK_INT
    jne .do_sub_reg
    mov eax, [rsi+4]
    add rsi, 8
    mov word [rdi], 0x2D48
    mov [rdi+2], eax
    add rdi, 6
    mov dword [expr_type_tag], TYPE_INT
    jmp .add_loop
.do_sub_reg:
    mov byte [rdi], 0x50            ; push rax
    inc rdi
    call eval_mul
    mov dword [rdi], 0x58C38948     ; mov rbx, rax; pop rax
    mov dword [rdi+4], 0x00D82948   ; sub rax, rbx
    add rdi, 7
    mov dword [expr_type_tag], TYPE_INT
    jmp .add_loop

; --- Spatial Collision Operator: p_rect -> target (4-Edge AABB Overlap Check) ---
.do_arrow:
    add rsi, 8
    mov byte [rdi], 0x50            ; push rax (rect A ptr)
    inc rdi
    call eval_mul                   ; target B ptr -> RAX
    mov byte [rdi], 0x5B            ; pop rbx (rect A ptr)
    mov dword [rdi+1], 0x0B2C0FF3   ; cvttss2si ecx, dword [rbx]
    mov dword [rdi+5], 0x532C0FF3   ; cvttss2si edx, dword [rbx+4]
    mov byte [rdi+9], 0x04
    mov dword [rdi+10], 0x08438B44  ; mov r8d, [rbx+8]
    mov dword [rdi+14], 0x0C4B8B44  ; mov r9d, [rbx+12]
    add rdi, 18
    call emit_aabb_collision_check
    mov dword [expr_type_tag], TYPE_INT
    jmp .add_loop
; ==============================================================================
; STAGE 2D-1B: MULTIPLICATIVE TIER (*, \, %) WITH CONSTANT FOLDING & SHIFTS
; ==============================================================================
eval_mul:
    cmp byte [rsi], TOK_INT
    jne .eval_mul_runtime
    mov al, [rsi+8]
    cmp al, TOK_MUL
    je .chk_fold_mul
    cmp al, TOK_DIV
    je .chk_fold_div
    cmp al, TOK_MOD
    je .chk_fold_mod
    jmp .eval_mul_runtime

.chk_fold_mul:
    cmp byte [rsi+16], TOK_INT
    jne .eval_mul_runtime
    mov eax, [rsi+4]
    imul eax, [rsi+20]
    add rsi, 24
    mov byte [rdi], 0xB8
    mov [rdi+1], eax
    add rdi, 5
    mov dword [expr_type_tag], TYPE_INT
    jmp .mul_loop

.chk_fold_div:
    cmp byte [rsi+16], TOK_INT
    jne .eval_mul_runtime
    mov ecx, [rsi+20]
    test ecx, ecx
    jz .eval_mul_runtime
    mov eax, [rsi+4]
    cdq
    idiv ecx
    add rsi, 24
    mov byte [rdi], 0xB8
    mov [rdi+1], eax
    add rdi, 5
    mov dword [expr_type_tag], TYPE_INT
    jmp .mul_loop

.chk_fold_mod:
    cmp byte [rsi+16], TOK_INT
    jne .eval_mul_runtime
    mov ecx, [rsi+20]
    test ecx, ecx
    jz .eval_mul_runtime
    mov eax, [rsi+4]
    cdq
    idiv ecx
    add rsi, 24
    mov byte [rdi], 0xB8
    mov [rdi+1], edx
    add rdi, 5
    mov dword [expr_type_tag], TYPE_INT
    jmp .mul_loop

.eval_mul_runtime:
    call eval_term

.mul_loop:
    mov bl, [rsi]
    cmp bl, TOK_MUL
    je .do_mul
    cmp bl, TOK_DIV
    je .do_div
    cmp bl, TOK_MOD
    je .do_mod
    ret

.do_mul:
    add rsi, 8
    ; Fast immediate imul if RHS is TOK_INT: imul rax, rax, imm32 (48 69 C0 <imm32>)
    cmp byte [rsi], TOK_INT
    jne .do_mul_reg
    mov eax, [rsi+4]
    add rsi, 8
    mov dword [rdi], 0x00C06948
    mov [rdi+3], eax
    add rdi, 7
    mov dword [expr_type_tag], TYPE_INT
    jmp .mul_loop
.do_mul_reg:
    mov byte [rdi], 0x50
    inc rdi
    call eval_term
    mov dword [rdi], 0xAF0F485B     ; pop rbx; imul rax, rbx
    mov byte [rdi+4], 0xC3
    add rdi, 5
    mov dword [expr_type_tag], TYPE_INT
    jmp .mul_loop

.do_div:
    add rsi, 8
    ; Power-of-2 strength reduction: if RHS is 2^k, emit 1-cycle 'sar rax, k' instead of idiv!
    cmp byte [rsi], TOK_INT
    jne .do_div_reg
    mov eax, [rsi+4]
    test eax, eax
    jle .do_div_reg
    mov ecx, eax
    dec ecx
    test eax, ecx
    jnz .do_div_reg
    bsf ecx, eax                    ; Bit index k = log2(imm)
    add rsi, 8
    mov dword [rdi], 0x00F8C148     ; sar rax, imm8 (48 C1 F8 <imm8>)
    mov [rdi+3], cl
    add rdi, 4
    mov dword [expr_type_tag], TYPE_INT
    jmp .mul_loop
.do_div_reg:
    mov byte [rdi], 0x50
    inc rdi
    call eval_term
    mov dword [rdi], 0x58C38948     ; mov rbx, rax; pop rax
    mov dword [rdi+4], 0xF7489948   ; cqo; idiv rbx
    mov byte [rdi+8], 0xFB
    add rdi, 9
    mov dword [expr_type_tag], TYPE_INT
    jmp .mul_loop

.do_mod:
    add rsi, 8
    ; Power-of-2 strength reduction: if RHS is 2^k, emit 1-cycle 'and eax, (2^k - 1)'!
    cmp byte [rsi], TOK_INT
    jne .do_mod_reg
    mov eax, [rsi+4]
    test eax, eax
    jle .do_mod_reg
    mov ecx, eax
    dec ecx
    test eax, ecx
    jnz .do_mod_reg
    add rsi, 8
    mov byte [rdi], 0x25            ; and eax, imm32 (25 <imm32>)
    mov [rdi+1], ecx
    add rdi, 5
    mov dword [expr_type_tag], TYPE_INT
    jmp .mul_loop
.do_mod_reg:
    mov byte [rdi], 0x50
    inc rdi
    call eval_term
    mov dword [rdi], 0x58C38948
    mov dword [rdi+4], 0xF7489948
    mov dword [rdi+8], 0xD08948FB
    add rdi, 12
    mov dword [expr_type_tag], TYPE_INT
    jmp .mul_loop
; ==============================================================================
; STAGE 2D-2: PRIMARY TERM EVALUATOR (eval_term)
; ==============================================================================
eval_term:
    mov al, [rsi]
    cmp al, TOK_LPAREN
    je .term_parens
    cmp al, TOK_INT
    je .term_int
    cmp al, TOK_FLOAT
    je .term_float
    cmp al, TOK_CHAR
    je .term_char
    cmp al, TOK_STR
    je .term_str
    cmp al, TOK_KW_TRUE
    je .term_true
    cmp al, TOK_KW_FALSE
    je .term_false
    cmp al, TOK_KW_NULL
    je .term_null
    cmp al, TOK_KW_THIS
    je .term_this_or_parent
    cmp al, TOK_KW_PARENT
    je .term_this_or_parent
    cmp al, TOK_IDENT
    je .term_ident
    add rsi, 8
    ret

.term_parens:
    add rsi, 8
    call eval_expr
    cmp byte [rsi], TOK_RPAREN
    jne .parens_done
    add rsi, 8
.parens_done:
    ret

.term_int:
    mov eax, [rsi+4]
    mov byte [rdi], 0xB8
    mov [rdi+1], eax
    add rdi, 5
    add rsi, 8
    mov dword [expr_type_tag], TYPE_INT
    mov dword [expr_custom_idx], -1
    ret

.term_float:
    mov eax, [rsi+4]
    mov byte [rdi], 0xB8
    mov [rdi+1], eax
    add rdi, 5
    add rsi, 8
    mov dword [expr_type_tag], TYPE_FLOAT
    mov dword [expr_custom_idx], -1
    ret

.term_char:
    mov eax, [rsi+4]
    mov byte [rdi], 0xB8
    mov [rdi+1], eax
    add rdi, 5
    add rsi, 8
    mov dword [expr_type_tag], TYPE_CHR
    mov dword [expr_custom_idx], -1
    ret

.term_str:
    mov eax, [rsi+4]
    mov edx, [str_len_table + rax*4]
    mov [last_str_len], edx
    add eax, 0x6000
    mov dword [rdi], 0x00058D48
    mov rdx, rdi
    sub rdx, code_buffer
    add rdx, 0x1007
    sub eax, edx
    mov [rdi+3], eax
    add rdi, 7
    add rsi, 8
    mov dword [expr_type_tag], TYPE_STR
    mov dword [expr_custom_idx], -1
    ret

.term_true:
    mov byte [rdi], 0xB8
    mov dword [rdi+1], 1
    add rdi, 5
    add rsi, 8
    mov dword [expr_type_tag], TYPE_INT
    mov dword [expr_custom_idx], -1
    ret

.term_false:
    mov word [rdi], 0xC031
    add rdi, 2
    add rsi, 8
    mov dword [expr_type_tag], TYPE_INT
    mov dword [expr_custom_idx], -1
    ret

.term_null:
    mov word [rdi], 0xC031          ; xor eax, eax
    add rdi, 2
    add rsi, 8
    mov dword [expr_type_tag], TYPE_NULL
    mov dword [expr_custom_idx], -1
    ret

.term_this_or_parent:
    call eval_dotted_expr
    ret

.term_ident:
    mov eax, [rsi+4]
    lea r9, [str_pool + rax]

    cmp dword [r9], 'get_'
    je .eval_get_intrinsic
    cmp dword [r9], 'str'
    jne .chk_vars_in_cls
    cmp byte [r9+3], 0
    je .eval_str_mutate
.chk_vars_in_cls:
    cmp dword [r9], 'vars'
    je .eval_vars_in_class

    cmp byte [rsi+8], TOK_DOT
    je .eval_dotted_ident
    cmp byte [rsi+8], TOK_LPAREN
    je .eval_fn_call_expr
    cmp byte [rsi+8], TOK_LBRACK
    je .eval_array_read_expr

    ; Standard variable read
    add rsi, 8
    call lookup_symbol
    cmp edx, -1
    je .term_unknown_ident
    cmp byte [sym_deleted + rdx], 1
    je .term_deleted_ident
    movzx eax, byte [sym_type_tag + rdx]
    mov [expr_type_tag], eax
    mov eax, [sym_custom_idx + rdx*4]
    mov [expr_custom_idx], eax
    cmp byte [expr_type_tag], TYPE_CUSTOM
    je .load_custom_addr
    call emit_load_symbol_rax
    ret
.load_custom_addr:
    call emit_lea_symbol_rax
    ret
.term_unknown_ident:
    mov word [rdi], 0xC031
    add rdi, 2
    ret
.term_deleted_ident:
    lea rcx, [err_del_msg]
    call print_cstr
    mov word [rdi], 0xC031
    add rdi, 2
    ret

.eval_get_intrinsic:
    cmp dword [r9+4], 'key'
    je .call_get_key
    cmp dword [r9+4], 'mous'
    je .call_get_mouse_pos
    cmp dword [r9+4], 'cloc'
    je .call_get_clock
    cmp dword [r9+4], 'firs'
    je .call_get_first_char
    add rsi, 8
    ret

.call_get_key:
    add rsi, 8
    cmp byte [rsi], TOK_LPAREN
    jne .emit_key_scan
    add rsi, 16
.emit_key_scan:
    call emit_get_key_syscall
    mov dword [expr_type_tag], TYPE_CHR
    ret

.call_get_mouse_pos:
    add rsi, 8
    cmp byte [rsi], TOK_LPAREN
    jne .emit_mouse_pos
    add rsi, 16
.emit_mouse_pos:
    call emit_get_mouse_pos_syscall
    mov dword [expr_type_tag], TYPE_ARRAY
    ret

.call_get_clock:
    add rsi, 8
    cmp byte [rsi], TOK_LPAREN
    jne .emit_qpc
    add rsi, 16
.emit_qpc:
    mov dword [rdi], 0x20EC8348
    mov dword [rdi+4], 0xF84D8D48
    add rdi, 8
    mov edx, IAT_QPC
    call emit_iat_call
    mov dword [rdi], 0x20C48348
    mov dword [rdi+4], 0xF8458B48
    add rdi, 8
    mov dword [expr_type_tag], TYPE_INT
    ret

.call_get_first_char:
    add rsi, 16
    call eval_expr
    cmp byte [rsi], TOK_RPAREN
    jne .emit_first_byte
    add rsi, 8
.emit_first_byte:
    mov word [rdi], 0xB60F
    mov byte [rdi+2], 0x00
    add rdi, 3
    mov dword [expr_type_tag], TYPE_CHR
    ret

.eval_str_mutate:
    add rsi, 16
    call emit_mutate_to_string
    cmp byte [rsi], TOK_RPAREN
    jne .str_mut_done
    add rsi, 8
.str_mut_done:
    mov dword [expr_type_tag], TYPE_STR
    ret

.eval_vars_in_class:
    add rsi, 16
    cmp byte [rsi], TOK_IDENT
    jne .vars_cls_done
    mov eax, [rsi+4]
    add rsi, 8
    call lookup_symbol
    call emit_format_active_vars
.vars_cls_done:
    cmp byte [rsi], TOK_RPAREN
    jne .vars_cls_ret
    add rsi, 8
.vars_cls_ret:
    mov dword [expr_type_tag], TYPE_STR
    ret

.eval_dotted_ident:
    call eval_dotted_expr
    ret

.eval_array_read_expr:
    mov eax, [rsi+4]
    push rax
    add rsi, 16
    call eval_expr
    cmp byte [rsi], TOK_RBRACK
    jne .arr_rd_lookup
    add rsi, 8
.arr_rd_lookup:
    pop rax
    call lookup_symbol
    mov dword [rdi], 0xF8458948     ; mov [rbp - 8], rax
    add rdi, 4
    call emit_load_symbol_rax
    mov dword [rdi], 0xF84D8B48     ; mov rcx, [rbp - 8]
    mov dword [rdi+4], 0xC8448B48   ; mov rax, [rax + rcx*8 + 8]
    mov byte [rdi+8], 0x08
    add rdi, 9
    mov dword [expr_type_tag], TYPE_INT
    ret

.eval_fn_call_expr:
    mov eax, [rsi+4]
    push rax
    add rsi, 16
    xor r12d, r12d
.fn_arg_loop:
    cmp byte [rsi], TOK_RPAREN
    je .fn_args_done
    cmp byte [rsi], TOK_EOF
    je .fn_args_done
    call eval_expr
    mov byte [rdi], 0x50
    inc rdi
    inc r12d
    cmp byte [rsi], TOK_COMMA
    jne .fn_arg_loop
    add rsi, 8
    jmp .fn_arg_loop
.fn_args_done:
    cmp byte [rsi], TOK_RPAREN
    jne .fn_pop_args
    add rsi, 8
.fn_pop_args:
    cmp r12d, 4
    jl .fn_c3
    mov word [rdi], 0x5941
    add rdi, 2
.fn_c3:
    cmp r12d, 3
    jl .fn_c2
    mov word [rdi], 0x5841
    add rdi, 2
.fn_c2:
    cmp r12d, 2
    jl .fn_c1
    mov byte [rdi], 0x5A
    inc rdi
.fn_c1:
    cmp r12d, 1
    jl .fn_do_call
    mov byte [rdi], 0x59
    inc rdi
.fn_do_call:
    pop rax
    call lookup_fn
    mov dword [rdi], 0x20EC8348
    add rdi, 4
    mov byte [rdi], 0xE8
    lea r8, [code_buffer + rax]
    mov rax, r8
    sub rax, rdi
    sub eax, 5
    mov [rdi+1], eax
    add rdi, 5
    mov dword [rdi], 0x20C48348
    add rdi, 4
    mov dword [expr_type_tag], TYPE_INT
    ret
; ==============================================================================
; STAGE 2E-1: WIN32 SYSCALLS (terminal_add, wait, create_file, & delete_file)
; ==============================================================================

; --- Built-in Syscall: terminal_add(val) ---
call_terminal_add:
.call_terminal_add:
    add rsi, 16                     ; Skip 'terminal_add' and '('
    call eval_expr                  ; Evaluates argument -> RAX, sets [expr_type_tag]

    mov ecx, [expr_type_tag]
    cmp ecx, TYPE_ARRAY
    je .term_print_array
    cmp ecx, TYPE_INT
    je .term_print_int
    cmp ecx, TYPE_CHR
    je .term_print_char

    ; Default: TYPE_STR (RAX = pointer to null-terminated string)
    call emit_write_cstr_rax
    jmp skip_to_nl

.term_print_char:
    mov edx, BSS_KEY_BUF + 4
    call emit_lea_rdx_rva
    mov word [rdi], 0x0288          ; mov [rdx], al
    mov byte [rdi+2], 0xC6
    mov word [rdi+3], 0x0042        ; mov byte [rdx+1], 0
    mov byte [rdi+5], 0x01
    mov dword [rdi+6], 0xD08948     ; mov rax, rdx
    add rdi, 9
    call emit_write_cstr_rax
    jmp skip_to_nl

.term_print_int:
    call emit_int_to_str_rax
    call emit_write_cstr_rax
    jmp skip_to_nl

.term_print_array:
    call emit_print_array_rax
    jmp skip_to_nl

; --- Built-in Syscall: wait(ms) ---
call_wait:
    add rsi, 16                     ; Skip 'wait' and '('
    call eval_expr                  ; ms -> EAX
    mov word [rdi], 0xC189          ; mov ecx, eax
    mov dword [rdi+2], 0x20EC8348   ; sub rsp, 32
    add rdi, 6
    mov edx, IAT_SLEEP
    call emit_iat_call
    mov dword [rdi], 0x20C48348     ; add rsp, 32
    add rdi, 4
    jmp skip_to_nl

; --- Built-in Syscall: create_file(path, filename, fileending) ---
call_create_file:
    add rsi, 16                     ; Skip 'create_file' and '('
    call eval_expr                  ; arg1: path str ptr -> RAX
    mov byte [rdi], 0x50            ; push rax (path)
    inc rdi
    cmp byte [rsi], TOK_COMMA
    jne .cf_arg2
    add rsi, 8
.cf_arg2:
    call eval_expr                  ; arg2: filename str ptr -> RAX
    mov byte [rdi], 0x50            ; push rax (filename)
    inc rdi
    cmp byte [rsi], TOK_COMMA
    jne .cf_arg3
    add rsi, 8
.cf_arg3:
    call eval_expr                  ; arg3: fileending str ptr -> RAX
    ; mov r10, rax (49 89 C2), pop r9 (41 59), pop r8 (41 58)
    mov dword [rdi], 0x41C28949
    mov word [rdi+4], 0x4159
    mov byte [rdi+6], 0x58
    add rdi, 7

    ; Assemble full path into BSS_PATH_BUF using R11 as write cursor
    mov edx, BSS_PATH_BUF
    call emit_lea_rax_rva
    mov dword [rdi], 0x00C38949     ; mov r11, rax
    add rdi, 3

    call emit_append_r8_to_r11
    call emit_append_r9_to_r11
    ; Write '.' and copy R10: mov byte [r11], '.' (41 C6 03 2E), inc r11 (49 FF C3), mov r8, r10 (4D 89 D0)
    mov dword [rdi], 0x2E03C641
    mov dword [rdi+4], 0x4DC3FF49
    mov word [rdi+8], 0xD089
    add rdi, 10
    call emit_append_r8_to_r11
    ; Null-terminate: mov byte [r11], 0 (41 C6 03 00)
    mov dword [rdi], 0x0003C641
    add rdi, 4

    ; CreateFileA(BSS_PATH_BUF, GENERIC_WRITE=0x40000000, 0, 0, CREATE_ALWAYS=2, FILE_ATTRIBUTE_NORMAL=0x80, 0)
    mov dword [rdi], 0x40EC8348
    add rdi, 4
    mov edx, BSS_PATH_BUF
    call emit_lea_rcx_rva
    mov byte [rdi], 0xBA
    mov dword [rdi+1], 0x40000000
    mov dword [rdi+5], 0x45C03145
    mov word [rdi+9], 0xC931
    mov dword [rdi+11], 0x2444C748
    mov dword [rdi+15], 0x00000220
    mov byte [rdi+19], 0x00
    mov dword [rdi+20], 0x2444C748
    mov dword [rdi+24], 0x00008028
    mov byte [rdi+28], 0x00
    mov dword [rdi+29], 0x2444C748
    mov dword [rdi+33], 0x00000030
    mov byte [rdi+37], 0x00
    add rdi, 38
    mov edx, IAT_CREATE_FILE
    call emit_iat_call

    ; CloseHandle(rax)
    mov dword [rdi], 0x00C18948
    add rdi, 3
    mov edx, IAT_CLOSE_HANDLE
    call emit_iat_call
    mov dword [rdi], 0x40C48348
    add rdi, 4
    jmp skip_to_nl

; --- Built-in Syscall: delete_file(path) ---
call_delete_file:
    add rsi, 16                     ; Skip 'delete_file' and '('
    call eval_expr                  ; path str ptr -> RAX
    ; mov rcx, rax (48 89 C1), sub rsp, 32 (48 83 EC 20), call [IAT_DELETE_FILE], add rsp, 32
    mov dword [rdi], 0x48C18948
    mov dword [rdi+4], 0x0020EC83
    add rdi, 7
    mov edx, IAT_DELETE_FILE
    call emit_iat_call
    mov dword [rdi], 0x20C48348
    add rdi, 4
    jmp skip_to_nl
; ==============================================================================
; STAGE 2E-2: WIN32 WINDOW, OVERLOADED DRAW, DRAW_TRI ([]3), & DRAW_LINE
; ==============================================================================

; --- Built-in Syscall: window(w, h) ---
call_window:
    add rsi, 16                     ; Skip 'window' and '('
    call eval_expr                  ; width -> RAX
    mov edx, BSS_WIN_W
    call emit_store_bss_rax
    cmp byte [rsi], TOK_COMMA
    jne .win_eval_h
    add rsi, 8
.win_eval_h:
    call eval_expr                  ; height -> RAX
    mov edx, BSS_WIN_H
    call emit_store_bss_rax

    mov dword [rdi], 0x60EC8348     ; sub rsp, 96
    add rdi, 4
    mov word [rdi], 0xC931          ; xor ecx, ecx
    add rdi, 2
    mov edx, RODATA_STATIC_CLS
    call emit_lea_rdx_rva
    mov edx, RODATA_WIN_TITLE
    call emit_lea_r8_rva
    mov word [rdi], 0xB941
    mov dword [rdi+2], 0x10CF0000
    add rdi, 6

    mov dword [rdi], 0x2444C748
    mov dword [rdi+4], 0x00006420   ; [rsp+32] = 100
    mov dword [rdi+8], 0x2444C748
    mov dword [rdi+12], 0x00006428  ; [rsp+40] = 100
    add rdi, 16

    mov edx, BSS_WIN_W
    call emit_load_bss_rax
    mov dword [rdi], 0x24448948     ; mov [rsp+48], rax
    mov byte [rdi+4], 0x30
    add rdi, 5

    mov edx, BSS_WIN_H
    call emit_load_bss_rax
    mov dword [rdi], 0x24448948     ; mov [rsp+56], rax
    mov byte [rdi+4], 0x38
    add rdi, 5

    mov dword [rdi], 0x24448948     ; Zero [rsp+64..88]
    mov byte [rdi+4], 0x40
    mov dword [rdi+5], 0x24448948
    mov byte [rdi+9], 0x48
    mov dword [rdi+10], 0x24448948
    mov byte [rdi+14], 0x50
    mov dword [rdi+15], 0x24448948
    mov byte [rdi+19], 0x58
    add rdi, 20

    mov edx, IAT_CREATE_WIN
    call emit_iat_call
    mov edx, BSS_HWND
    call emit_store_bss_rax

    mov dword [rdi], 0x00C18948
    add rdi, 3
    mov edx, IAT_GET_DC
    call emit_iat_call
    mov edx, BSS_HDC
    call emit_store_bss_rax

    mov dword [rdi], 0x60C48348
    add rdi, 4

    ; Initialize 40-byte BITMAPINFOHEADER at BSS_BMI using dynamic BSS_WIN_W & -BSS_WIN_H
    mov edx, BSS_BMI
    call emit_lea_rax_rva
    mov dword [rdi], 0x000000C7     ; biSize = 40
    mov word [rdi+4], 0x0028
    mov dword [rdi+6], 0x000C40C7   ; biPlanes = 1, biBitCount = 32
    mov word [rdi+10], 0x0001
    mov word [rdi+12], 0x0020
    add rdi, 14

    mov edx, BSS_WIN_W
    call emit_load_bss_rax
    mov edx, BSS_BMI
    call emit_lea_rdx_rva
    mov dword [rdi], 0x00044289     ; mov [rdx+4], eax (biWidth)
    add rdi, 3

    mov edx, BSS_WIN_H
    call emit_load_bss_rax
    mov edx, BSS_BMI
    call emit_lea_rdx_rva
    mov dword [rdi], 0x4289D8F7     ; neg eax; mov [rdx+8], eax (biHeight = -height top-down)
    mov byte [rdi+4], 0x08
    add rdi, 5
    jmp skip_to_nl

; --- Built-in Syscall: draw(rect, color)  OR  draw(x, y, w, h, color) ---
call_draw:
    add rsi, 16
    call eval_expr
    cmp dword [expr_type_tag], TYPE_CUSTOM
    je .draw_custom_rect

    mov byte [rdi], 0x50
    inc rdi
    mov r12d, 1
.draw5_loop:
    cmp byte [rsi], TOK_COMMA
    jne .draw5_pop
    add rsi, 8
    call eval_expr
    mov byte [rdi], 0x50
    inc rdi
    inc r12d
    cmp r12d, 5
    jl .draw5_loop
.draw5_pop:
    mov word [rdi], 0x5B41          ; pop r11 (color)
    mov word [rdi+2], 0x5A41        ; pop r10 (h)
    mov word [rdi+4], 0x5941        ; pop r9  (w)
    mov word [rdi+6], 0x5841        ; pop r8  (y)
    mov byte [rdi+8], 0x59          ; pop rcx (x)
    add rdi, 9
    jmp .draw_rect_blit

.draw_custom_rect:
    mov byte [rdi], 0x50
    inc rdi
    cmp byte [rsi], TOK_COMMA
    jne .draw_rect_color
    add rsi, 8
.draw_rect_color:
    call eval_expr
    mov dword [rdi], 0x5BC38941
    mov dword [rdi+4], 0x0B2C0FF3
    mov dword [rdi+8], 0x2C0F44F3
    mov word [rdi+12], 0x0443
    mov dword [rdi+14], 0x084B8B44
    mov dword [rdi+18], 0x0C538B44
    add rdi, 22

.draw_rect_blit:
    call emit_rasterize_rect_and_blit
    jmp skip_to_nl

; --- Built-in Syscall: draw_tri(tri_array_3 [, color])  OR  draw_tri(p1, p2, p3 [, color]) ---
call_draw_tri :
    add rsi, 16                     ; Skip 'draw_tri' and '('
    call eval_expr                  ; First arg -> RAX, sets [expr_type_tag]
    cmp dword [expr_type_tag], TYPE_ARRAY
    je .tri_from_array3

    ; 3-vertex form: draw_tri(p1, p2, p3 [, color])
    mov byte [rdi], 0x50            ; push p1
    inc rdi
    cmp byte [rsi], TOK_COMMA
    jne .tri_v2
    add rsi, 8
.tri_v2:
    call eval_expr                  ; p2
    mov byte [rdi], 0x50
    inc rdi
    cmp byte [rsi], TOK_COMMA
    jne .tri_v3
    add rsi, 8
.tri_v3:
    call eval_expr                  ; p3
    mov byte [rdi], 0x50
    inc rdi
    mov eax, 0xFFFFFF
    mov byte [rdi], 0xB8
    mov [rdi+1], eax
    add rdi, 5
    cmp byte [rsi], TOK_COMMA
    jne .tri_pop_verts
    add rsi, 8
    call eval_expr                  ; color -> RAX
.tri_pop_verts:
    mov dword [rdi], 0x59C38941
    mov dword [rdi+4], 0x5A584141
    add rdi, 8
    call emit_rasterize_triangle_and_blit
    jmp skip_to_nl

.tri_from_array3:
    mov byte [rdi], 0x50            ; push tri_arr_ptr
    inc rdi
    mov eax, 0xFFFFFF               ; Default white 0xFFFFFF
    mov byte [rdi], 0xB8
    mov [rdi+1], eax
    add rdi, 5
    cmp byte [rsi], TOK_COMMA
    jne .tri_unpack_arr3
    add rsi, 8
    call eval_expr                  ; Optional color -> RAX
.tri_unpack_arr3:
    mov dword [rdi], 0x58C38941
    mov dword [rdi+4], 0x08508B48
    mov dword [rdi+8], 0x10408B4C
    mov dword [rdi+12], 0x18488B4C
    add rdi, 16
    call emit_rasterize_triangle_and_blit
    jmp skip_to_nl

; --- Built-in Syscall: draw_line(p1, p2 [, color]) ---
call_draw_line:
    add rsi, 16                     ; Skip 'draw_line' and '('
    call eval_expr                  ; p1 -> RAX
    mov byte [rdi], 0x50            ; push p1
    inc rdi
    cmp byte [rsi], TOK_COMMA
    jne .line_p2
    add rsi, 8
.line_p2:
    call eval_expr                  ; p2 -> RAX
    mov byte [rdi], 0x50            ; push p2
    inc rdi
    mov eax, 0xFFFFFF               ; Default white 0xFFFFFF
    mov byte [rdi], 0xB8
    mov [rdi+1], eax
    add rdi, 5
    cmp byte [rsi], TOK_COMMA
    jne .line_pop_pts
    add rsi, 8
    call eval_expr                  ; Optional color -> RAX
.line_pop_pts:
    mov dword [rdi], 0x58C38941
    mov word [rdi+4], 0x5A41
    add rdi, 6
    call emit_rasterize_line_and_blit
    jmp skip_to_nl
; ==============================================================================
; STAGE 2E-3: ENTRY PATCHER & CONDITION EVALUATOR (if x == int / rect / null)
; ==============================================================================

; --- Program End: Verify top-level 'fn main' exists & patch entry call at +5 ---
finish_program:
.finish_program:
    mov eax, [main_code_off]
    cmp eax, -1
    je .missing_main
    sub eax, 9
    mov dword [code_buffer + 5], eax
    xor eax, eax
    ret

.missing_main:
    lea rcx, [err_main_msg]
    call print_cstr
    mov eax, 1
    ret

; --- Condition Evaluator for 'if' and 'while' ---
; Supports:
;   1. Truthy expressions: if p_rect -> edge {  /  while true {
;   2. Runtime type introspection: if x == int { / if x == rect { / if x == null {
;   3. Standard 64-bit value comparisons: ==, <, >
emit_condition:
    ; Peek ahead to check for '<ident> == <type_keyword | custom_def_name | null>'
    cmp byte [rsi], TOK_IDENT
    jne .std_cond_eval
    cmp byte [rsi+8], TOK_EQ
    jne .std_cond_eval

    mov bl, [rsi+16]                ; RHS token type after '=='
    cmp bl, TOK_KW_INT
    je .cond_type_kw
    cmp bl, TOK_KW_FLOAT
    je .cond_type_kw
    cmp bl, TOK_KW_STR
    je .cond_type_kw
    cmp bl, TOK_KW_CHR
    je .cond_type_kw
    cmp bl, TOK_KW_ARRAY
    je .cond_type_kw
    cmp bl, TOK_KW_OBJ
    je .cond_type_kw
    cmp bl, TOK_KW_NULL
    je .cond_type_kw
    cmp bl, TOK_IDENT
    jne .std_cond_eval

    ; Check if RHS identifier is a registered custom #define type (e.g., 'rect')
    mov eax, [rsi+20]
    call lookup_custom_def
    cmp ecx, -1
    je .std_cond_eval
    ; Found 'if x == rect'!
    mov eax, [rsi+4]                ; LHS variable name
    add rsi, 24                     ; Advance past 'x == rect'
    call lookup_symbol
    cmp edx, -1
    je .std_cond_zero
    push rcx                        ; Save custom def index
    call emit_load_slot_tag_eax     ; Loads [slot+16] (tag) in AL, [slot+17] (def_idx) in AH
    pop rcx
    ; Compare AX against ((cl << 8) | TYPE_CUSTOM): cmp ax, imm16 (66 3D <imm16>)
    shl ecx, 8
    or ecx, TYPE_CUSTOM
    mov word [rdi], 0x3D66
    mov [rdi+2], cx
    mov word [rdi+4], 0x850F        ; jne rel32
    mov dword [rdi+6], 0
    mov rax, rdi
    sub rax, code_buffer
    add eax, 6
    add rdi, 10
    jmp .skip_cond_lbrace

.cond_type_kw:
    ; Map keyword token BL -> TYPE_* constant in CL
    mov cl, TYPE_NULL
    cmp bl, TOK_KW_INT
    jne .ct_f
    mov cl, TYPE_INT
.ct_f:
    cmp bl, TOK_KW_FLOAT
    jne .ct_s
    mov cl, TYPE_FLOAT
.ct_s:
    cmp bl, TOK_KW_STR
    jne .ct_c
    mov cl, TYPE_STR
.ct_c:
    cmp bl, TOK_KW_CHR
    jne .ct_a
    mov cl, TYPE_CHR
.ct_a:
    cmp bl, TOK_KW_ARRAY
    jne .ct_o
    mov cl, TYPE_ARRAY
.ct_o:
    cmp bl, TOK_KW_OBJ
    jne .ct_emit
    mov cl, TYPE_OBJ
.ct_emit:
    mov eax, [rsi+4]                ; LHS variable name
    add rsi, 24                     ; Advance past 'x == <type>'
    call lookup_symbol
    cmp edx, -1
    je .std_cond_zero
    push rcx
    call emit_load_slot_tag_eax     ; Loads runtime type tag from [slot + 16] into AL
    pop rcx
    ; cmp al, cl (3C <imm8>), jne rel32 (0F 85 <rel32>)
    mov byte [rdi], 0x3C
    mov [rdi+1], cl
    mov word [rdi+2], 0x850F
    mov dword [rdi+4], 0
    mov rax, rdi
    sub rax, code_buffer
    add eax, 4
    add rdi, 8
    jmp .skip_cond_lbrace

.std_cond_zero:
    mov word [rdi], 0xC031
    mov word [rdi+2], 0x840F
    mov dword [rdi+4], 0
    mov rax, rdi
    sub rax, code_buffer
    add eax, 4
    add rdi, 8
    jmp .skip_cond_lbrace

.std_cond_eval:
    call eval_expr                  ; LHS -> RAX
    mov bl, [rsi]
    cmp bl, TOK_LBRACE
    je .truthy_cond
    push rbx
    add rsi, 8
    mov byte [rdi], 0x50            ; push rax
    inc rdi
    call eval_expr                  ; RHS -> RAX
    mov dword [rdi], 0x58C38948     ; mov rbx, rax; pop rax
    mov dword [rdi+4], 0x00D83948   ; cmp rax, rbx
    add rdi, 7
    pop rbx

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
    mov dword [rdi+2], 0
    mov rax, rdi
    sub rax, code_buffer
    add eax, 2
    add rdi, 6

.skip_cond_lbrace:
    cmp byte [rsi], TOK_LBRACE
    jne .cond_done
    add rsi, 8
.cond_done:
    ret

.truthy_cond:
    mov dword [rdi], 0x0FC08548     ; test rax, rax
    mov byte [rdi+4], 0x84          ; jz rel32
    mov dword [rdi+5], 0
    mov rax, rdi
    sub rax, code_buffer
    add eax, 5
    add rdi, 9
    add rsi, 8
    ret
; ==============================================================================
; STAGE 2F-1A: PATH APPENDERS, VERTEX UNPACKER, & DRAW_LINE RASTERIZER
; ==============================================================================

; --- Helper: Copies null-terminated string from R8 into [R11++] (for create_file) ---
emit_append_r8_to_r11:
    ; mov al, [r8] (41 8A 00), test al, al (84 C0), jz +9 (74 09)
    ; mov [r11], al (41 88 03), inc r8 (49 FF C0), inc r11 (49 FF C3), jmp -17 (EB EF)
    mov dword [rdi], 0x84008A41
    mov dword [rdi+4], 0x410974C0
    mov dword [rdi+8], 0xFF490388
    mov dword [rdi+12], 0xC3FF49C0
    mov word [rdi+16], 0xEFEB
    add rdi, 18
    ret

; --- Helper: Copies null-terminated string from R9 into [R11++] (for create_file) ---
emit_append_r9_to_r11:
    ; mov al, [r9] (41 8A 01), test al, al (84 C0), jz +9 (74 09)
    ; mov [r11], al (41 88 03), inc r9 (49 FF C1), inc r11 (49 FF C3), jmp -17 (EB EF)
    mov dword [rdi], 0x84018A41
    mov dword [rdi+4], 0x410974C0
    mov dword [rdi+8], 0xFF490388
    mov dword [rdi+12], 0xC3FF49C1
    mov word [rdi+16], 0xEFEB
    add rdi, 18
    ret

; --- Helper: Unpacks vertex pointer in RAX (either #define {x,y} or []2 array) into (EAX=x, EBX=y) ---
emit_unpack_vertex_rax_to_eax_ebx:
    ; Check if vertex is a []2 array ([rax] == 2 && [rax+4] == 2)
    mov dword [rdi], 0x75023883     ; cmp dword [rax], 2; jne +11
    mov byte [rdi+4], 0x0B
    mov dword [rdi+5], 0x8B10588B   ; mov ebx, [rax+16]; mov eax, [rax+8]
    mov dword [rdi+9], 0xEB0840
    mov byte [rdi+12], 0x16         ; jmp +22
    ; Custom #define point {x, y} at [rax+0], [rax+4]: convert float32 if exponent != 0, else raw int32
    mov dword [rdi+13], 0x8B04588B  ; mov ebx, [rax+4]; mov eax, [rax]
    mov word [rdi+17], 0x3D00
    mov dword [rdi+19], 0x38000000  ; cmp eax, 0x38000000
    mov word [rdi+23], 0x1072       ; jb +16
    mov dword [rdi+25], 0xC06E0F66  ; movd xmm0, eax
    mov dword [rdi+29], 0xC02C0FF3  ; cvttss2si eax, xmm0
    mov dword [rdi+33], 0xC36E0F66  ; movd xmm0, ebx
    mov dword [rdi+37], 0xD82C0FF3  ; cvttss2si ebx, xmm0
    add rdi, 41
    ret

; --- Rasterizes Line from RDX (p1) to R8 (p2) in Color R11D & Blits ---
emit_rasterize_line_and_blit:
    mov word [rdi], 0x5041          ; push r8 (p2)
    mov word [rdi+2], 0x5341        ; push r11 (color)
    mov dword [rdi+4], 0x00D08948   ; mov rax, rdx (p1)
    add rdi, 7
    call emit_unpack_vertex_rax_to_eax_ebx ; EAX = x1, EBX = y1
    mov byte [rdi], 0x50            ; push rax (x1)
    mov byte [rdi+1], 0x53          ; push rbx (y1)
    mov dword [rdi+2], 0x24448B48   ; mov rax, [rsp+24] (p2)
    mov byte [rdi+6], 0x18
    add rdi, 7
    call emit_unpack_vertex_rax_to_eax_ebx ; EAX = x2, EBX = y2
    mov word [rdi], 0x5941          ; pop r9 (y1)
    mov word [rdi+2], 0x5841        ; pop r8 (x1)
    mov word [rdi+4], 0x5B41        ; pop r11 (color)
    mov dword [rdi+6], 0x08C48348   ; add rsp, 8 (pop p2)
    add rdi, 10

    ; Fixed-point 16.16 DDA line drawer (256 steps):
    mov dword [rdi], 0xC1C02944     ; sub eax, r8d; shl eax, 8 (dx_step)
    mov dword [rdi+4], 0x294408E0
    mov dword [rdi+8], 0x08E3C1CB   ; sub ebx, r9d; shl ebx, 8 (dy_step)
    mov dword [rdi+12], 0x10E0C141  ; shl r8d, 16 (cur_x_fp)
    mov dword [rdi+16], 0x10E1C141  ; shl r9d, 16 (cur_y_fp)
    mov dword [rdi+20], 0x00C48941  ; mov r12d, eax (save dx_step)
    add rdi, 23

    mov edx, BSS_WIN_W
    call emit_load_bss_rax
    mov dword [rdi], 0x00E0C148     ; shl rax, 2 (row stride in bytes -> R10)
    mov dword [rdi+3], 0x02C28949   ; mov r10, rax
    add rdi, 7
    mov edx, BSS_FRAMEBUF
    call emit_lea_rax_rva           ; RAX = framebuffer base

    ; Plot 256 pixels along segment:
    mov byte [rdi], 0xB9
    mov dword [rdi+1], 256
    mov dword [rdi+5], 0xC1CA8944   ; mov edx, r9d; shr edx, 16
    mov dword [rdi+9], 0x0F4910EA   ; imul rdx, r10
    mov dword [rdi+13], 0x8944D2AF  ; mov esi, r8d; shr esi, 16
    mov dword [rdi+17], 0x10EEC1C6  ; lea rdx, [rax + rdx]
    mov dword [rdi+21], 0x10148D48  ; mov [rdx + rsi*4], r11d
    mov dword [rdi+25], 0xB21C8944
    mov dword [rdi+29], 0x41E00145  ; add r8d, r12d; add r9d, ebx; dec ecx; jnz
    mov dword [rdi+33], 0xE2FFD901
    add rdi, 37
    call emit_pump_and_blit_framebuffer
    ret
; ==============================================================================
; STAGE 2F-1B: FILLED TRIANGLE RASTERIZER (DRAW_TRI), RECT RASTERIZER, & BLITTER
; ==============================================================================

; --- Rasterizes Filled Triangle (RDX=p1, R8=p2, R9=p3, R11D=color) & Blits ---
emit_rasterize_triangle_and_blit:
    mov byte [rdi], 0x52            ; push rdx (p1)
    mov word [rdi+1], 0x5041        ; push r8 (p2)
    mov word [rdi+3], 0x5141        ; push r9 (p3)
    mov word [rdi+5], 0x5341        ; push r11 (color)
    ; Unpack p1 -> [rbp-8] (x1:i32, y1:i32)
    mov dword [rdi+7], 0x24448B48   ; mov rax, [rsp+24]
    mov byte [rdi+11], 0x18
    add rdi, 12
    call emit_unpack_vertex_rax_to_eax_ebx ; EAX=x1, EBX=y1
    mov dword [rdi], 0xF84589       ; mov [rbp-8], eax
    mov dword [rdi+3], 0xFC5D89     ; mov [rbp-4], ebx
    ; Unpack p2 -> [rbp-16] (x2:i32, y2:i32)
    mov dword [rdi+6], 0x24448B48   ; mov rax, [rsp+16]
    mov byte [rdi+10], 0x10
    add rdi, 11
    call emit_unpack_vertex_rax_to_eax_ebx ; EAX=x2, EBX=y2
    mov dword [rdi], 0xF04589       ; mov [rbp-16], eax
    mov dword [rdi+3], 0xF45D89     ; mov [rbp-12], ebx
    ; Unpack p3 -> (R12D=x3, R13D=y3)
    mov dword [rdi+6], 0x24448B48   ; mov rax, [rsp+8]
    mov byte [rdi+10], 0x08
    add rdi, 11
    call emit_unpack_vertex_rax_to_eax_ebx
    mov dword [rdi], 0x41C48941     ; mov r12d, eax; mov r13d, ebx
    mov word [rdi+4], 0xDD89
    mov word [rdi+6], 0x5B41        ; pop r11 (color)
    mov dword [rdi+8], 0x18C48348   ; add rsp, 24 (discard p1, p2, p3)
    add rdi, 12

    ; Load R8D=x1, R9D=y1, R10D=x2, R14D=y2, R12D=x3, R13D=y3
    mov dword [rdi], 0x8B44F845     ; mov r8d, [rbp-8]
    mov dword [rdi+4], 0x8B44FC4D   ; mov r9d, [rbp-4]
    mov dword [rdi+8], 0x8B44F055   ; mov r10d, [rbp-16]
    mov dword [rdi+12], 0x8B44F475  ; mov r14d, [rbp-12]
    add rdi, 16

    mov edx, BSS_FRAMEBUF
    call emit_lea_rax_rva
    mov byte [rdi], 0xB9
    mov dword [rdi+1], 256          ; 256 interpolation steps across edge p2->p3
    add rdi, 5
    mov r15, rdi                    ; Outer t-loop

    ; Interpolate target point Q on edge p2->p3, then fill segment p1->Q in BSS_FRAMEBUF:
    mov dword [rdi], 0x2944E689
    mov dword [rdi+4], 0xF1AF0FD6
    mov dword [rdi+8], 0x4408FEC1
    mov dword [rdi+12], 0x8944D601
    mov dword [rdi+16], 0xF32944EB
    mov dword [rdi+20], 0xFBC1D9AF
    mov dword [rdi+24], 0xF3014408
    mov dword [rdi+28], 0x44C62944
    mov word [rdi+32], 0xCB29
    mov byte [rdi+34], 0xBA         ; mov edx, 256
    mov dword [rdi+35], 256
    add rdi, 39

    ; Inner s-loop (256 steps from p1 to Q):
    mov dword [rdi], 0x0FF08950
    mov dword [rdi+4], 0xF8C1C2AF
    mov dword [rdi+8], 0xC0014408
    mov dword [rdi+12], 0x0FD98951
    mov dword [rdi+16], 0xF9C1CAAF
    mov dword [rdi+20], 0xC9014408
    mov dword [rdi+24], 0x00C96948
    mov dword [rdi+28], 0x4800000A
    mov dword [rdi+32], 0x0824748B
    mov dword [rdi+36], 0x440E0C8D
    mov dword [rdi+40], 0x59811C89
    mov dword [rdi+44], 0x75CAFF58
    mov byte [rdi+48], 0xCF
    add rdi, 49

    ; dec ecx (FF C9), jnz outer (0F 85 <rel32>)
    mov dword [rdi], 0x850FC9FF
    mov rax, r15
    sub rax, rdi
    sub eax, 8
    mov [rdi+4], eax
    add rdi, 8
    call emit_pump_and_blit_framebuffer
    ret

; --- Rasterizes Filled Rectangle (ECX=x, R8D=y, R9D=w, R10D=h, R11D=color) & Blits ---
emit_rasterize_rect_and_blit:
    mov edx, BSS_FRAMEBUF
    call emit_lea_rax_rva
    mov dword [rdi], 0x7ED28545     ; test r10d, r10d; jle +50
    mov byte [rdi+4], 0x32
    mov dword [rdi+5], 0x48C2894C   ; mov rdx, r8; imul rdx, 2560
    mov dword [rdi+9], 0x000AD269
    mov word [rdi+13], 0x0000
    mov dword [rdi+15], 0x10148D48  ; lea rdx, [rax + rdx]
    mov dword [rdi+19], 0x8A148D48  ; lea rdx, [rdx + rcx*4]
    mov dword [rdi+23], 0x85CB8944  ; mov ebx, r9d; test ebx, ebx
    mov dword [rdi+27], 0x440C7EDB  ; jle +12; mov [rdx], r11d
    mov dword [rdi+31], 0x83481A89
    mov dword [rdi+35], 0xCBFF04C2  ; add rdx, 4; dec ebx
    mov dword [rdi+39], 0xFF49EEEB  ; jmp -16; inc r8
    mov dword [rdi+43], 0xCAFF41C0  ; dec r10d
    mov word [rdi+47], 0xCCEB       ; jmp -52
    add rdi, 49
    call emit_pump_and_blit_framebuffer
    ret

; --- Shared Message Pump (PeekMessageA) & StretchDIBits Blitter ---
emit_pump_and_blit_framebuffer:
    mov dword [rdi], 0x30EC8348
    add rdi, 4
    mov edx, BSS_MSG
    call emit_lea_rcx_rva
    mov dword [rdi], 0x3145D231
    mov dword [rdi+4], 0xC748C931
    mov dword [rdi+8], 0x01202444
    mov dword [rdi+12], 0x000000
    add rdi, 15
    mov edx, IAT_PEEK_MSG
    call emit_iat_call
    mov dword [rdi], 0x30C48348
    add rdi, 4

    mov dword [rdi], 0x70EC8348     ; sub rsp, 112
    add rdi, 4
    mov edx, BSS_HDC
    call emit_load_bss_rax
    mov dword [rdi], 0x31C18948
    mov word [rdi+4], 0xD231
    mov dword [rdi+6], 0x41C03145
    mov dword [rdi+10], 0x000280B9
    mov byte [rdi+14], 0x00
    add rdi, 15

    mov dword [rdi], 0x2444C748
    mov dword [rdi+4], 0x01E020
    mov byte [rdi+7], 0x00
    mov dword [rdi+8], 0x2444C748
    mov dword [rdi+12], 0x000028
    mov byte [rdi+15], 0x00
    mov dword [rdi+16], 0x2444C748
    mov dword [rdi+20], 0x000030
    mov byte [rdi+23], 0x00
    mov dword [rdi+24], 0x2444C748
    mov dword [rdi+28], 0x028038
    mov byte [rdi+31], 0x00
    mov dword [rdi+32], 0x2444C748
    mov dword [rdi+36], 0x01E040
    mov byte [rdi+39], 0x00
    add rdi, 40

    mov edx, BSS_FRAMEBUF
    call emit_lea_rax_rva
    mov dword [rdi], 0x24448948
    mov byte [rdi+4], 0x48
    add rdi, 5

    mov edx, BSS_BMI
    call emit_lea_rax_rva
    mov dword [rdi], 0x24448948
    mov byte [rdi+4], 0x50
    add rdi, 5

    mov dword [rdi], 0x2444C748
    mov dword [rdi+4], 0x000058
    mov byte [rdi+7], 0x00
    mov dword [rdi+8], 0x2444C748
    mov dword [rdi+12], 0x002060
    mov byte [rdi+15], 0xCC
    add rdi, 16

    mov edx, IAT_STRETCH_DIB
    call emit_iat_call
    mov dword [rdi], 0x70C48348
    add rdi, 4
    ret
; ==============================================================================
; STAGE 2F-2: RUNTIME CODE-EMITTER HELPERS (INPUT, 4-EDGE AABB, & #define)
; ==============================================================================

emit_iat_call:
    mov word [rdi], 0x15FF
    mov rax, rdi
    sub rax, code_buffer
    add rax, 0x1006
    sub edx, eax
    mov [rdi+2], edx
    add rdi, 6
    ret

emit_lea_rax_rva:
    mov dword [rdi], 0x00058D48
    mov rax, rdi
    sub rax, code_buffer
    add rax, 0x1007
    sub edx, eax
    mov [rdi+3], edx
    add rdi, 7
    ret

emit_lea_rcx_rva:
    mov dword [rdi], 0x000D8D48
    mov rax, rdi
    sub rax, code_buffer
    add rax, 0x1007
    sub edx, eax
    mov [rdi+3], edx
    add rdi, 7
    ret

emit_lea_rdx_rva:
    mov dword [rdi], 0x00158D48
    mov rax, rdi
    sub rax, code_buffer
    add rax, 0x1007
    sub edx, eax
    mov [rdi+3], edx
    add rdi, 7
    ret

emit_lea_r8_rva:
    mov dword [rdi], 0x00058D4C
    mov rax, rdi
    sub rax, code_buffer
    add rax, 0x1007
    sub edx, eax
    mov [rdi+3], edx
    add rdi, 7
    ret

emit_load_bss_rax:
    mov dword [rdi], 0x00058B48
    mov rax, rdi
    sub rax, code_buffer
    add rax, 0x1007
    sub edx, eax
    mov [rdi+3], edx
    add rdi, 7
    ret

emit_store_bss_rax:
    mov dword [rdi], 0x00058948
    mov rax, rdi
    sub rax, code_buffer
    add rax, 0x1007
    sub edx, eax
    mov [rdi+3], edx
    add rdi, 7
    ret

; --- Bump Heap Allocator: Reserves ECX bytes from BSS_HEAP_PTR -> RAX ---
emit_heap_alloc_imm:
    push rcx
    mov edx, BSS_HEAP_PTR
    call emit_load_bss_rax
    mov dword [rdi], 0x0775C085     ; test rax, rax; jnz +7
    add rdi, 4
    mov edx, BSS_HEAP_ARENA
    call emit_lea_rax_rva
    mov dword [rdi], 0x48C28948     ; mov rdx, rax; add rax, imm32
    mov byte [rdi+4], 0x05
    pop rcx
    mov [rdi+5], ecx
    add rdi, 9
    push rdx
    mov edx, BSS_HEAP_PTR
    call emit_store_bss_rax
    pop rdx
    mov dword [rdi], 0x00D08948     ; mov rax, rdx
    add rdi, 3
    ret

; --- get_key(): scans VK 0x08..0x5A via GetAsyncKeyState -> ASCII char in EAX ---
emit_get_key_syscall:
    mov byte [rdi], 0x53            ; push rbx
    mov dword [rdi+1], 0x28EC8348   ; sub rsp, 40
    mov byte [rdi+5], 0xBB          ; mov ebx, 8
    mov dword [rdi+6], 8
    add rdi, 10
    mov r14, rdi
    mov word [rdi], 0xD989          ; mov ecx, ebx
    add rdi, 2
    mov edx, IAT_GET_KEY_STATE
    call emit_iat_call
    mov dword [rdi], 0x8000A966     ; test ax, 0x8000
    mov word [rdi+4], 0x0C75        ; jnz +12
    mov word [rdi+6], 0xC3FF        ; inc ebx
    mov dword [rdi+8], 0x7E5AFB83   ; cmp ebx, 90; jle loop_top
    mov rax, r14
    sub rax, rdi
    sub eax, 13
    mov [rdi+12], al
    mov word [rdi+13], 0xDB31       ; xor ebx, ebx
    mov word [rdi+15], 0xD889       ; mov eax, ebx
    mov dword [rdi+17], 0x28C48348  ; add rsp, 40
    mov byte [rdi+21], 0x5B         ; pop rbx
    add rdi, 22
    ret

; --- get_mouse_pos(): allocates []2 array, calls GetCursorPos + ScreenToClient ---
emit_get_mouse_pos_syscall:
    mov ecx, 24
    call emit_heap_alloc_imm
    mov dword [rdi], 0x000200C7
    mov word [rdi+4], 0x0000
    mov dword [rdi+6], 0x020440C7
    mov dword [rdi+10], 0x50000000
    mov dword [rdi+14], 0x28EC8348
    add rdi, 18
    mov edx, BSS_POINT
    call emit_lea_rcx_rva
    mov edx, IAT_GET_CURSOR_POS
    call emit_iat_call
    mov edx, BSS_HWND
    call emit_load_bss_rax
    mov dword [rdi], 0x1274C085
    mov dword [rdi+4], 0x00C18948
    add rdi, 7
    mov edx, BSS_POINT
    call emit_lea_rdx_rva
    mov edx, IAT_SCREEN_CLIENT
    call emit_iat_call
    mov edx, BSS_POINT
    call emit_lea_rdx_rva
    mov dword [rdi], 0x28C48348
    mov byte [rdi+4], 0x58
    mov dword [rdi+5], 0x480A6348
    mov dword [rdi+9], 0x48084889
    mov dword [rdi+13], 0x48044A63
    mov dword [rdi+17], 0x00104889
    add rdi, 21
    ret

; --- Full 4-Edge 2D AABB Collision Check (ECX=Ax, EDX=Ay, R8D=Aw, R9D=Ah, RAX=target B) ---
emit_aabb_collision_check:
    mov dword [rdi], 0x75023883     ; cmp dword [rax], 2; jne +47 (rect-vs-rect)
    mov byte [rdi+4], 47
    ; Path A: Screen Bounds [w, h]2 (Ax <= 0 || Ay <= 0 || Ax+Aw >= w || Ay+Ah >= h)
    mov word [rdi+5], 0xC985
    mov dword [rdi+7], 0xC29E0F41
    mov word [rdi+11], 0xD285
    mov dword [rdi+13], 0xC39E0F41
    mov dword [rdi+17], 0x44DA0845
    mov word [rdi+21], 0xC101
    mov dword [rdi+23], 0x4108483B
    mov dword [rdi+27], 0x45C39D0F
    mov dword [rdi+31], 0x0144DA08
    mov byte [rdi+35], 0xC2
    mov dword [rdi+36], 0x4110503B
    mov dword [rdi+40], 0x45C39D0F
    mov dword [rdi+44], 0x0F45DA08
    mov word [rdi+48], 0xC2B6
    mov word [rdi+50], 0x3CEB       ; jmp +60 (over Path B)
    add rdi, 52
    ; Path B: Rect-vs-Rect 4-Edge AABB Overlap
    mov byte [rdi], 0x56
    mov dword [rdi+1], 0x2C0F44F3
    mov dword [rdi+5], 0x0F44F310
    mov word [rdi+9], 0x0458
    mov dword [rdi+11], 0x708B0858
    mov byte [rdi+15], 0x0C
    mov dword [rdi+16], 0x0144C189
    mov dword [rdi+20], 0x0FD03944
    mov word [rdi+24], 0xC09F
    mov dword [rdi+26], 0x39D30141
    mov dword [rdi+30], 0x20C19C0F
    mov byte [rdi+34], 0xC8
    mov dword [rdi+35], 0x0144D189
    mov dword [rdi+39], 0x0FD93944
    mov dword [rdi+43], 0xC820C19F
    mov dword [rdi+47], 0x39F30141
    mov dword [rdi+51], 0x20C19C0F
    mov byte [rdi+55], 0xC8
    mov dword [rdi+56], 0x5EC0B60F
    add rdi, 60
    ret

; --- Packs comma-separated field literals into custom #define slot EDX (ECX = def index) ---
emit_pack_custom_def:
    push rdx
    push rcx
    call emit_lea_symbol_rax        ; Base address of 24B slot -> RAX
    mov dword [rdi], 0xF8458948     ; mov [rbp - 8], rax
    add rdi, 4
    pop rcx
    mov r13d, [def_field_cnt + rcx*4]
    xor r14d, r14d
.pack_loop:
    cmp r14d, r13d
    jge .pack_done
    push rcx
    push r13
    push r14
    call eval_expr
    pop r14
    pop r13
    pop rcx
    mov ebx, ecx
    shl ebx, 3
    add ebx, r14d
    mov ebx, [def_fld_off + rbx*4]
    mov dword [rdi], 0xF8558B48     ; mov rdx, [rbp - 8]
    mov word [rdi+4], 0x8289        ; mov [rdx + disp32], eax
    mov [rdi+6], ebx
    add rdi, 10
    inc r14d
    cmp byte [rsi], TOK_COMMA
    jne .pack_loop
    add rsi, 8
    jmp .pack_loop
.pack_done:
    pop rdx
    mov byte [sym_type_tag + rdx], TYPE_CUSTOM
    mov [sym_custom_idx + rdx*4], ecx
    push rcx
    call emit_lea_symbol_rax
    pop rcx
    shl ecx, 8
    or ecx, TYPE_CUSTOM
    mov dword [rdi], 0x1040C766
    mov [rdi+4], cx
    add rdi, 6
    ret

; --- Copies 16B custom value from [RAX] into symbol EDX + sets tag TYPE_CUSTOM & def_idx ECX ---
emit_copy_custom_to_symbol:
    push rdx
    push rcx
    mov dword [rdi], 0x4C008B4C
    mov dword [rdi+4], 0x0008488B
    add rdi, 7
    call emit_lea_symbol_rax        ; Destination slot address -> RAX
    pop rcx
    pop rdx
    mov byte [sym_type_tag + rdx], TYPE_CUSTOM
    mov [sym_custom_idx + rdx*4], ecx
    shl ecx, 8
    or ecx, TYPE_CUSTOM
    mov dword [rdi], 0x4C00894C
    mov dword [rdi+4], 0x66084889
    mov word [rdi+8], 0x40C7
    mov byte [rdi+10], 0x10
    mov [rdi+11], cx
    add rdi, 13
    ret
; ==============================================================================
; STAGE 2F-3A-1: SUBTRACTIVE OBJ EMITTERS, IN-PLACE str(), & CONSOLE WRITERS
; ==============================================================================

emit_alloc_array_from_stack:
    push rdx
    push rcx
    push r12
    mov eax, ecx
    shl eax, 3
    add eax, 8
    mov ecx, eax
    call emit_heap_alloc_imm
    pop r12
    pop rcx
    mov word [rdi], 0x00C7
    mov [rdi+2], ecx
    mov dword [rdi+6], 0x000440C7
    mov [rdi+9], r12d
    add rdi, 13
    mov ecx, r12d
.pop_arr_items:
    dec ecx
    js .store_arr_sym
    mov byte [rdi], 0x5A
    mov dword [rdi+1], 0x00908948
    mov ebx, ecx
    shl ebx, 3
    add ebx, 8
    mov [rdi+4], ebx
    add rdi, 8
    jmp .pop_arr_items
.store_arr_sym:
    pop rdx
    mov bl, TYPE_ARRAY
    call emit_store_typed_symbol
    ret

emit_array_push:
    mov dword [rdi], 0xF8458948
    add rdi, 4
    call emit_load_symbol_rax
    mov dword [rdi], 0x3B04488B
    mov dword [rdi+4], 0x48117D08
    mov dword [rdi+8], 0x48F8558B
    mov dword [rdi+12], 0x08C85489
    mov dword [rdi+16], 0x000440FF
    add rdi, 19
    ret

emit_array_elem_write:
    mov dword [rdi], 0xF8458948     ; mov [rbp - 8], rax
    mov dword [rdi+4], 0xF04D8948   ; mov [rbp - 16], rcx
    add rdi, 8
    call emit_load_symbol_rax
    mov dword [rdi], 0xF04D8B48     ; mov rcx, [rbp - 16]
    mov dword [rdi+4], 0xF8558B48   ; mov rdx, [rbp - 8]
    mov dword [rdi+8], 0xC8548948   ; mov [rax + rcx*8 + 8], rdx
    mov byte [rdi+12], 0x08
    add rdi, 13
    ret

emit_instantiate_obj:
    push rdx
    mov ecx, 264
    call emit_heap_alloc_imm
    mov dword [rdi], 0x0000C748
    mov dword [rdi+4], 0xFFFFFFFF
    add rdi, 7
    pop rdx
    mov bl, TYPE_OBJ
    call emit_store_typed_symbol
    ret

emit_clear_obj_field_bit_idx:
    push rcx
    call emit_load_symbol_rax
    pop rcx
    mov dword [rdi], 0x30BA0F48     ; btr qword [rax], cl
    mov [rdi+4], cl
    add rdi, 5
    ret

emit_call_obj_main:
    mov ecx, [sym_custom_idx + rdx*4]
    cmp ecx, -1
    je .no_obj_main
    mov ebx, [cls_main_off + rcx*4]
    cmp ebx, -1
    je .no_obj_main
    push rbx
    call emit_load_symbol_rax
    mov dword [rdi], 0x20EC8348
    mov dword [rdi+4], 0x00C18948
    add rdi, 7
    pop rax
    mov byte [rdi], 0xE8
    lea r8, [code_buffer + rax]
    mov rax, r8
    sub rax, rdi
    sub eax, 5
    mov [rdi+1], eax
    add rdi, 5
    mov dword [rdi], 0x20C48348
    add rdi, 4
.no_obj_main:
    ret

emit_format_active_vars:
    mov ecx, [sym_custom_idx + rdx*4]
    cmp ecx, -1
    je .fmt_vars_empty
    push rcx
    call emit_load_symbol_rax
    mov dword [rdi], 0xF8458948
    add rdi, 4
    mov ecx, 256
    call emit_heap_alloc_imm
    mov dword [rdi], 0x50C48949
    add rdi, 4
    pop rcx
    mov r13d, [cls_fld_cnt + rcx*4]
    xor r14d, r14d
.fmt_fld_loop:
    cmp r14d, r13d
    jge .fmt_fld_done
    mov dword [rdi], 0xF8558B48
    mov dword [rdi+4], 0x22BA0F48
    mov [rdi+8], r14b
    mov word [rdi+9], 0x1273
    add rdi, 11
    mov eax, ecx
    shl eax, 4
    add eax, r14d
    mov eax, [cls_fld_name + rax*4]
    lea r9, [str_pool + rax]
.copy_fname_byte:
    mov dl, [r9]
    test dl, dl
    jz .fname_sep
    mov word [rdi], 0xC641
    mov byte [rdi+2], 0x04
    mov byte [rdi+3], 0x24
    mov [rdi+4], dl
    mov dword [rdi+5], 0x00C4FF49
    add rdi, 8
    inc r9
    jmp .copy_fname_byte
.fname_sep:
    mov word [rdi], 0xC641
    mov byte [rdi+2], 0x04
    mov byte [rdi+3], 0x24
    mov byte [rdi+4], ' '
    mov dword [rdi+5], 0x00C4FF49
    add rdi, 8
    inc r14d
    jmp .fmt_fld_loop
.fmt_fld_done:
    mov dword [rdi], 0x002404C6
    mov byte [rdi+4], 0x00
    mov byte [rdi+5], 0x58
    add rdi, 6
    ret
.fmt_vars_empty:
    mov edx, RODATA_SPACE
    call emit_lea_rax_rva
    ret

emit_mutate_to_string:
    cmp byte [rsi], TOK_IDENT
    jne .mut_done
    mov eax, [rsi+4]
    add rsi, 8
    cmp byte [rsi], TOK_DOT
    je .mut_member_field
    call lookup_symbol
    cmp edx, -1
    je .mut_done
    push rdx
    call emit_load_symbol_rax
    call emit_int_to_str_rax
    pop rdx
    mov bl, TYPE_STR
    call emit_store_typed_symbol
    ret
.mut_member_field:
    add rsi, 8
    mov ebx, [rsi+4]
    add rsi, 8
    call lookup_symbol
    cmp edx, -1
    je .mut_done
    mov ecx, [sym_custom_idx + rdx*4]
    mov eax, ebx
    call lookup_class_field
    cmp ecx, -1
    je .mut_done
    push rcx
    call emit_load_symbol_rax
    pop rcx
    shl ecx, 4
    add ecx, 8
    push rcx
    mov dword [rdi], 0xF8458948
    mov dword [rdi+4], 0x00808B48
    mov [rdi+7], ecx
    add rdi, 11
    call emit_int_to_str_rax
    pop rcx
    mov dword [rdi], 0xF8558B48
    mov dword [rdi+4], 0x00828948
    mov [rdi+7], ecx
    add ecx, 8
    mov word [rdi+11], 0x82C6
    mov [rdi+13], ecx
    mov byte [rdi+17], TYPE_STR
    add rdi, 18
.mut_done:
    ret

emit_int_to_str_rax:
    mov dword [rdi], 0xF8458948
    add rdi, 4
    mov ecx, 32
    call emit_heap_alloc_imm
    mov dword [rdi], 0xF84D8B48
    mov dword [rdi+4], 0x45D23145
    mov dword [rdi+8], 0x0979C985
    mov dword [rdi+12], 0x41D9F748
    mov dword [rdi+16], 0x000001BA
    mov byte [rdi+20], 0x00
    mov dword [rdi+21], 0x1F408D4C
    mov dword [rdi+25], 0x0000C641
    mov word [rdi+29], 0xB941
    mov dword [rdi+31], 10
    mov dword [rdi+35], 0x48C8FF49
    mov dword [rdi+39], 0x489948C8
    mov dword [rdi+43], 0x80F9F749
    mov dword [rdi+47], 0x884130C2
    mov dword [rdi+51], 0xC1894810
    mov dword [rdi+55], 0x75C98548
    mov byte [rdi+59], 0xE5
    mov dword [rdi+60], 0x0974D285
    mov dword [rdi+64], 0x41C8FF49
    mov dword [rdi+68], 0x002D00C6
    mov dword [rdi+72], 0x00C0894C
    add rdi, 75
    ret

emit_write_cstr_rax:
    mov dword [rdi], 0x42C03145
    mov dword [rdi+4], 0x00003C80
    mov word [rdi+8], 0x0574
    mov dword [rdi+10], 0xEBC0FF41
    mov byte [rdi+14], 0xF4
    mov byte [rdi+15], 0x50
    mov word [rdi+16], 0x5041
    mov dword [rdi+18], 0x30EC8348
    mov byte [rdi+22], 0xB9
    mov dword [rdi+23], 0xFFFFFFF5
    add rdi, 27
    mov edx, IAT_GET_STD_HANDLE
    call emit_iat_call
    mov dword [rdi], 0x48C18948
    mov dword [rdi+4], 0x3824548B
    mov dword [rdi+8], 0x3024448B
    mov dword [rdi+12], 0x4C244C8D
    mov byte [rdi+16], 0x28
    mov dword [rdi+17], 0x2444C748
    mov dword [rdi+21], 0x00000020
    mov byte [rdi+25], 0x00
    add rdi, 26
    mov edx, IAT_WRITE_FILE
    call emit_iat_call
    mov dword [rdi], 0x40C48348
    add rdi, 4
    ret

emit_print_array_rax:
    mov byte [rdi], 0x53
    mov word [rdi+1], 0x5441
    mov dword [rdi+3], 0x45C38948
    mov word [rdi+7], 0xE431
    add rdi, 9
    mov r14, rdi
    mov dword [rdi], 0x04633B44
    mov word [rdi+4], 0x007D
    mov r15, rdi
    add r15, 5
    mov dword [rdi+6], 0xE3448B4A
    mov byte [rdi+10], 0x08
    add rdi, 11
    call emit_int_to_str_rax
    call emit_write_cstr_rax
    mov edx, RODATA_SPACE
    call emit_lea_rax_rva
    call emit_write_cstr_rax
    mov dword [rdi], 0xE9C4FF41
    mov rax, r14
    sub rax, rdi
    sub eax, 8
    mov [rdi+4], eax
    add rdi, 8
    mov rax, rdi
    sub rax, r15
    dec eax
    mov [r15], al
    mov edx, RODATA_NEWLINE
    call emit_lea_rax_rva
    call emit_write_cstr_rax
    mov word [rdi], 0x5C41
    mov byte [rdi+2], 0x5B
    add rdi, 3
    ret
; ==============================================================================
; STAGE 2F-3A-2: DOTTED STATEMENT & EXPRESSION RESOLVERS
; ==============================================================================
emit_dotted_statement:
    mov eax, [rsi+4]
    add rsi, 16
    cmp byte [rsi], TOK_KW_OBJ
    jne .dot_stmt_member
    add rsi, 8
    cmp byte [rsi], TOK_IDENT
    jne skip_to_nl
    mov eax, [rsi+4]
    call register_symbol
    mov byte [sym_type_tag + rdx], TYPE_OBJ
    push rdx
    add rsi, 16
    mov eax, [rsi+4]
    add rsi, 8
    call lookup_class
    pop rdx
    mov [sym_custom_idx + rdx*4], eax
    call emit_instantiate_obj
    ret
.dot_stmt_member:
    push rax
.walk_dot_stmt:
    mov ebx, [rsi+4]
    add rsi, 8
    cmp byte [rsi], TOK_DOT
    jne .dot_stmt_leaf
    add rsi, 8
    jmp .walk_dot_stmt
.dot_stmt_leaf:
    cmp byte [rsi], TOK_ASSIGN
    je .dot_field_write
    pop rax
    cmp byte [rsi], TOK_LPAREN
    jne skip_to_nl
    add rsi, 8
    cmp byte [rsi], TOK_RPAREN
    je .dot_call_no_arg
    call eval_expr
    mov dword [rdi], 0x00C28948
    add rdi, 3
.dot_call_no_arg:
    mov eax, ebx
    call lookup_fn
    mov dword [rdi], 0x20EC8348
    add rdi, 4
    mov byte [rdi], 0xE8
    lea r8, [code_buffer + rax]
    mov rax, r8
    sub rax, rdi
    sub eax, 5
    mov [rdi+1], eax
    add rdi, 5
    mov dword [rdi], 0x20C48348
    add rdi, 4
    jmp skip_to_nl

.dot_field_write:
    pop rax
    call lookup_symbol
    cmp edx, -1
    je skip_to_nl
    mov ecx, [sym_custom_idx + rdx*4]
    mov eax, ebx
    call lookup_class_field
    cmp ecx, -1
    je skip_to_nl
    bt qword [sym_obj_del_msk + rdx*8], rcx
    jc .dot_deleted_trap
    push rdx
    push rcx
    add rsi, 8
    call eval_expr
    mov dword [rdi], 0xF8458948
    add rdi, 4
    pop rcx
    pop rdx
    push rcx
    call emit_load_symbol_rax
    pop rcx
    shl ecx, 4
    add ecx, 8
    mov dword [rdi], 0xF8558B48
    mov dword [rdi+4], 0x00908948
    mov [rdi+7], ecx
    add ecx, 8
    mov word [rdi+11], 0x80C6
    mov [rdi+13], ecx
    mov bl, byte [expr_type_tag]
    mov [rdi+17], bl
    add rdi, 18
    ret
.dot_deleted_trap:
    lea rcx, [err_del_msg]
    call print_cstr
    jmp skip_to_nl

eval_dotted_expr:
    mov eax, [rsi+4]
    add rsi, 16
    push rax
.walk_dot_expr:
    mov ebx, [rsi+4]
    add rsi, 8
    cmp byte [rsi], TOK_DOT
    jne .dot_expr_leaf
    add rsi, 8
    jmp .walk_dot_expr
.dot_expr_leaf:
    cmp byte [rsi], TOK_LPAREN
    je .dot_expr_call
    pop rax
    call lookup_symbol
    cmp edx, -1
    je .dot_expr_zero
    cmp byte [sym_type_tag + rdx], TYPE_CUSTOM
    je .read_custom_def_field
    mov ecx, [sym_custom_idx + rdx*4]
    mov eax, ebx
    call lookup_class_field
    cmp ecx, -1
    je .dot_expr_zero
    bt qword [sym_obj_del_msk + rdx*8], rcx
    jc .dot_expr_deleted
    push rcx
    call emit_load_symbol_rax
    pop rcx
    shl ecx, 4
    add ecx, 8
    mov dword [rdi], 0x00808B48
    mov [rdi+3], ecx
    add rdi, 7
    mov dword [expr_type_tag], TYPE_INT
    ret
.dot_expr_deleted:
    lea rcx, [err_del_msg]
    call print_cstr
    jmp .dot_expr_zero
.read_custom_def_field:
    mov ecx, [sym_custom_idx + rdx*4]
    mov eax, ebx
    call lookup_def_field
    cmp ecx, -1
    je .dot_expr_zero
    push rcx
    call emit_lea_symbol_rax
    pop rcx
    mov word [rdi], 0x808B
    mov [rdi+2], ecx
    add rdi, 6
    mov dword [expr_type_tag], TYPE_INT
    ret
.dot_expr_call:
    pop rax
    add rsi, 8
    cmp byte [rsi], TOK_RPAREN
    je .dot_expr_no_arg
    call eval_expr
    mov dword [rdi], 0x00C28948
    add rdi, 3
.dot_expr_no_arg:
    cmp byte [rsi], TOK_RPAREN
    jne .dot_expr_invoke
    add rsi, 8
.dot_expr_invoke:
    mov eax, ebx
    call lookup_fn
    mov dword [rdi], 0x20EC8348
    add rdi, 4
    mov byte [rdi], 0xE8
    lea r8, [code_buffer + rax]
    mov rax, r8
    sub rax, rdi
    sub eax, 5
    mov [rdi+1], eax
    add rdi, 5
    mov dword [rdi], 0x20C48348
    add rdi, 4
    mov dword [expr_type_tag], TYPE_INT
    ret
.dot_expr_zero:
    mov word [rdi], 0xC031
    add rdi, 2
    ret
; ==============================================================================
; STAGE 2F-3B-1: 24-BYTE UNIVERSAL SLOT HELPERS & SYMBOL/CLASS LOOKUPS
; ==============================================================================
emit_load_slot_tag_eax:
    call emit_lea_symbol_rax
    mov dword [rdi], 0x1040B70F     ; movzx eax, word [rax + 16]
    add rdi, 4
    ret

emit_load_symbol_rax:
    cmp byte [sym_is_global + rdx], 1
    je .ld_glob
    mov ecx, [sym_offset + rdx*4]
    neg ecx
    mov dword [rdi], 0x00858B48     ; mov rax, [rbp - disp32]
    mov [rdi+3], ecx
    add rdi, 7
    ret
.ld_glob:
    mov edx, [sym_offset + rdx*4]
    call emit_load_bss_rax
    ret

emit_lea_symbol_rax:
    cmp byte [sym_is_global + rdx], 1
    je .lea_glob
    mov ecx, [sym_offset + rdx*4]
    neg ecx
    mov dword [rdi], 0x00858D48     ; lea rax, [rbp - disp32]
    mov [rdi+3], ecx
    add rdi, 7
    ret
.lea_glob:
    mov edx, [sym_offset + rdx*4]
    call emit_lea_rax_rva
    ret

emit_store_typed_symbol:
    mov [sym_type_tag + rdx], bl
    cmp byte [sym_is_global + rdx], 1
    je .st_glob
    mov ecx, [sym_offset + rdx*4]
    neg ecx
    mov dword [rdi], 0x00858948     ; mov [rbp - disp32], rax
    mov [rdi+3], ecx
    add ecx, 16                     ; Tag byte sits at [rbp - disp + 16]
    mov word [rdi+7], 0x85C6
    mov [rdi+9], ecx
    mov [rdi+13], bl
    add rdi, 14
    ret
.st_glob:
    mov ecx, [sym_offset + rdx*4]
    push rcx
    push rbx
    mov edx, ecx
    call emit_store_bss_rax
    pop rbx
    pop rdx
    add edx, 16
    call emit_lea_rax_rva
    mov byte [rdi], 0xC6
    mov byte [rdi+1], 0x00
    mov [rdi+2], bl
    add rdi, 3
    ret

emit_spill_arg_reg:
    neg ecx
    cmp r12d, 0
    je .sp0
    cmp r12d, 1
    je .sp1
    cmp r12d, 2
    je .sp2
    cmp r12d, 3
    je .sp3
    ret
.sp0:
    mov dword [rdi], 0x008D8948
    mov [rdi+3], ecx
    add rdi, 7
    ret
.sp1:
    mov dword [rdi], 0x00958948
    mov [rdi+3], ecx
    add rdi, 7
    ret
.sp2:
    mov dword [rdi], 0x0085894C
    mov [rdi+3], ecx
    add rdi, 7
    ret
.sp3:
    mov dword [rdi], 0x008D894C
    mov [rdi+3], ecx
    add rdi, 7
    ret

emit_load_arg_reg_to_rax:
    cmp r12d, 0
    je .la0
    cmp r12d, 1
    je .la1
    cmp r12d, 2
    je .la2
    mov dword [rdi], 0x00C8894C
    add rdi, 3
    ret
.la0:
    mov dword [rdi], 0x00C88948
    add rdi, 3
    ret
.la1:
    mov dword [rdi], 0x00D08948
    add rdi, 3
    ret
.la2:
    mov dword [rdi], 0x00C0894C
    add rdi, 3
    ret

parse_type_annotation:
    mov al, [rsi]
    cmp al, TOK_IDENT
    jne .pta_builtin
    mov eax, [rsi+4]
    call lookup_custom_def
    cmp ecx, -1
    je .pta_done
    mov byte [sym_type_tag + rdx], TYPE_CUSTOM
    mov [sym_custom_idx + rdx*4], ecx
.pta_done:
    add rsi, 8
    ret
.pta_builtin:
    add rsi, 8
    ret

register_symbol:
    push rbx
    mov ecx, [sym_count]
.chk_ex:
    dec ecx
    js .new_sym
    cmp [sym_str_off + rcx*4], eax
    je .fnd_ex
    jmp .chk_ex
.fnd_ex:
    mov edx, ecx
    mov ecx, [sym_offset + rcx*4]
    pop rbx
    ret
.new_sym:
    mov ecx, [sym_count]
    mov edx, ecx
    mov [sym_str_off + rcx*4], eax
    mov byte [sym_is_fluid + rcx], 0
    mov byte [sym_const_lock + rcx], 0
    mov byte [sym_deleted + rcx], 0
    mov qword [sym_obj_del_msk + rcx*8], 0
    mov dword [sym_custom_idx + rcx*4], -1
    cmp dword [in_fn_scope], 1
    je .loc_sym
    mov byte [sym_is_global + rcx], 1
    imul ebx, ecx, 24               ; 24-byte universal global slot in BSS_GLOBALS
    add ebx, BSS_GLOBALS
    mov [sym_offset + rcx*4], ebx
    inc dword [sym_count]
    mov ecx, ebx
    pop rbx
    ret
.loc_sym:
    mov byte [sym_is_global + rcx], 0
    mov ebx, [next_local_off]
    mov [sym_offset + rcx*4], ebx
    add dword [next_local_off], 24  ; 24-byte universal local slot
    inc dword [sym_count]
    mov ecx, ebx
    pop rbx
    ret

lookup_symbol:
    mov ecx, [sym_count]
.f_lp:
    dec ecx
    js .not_f
    cmp [sym_str_off + rcx*4], eax
    je .f_ok
    jmp .f_lp
.f_ok:
    mov edx, ecx
    ret
.not_f:
    mov edx, -1
    ret

lookup_custom_def:
    xor ecx, ecx
.lcd_lp:
    cmp ecx, [def_count]
    jge .lcd_no
    cmp [def_name_off + rcx*4], eax
    je .lcd_yes
    inc ecx
    jmp .lcd_lp
.lcd_yes:
    ret
.lcd_no:
    mov ecx, -1
    ret

lookup_def_field:
    mov ebx, ecx
    shl ebx, 3
    mov edx, [def_field_cnt + rcx*4]
    xor ecx, ecx
.ldf_lp:
    cmp ecx, edx
    jge .ldf_no
    push rbx
    add ebx, ecx
    cmp [def_fld_name + rbx*4], eax
    je .ldf_yes
    pop rbx
    inc ecx
    jmp .ldf_lp
.ldf_yes:
    mov ecx, [def_fld_off + rbx*4]
    pop rbx
    ret
.ldf_no:
    mov ecx, -1
    ret
; ==============================================================================
; STAGE 2F-3B-2: CLASS LOOKUPS, STAGE 3 PE64 WRITER, & COMPILER IMPORTS
; ==============================================================================
lookup_class:
    xor ecx, ecx
.lc_lp:
    cmp ecx, [cls_count]
    jge .lc_no
    cmp [cls_name_off + rcx*4], eax
    je .lc_yes
    inc ecx
    jmp .lc_lp
.lc_yes:
    mov eax, ecx
    ret
.lc_no:
    mov eax, -1
    ret

add_class_proto_field:
    mov edx, [cls_fld_cnt + rcx*4]
    mov r8d, ecx
    shl r8d, 4
    add r8d, edx
    mov [cls_fld_name + r8*4], eax
    mov [cls_fld_type + r8], bl
    inc dword [cls_fld_cnt + rcx*4]
    ret

lookup_class_field:
    cmp ecx, -1
    je .lcf_no
    mov ebx, ecx
    shl ebx, 4
    mov edx, [cls_fld_cnt + rcx*4]
    xor ecx, ecx
.lcf_lp:
    cmp ecx, edx
    jge .lcf_no
    push rbx
    add ebx, ecx
    cmp [cls_fld_name + rbx*4], eax
    je .lcf_yes
    pop rbx
    inc ecx
    jmp .lcf_lp
.lcf_yes:
    pop rbx
    ret
.lcf_no:
    mov ecx, -1
    ret

register_class_method:
    mov ecx, [fn_count]
    mov [fn_str_off + rcx*4], eax
    mov [fn_code_off + rcx*4], edx
    inc dword [fn_count]
    ret

lookup_fn:
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

; ==============================================================================
; STAGE 3: WINDOWS PE64 EXECUTABLE WRITER
; ==============================================================================
write_pe_exe:
    invoke CreateFileA, out_exe_name, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
    mov [hFile], rax
    invoke WriteFile, [hFile], pe_template, 0x200, bytesWritten, 0
    invoke WriteFile, [hFile], code_buffer, 0x4000, bytesWritten, 0
    invoke WriteFile, [hFile], idata_section, 0x400, bytesWritten, 0
    invoke WriteFile, [hFile], rodata_buffer, 0x1000, bytesWritten, 0
    invoke CloseHandle, [hFile]
    ret

; ==============================================================================
; KEYWORD & CLI STRING HELPERS
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
