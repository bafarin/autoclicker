format PE GUI 4.0
entry start
include 'win32a.inc'

section '.data' data readable writeable
    Tittle          db 'Clicker Panel', 0
    class_name      db 'ExampleWindow', 0
    btn_class       db 'BUTTON', 0
    edit_class      db 'EDIT', 0
    btn_lmb_text    db 'LMB', 0
    btn_rmb_text    db 'RMB', 0
    btn_f_text      db 'F', 0
    list_class      db 'LISTBOX', 0 
    btn_stop_text   db 'STOP', 0
    default_delay   db '1500', 0
    filename        db 'settings.txt', 0
    wc              WNDCLASS
    msg             MSG
    str_ms          db 'milliseconds', 0
    str_sec         db 'seconds', 0
    str_min         db 'minutes', 0
    btn_handles     dd 0, ?, ?, ?, ?
    hedit           dd ?        
    click_states    dd 0, 0, 0, 0, 0
    text_buffer     db 16 dup(0)
    hotkey_LMB      dd ?
    hotkey_RMB      dd ?
    hotkey_F        dd ?
    hlist           dd ?
section '.bss' readable writeable
    file_handle     dd ?
    bytes_read      dd ?
    file_buffer     rb 512

section '.text' code readable executable
start:
    call    LoadSettings
    invoke GetModuleHandle, 0
    mov [wc.hInstance], eax
    mov [wc.lpfnWndProc], WindowProc
    invoke LoadCursor, 0, IDC_ARROW
    mov [wc.hCursor], eax
    mov [wc.hbrBackground], COLOR_WINDOW-2
    mov [wc.lpszClassName], class_name
    invoke RegisterClass, wc

    invoke CreateWindowEx, WS_EX_LEFT, class_name, Tittle,\
        WS_VISIBLE + WS_SYSMENU + WS_MINIMIZEBOX + WS_CAPTION,\
        CW_USEDEFAULT, CW_USEDEFAULT, 370, 200,\
        0, 0, [wc.hInstance], 0

.msg_loop:
    invoke GetMessage,  msg, 0, 0, 0
    test eax, eax
    jle .end_loop
    invoke TranslateMessage, msg
    invoke DispatchMessage, msg
    jmp .msg_loop

.end_loop:
    invoke ExitProcess, [msg.wParam]

proc WindowProc hwnd, wmsg, wparam, lparam
    cmp [wmsg], WM_CREATE
    je .wm_create
    cmp [wmsg], WM_COMMAND
    je .wm_command
    cmp [wmsg], WM_HOTKEY
    je .wm_hotkey
    cmp [wmsg], WM_TIMER
    je .wm_timer
    cmp [wmsg], WM_DESTROY
    je .wm_destroy
    invoke DefWindowProc, [hwnd], [wmsg], [wparam], [lparam]
    ret

.wm_create:
    invoke RegisterHotKey, [hwnd], 1, 0x4000, [hotkey_LMB]
    invoke RegisterHotKey, [hwnd], 2, 0x4000, [hotkey_RMB]
    invoke RegisterHotKey, [hwnd], 3, 0x4000, [hotkey_F]

    invoke CreateWindowEx, 0, btn_class, btn_lmb_text,\
        WS_VISIBLE + WS_CHILD + BS_PUSHBUTTON,\
        20, 20, 80, 30,\       
        [hwnd], 1, [wc.hInstance], 0
    mov [btn_handles + 1*4], eax

    invoke CreateWindowEx, 0, btn_class, btn_rmb_text,\
        WS_VISIBLE + WS_CHILD + BS_PUSHBUTTON,\
        120, 20, 80, 30,\
        [hwnd], 2, [wc.hInstance], 0
    mov [btn_handles + 2*4], eax

    invoke CreateWindowEx, 0, btn_class, btn_f_text,\
        WS_VISIBLE + WS_CHILD + BS_PUSHBUTTON,\
        220, 20, 80, 30,\
        [hwnd], 3, [wc.hInstance], 0
    mov [btn_handles + 3*4], eax

    invoke CreateWindowEx, 0, edit_class, default_delay,\
        WS_VISIBLE + WS_CHILD + WS_BORDER + ES_NUMBER,\
        70, 60, 80, 20,\
        [hwnd], 4, [wc.hInstance], 0
    mov [hedit], eax

    invoke CreateWindowEx, WS_EX_CLIENTEDGE, list_class, 0,\
    WS_VISIBLE + WS_CHILD + LBS_NOTIFY + WS_VSCROLL,\
    175, 60, 120, 65,\
    [hwnd], 5, [wc.hInstance], 0
    mov [hlist], eax

    invoke SendMessage, [hlist], 0x0180, 0, str_ms
    invoke SendMessage, [hlist], 0x0180, 0, str_sec
    invoke SendMessage, [hlist], 0x0180, 0, str_min
    invoke SendMessage, [hlist], 0x0186, 0, 0
    xor eax, eax
    ret

.wm_command:
    mov eax, [wparam]
    and eax, $FFFF
    cmp eax, 1
    je .toggle_clicker
    cmp eax, 2
    je .toggle_clicker
    cmp eax, 3
    je .toggle_clicker
    jmp .command_exit

.wm_hotkey:
    mov eax, [wparam]

.toggle_clicker:
    push ebx
    mov ebx, eax
    xor [click_states + ebx*4], 1
    cmp [click_states + ebx*4], 1
    je .start_timer

.stop_timer:
    invoke KillTimer, [hwnd], ebx
    
    mov edx, btn_lmb_text
    cmp ebx, 1
    je .apply_text
    mov edx, btn_rmb_text
    cmp ebx, 2
    je .apply_text
    mov edx, btn_f_text

.apply_text:
    invoke SetWindowText, [btn_handles + ebx*4], edx
    pop ebx
    jmp .command_exit

.start_timer:
    invoke GetWindowText, [hedit], text_buffer, 16
    call ParseStringToDword
    push eax
    invoke SendMessage, [hlist], 0x0188, 0, 0
    mov edx, eax
    pop eax
    cmp edx, 1
    je .multiply_seconds
    cmp edx, 2
    je .multiply_minutes
    jmp .timer_ok

.multiply_seconds:
    imul eax, 1000
    jmp .timer_ok

.multiply_minutes:
    imul eax, 60000

.timer_ok:
    invoke SetTimer, [hwnd], ebx, eax, 0
    invoke SetWindowText, [btn_handles + ebx*4], btn_stop_text
    pop ebx

.command_exit:
    xor eax, eax
    ret

.wm_timer:
    mov eax, [wparam]
    cmp eax, 1
    je .do_lmb_click
    cmp eax, 2
    je .do_rmb_click
    cmp eax, 3
    je .do_f_click
    jmp .timer_exit

.do_lmb_click:
    invoke mouse_event, MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0
    invoke mouse_event, MOUSEEVENTF_LEFTUP, 0, 0, 0, 0
    jmp .timer_exit

.do_rmb_click:
    invoke mouse_event, MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, 0
    invoke mouse_event, MOUSEEVENTF_RIGHTUP, 0, 0, 0, 0
    jmp .timer_exit

.do_f_click:
    invoke keybd_event, 0x46, 0, 0, 0
    invoke keybd_event, 0x46, 0, KEYEVENTF_KEYUP, 0

.timer_exit:
    xor eax, eax
    ret

.wm_destroy:
    invoke UnregisterHotKey, [hwnd], 1
    invoke UnregisterHotKey, [hwnd], 2
    invoke UnregisterHotKey, [hwnd], 3

    invoke KillTimer, [hwnd], 1
    invoke KillTimer, [hwnd], 2
    invoke KillTimer, [hwnd], 3
    invoke PostQuitMessage, 0
    xor eax, eax
    ret
endp

proc LoadSettings
    push esi ebx ecx edx
    invoke CreateFileA, filename, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
    cmp eax, INVALID_HANDLE_VALUE
    je .exit_proc
    mov [file_handle], eax

    invoke ReadFile, [file_handle], file_buffer, 511, bytes_read, 0
    test eax, eax
    jz .close_file

    mov ebx, [bytes_read]
    mov byte [file_buffer + ebx], 0
    invoke CloseHandle, [file_handle]

    lea esi, [file_buffer]

.parse_lines:
    mov al, [esi]
    test al, al
    jz .exit_proc
    cmp al, 13
    je .step_char
    cmp al, 10
    je .step_char
    jmp .check_lmb

.step_char:
    inc esi
    jmp .parse_lines

.check_lmb:
    cmp dword [esi], 'LMB:'
    jne .check_rmb
    add esi, 4
    call ParseHexValue
    cmp eax, -1
    je .skip_line
    mov [hotkey_LMB], eax
    jmp .skip_line

.check_rmb:
    cmp dword [esi], 'RMB:'
    jne .check_f
    add esi, 4
    call ParseHexValue
    cmp eax, -1
    je .skip_line
    mov [hotkey_RMB], eax
    jmp .skip_line

.check_f:
    cmp word [esi], 'F:'
    jne .check_timer
    add esi, 2
    call ParseHexValue
    cmp eax, -1
    je .skip_line
    mov [hotkey_F], eax
    jmp .skip_line

.check_timer:
    cmp dword [esi], 'TIME'
    jne .skip_line
    cmp word [esi+4], 'R:'
    jne .skip_line
    add esi, 6

.skip_spaces:
    cmp byte [esi], ' '
    jne .copy_delay
    inc esi
    jmp .skip_spaces

.copy_delay:
    lea edi, [default_delay]
    mov ecx, 0

.copy_loop:
    mov al, [esi]
    cmp al, '0'
    jb .copy_done
    cmp al, '9'
    ja .copy_done
    mov [edi], al
    inc esi
    inc edi
    inc ecx
    cmp ecx, 5
    jb .copy_loop

.copy_done:
    mov byte [edi], 0
    jmp .skip_line

.skip_line:
    mov al, [esi]
    test al, al
    jz .exit_proc
    inc esi
    cmp al, 10
    jne .skip_line
    jmp .parse_lines

.close_file:
    invoke CloseHandle, [file_handle]

.exit_proc:
    pop edx ecx ebx esi
    ret
endp


proc ParseHexValue
    push    ebx edi

.skip_junk:
    mov     al, [esi]
    test    al, al
    jz      .err
    cmp     al, ':'
    je      .step_junk
    cmp     al, ' '
    je      .step_junk
    cmp     al, '"'
    je      .step_junk
    jmp     .check_prefix

.step_junk:
    inc     esi
    jmp     .skip_junk

.check_prefix:
    cmp     byte [esi], '0'
    jne     .start_parse
    cmp     byte [esi+1], 'x'
    je      .skip_prefix
    cmp     byte [esi+1], 'X'
    jne     .start_parse
.skip_prefix:
    add     esi, 2

.start_parse:
    xor     eax, eax
    xor     ebx, ebx
    xor     edi, edi

.hex_loop:
    mov     bl, [esi]
    cmp     bl, '0'
    jb      .check_upper_letter
    cmp     bl, '9'
    jbe     .is_digit

.check_upper_letter:
    cmp     bl, 'A'
    jb      .check_lower_letter
    cmp     bl, 'F'
    jbe     .is_upper

.check_lower_letter:
    cmp     bl, 'a'
    jb      .done_parsing
    cmp     bl, 'f'
    ja      .done_parsing

.is_lower:
    sub     bl, 'a'
    add     bl, 10
    jmp     .accumulate

.is_upper:
    sub     bl, 'A'
    add     bl, 10
    jmp     .accumulate

.is_digit:
    sub     bl, '0'

.accumulate:
    shl     eax, 4
    add     eax, ebx
    inc     esi
    inc     edi
    jmp     .hex_loop

.done_parsing:
    test    edi, edi
    jz      .err
    jmp     .out
.err:
    mov     eax, -1
.out:
    pop     edi ebx
    ret
endp

proc ParseStringToDword
    push esi
    push ecx
    push edx
    xor eax, eax
    mov esi, text_buffer
    xor ecx, ecx

.loop_chars:
    mov cl, [esi]
    test cl, cl
    jz .parse_done
    sub cl, '0'
    imul eax, 10
    add eax, ecx
    inc esi
    jmp .loop_chars

.parse_done:
    pop edx
    pop ecx
    pop esi
    ret
endp

section '.idata' import data readable
library kernel32,   'kernel32.dll',\
        user32,     'user32.dll'
    import  kernel32,\ 
        ExitProcess,        'ExitProcess',\
        GetModuleHandle,    'GetModuleHandleA',\
        CreateFileA,        'CreateFileA',\
        ReadFile,           'ReadFile',\
        CloseHandle,        'CloseHandle'
    import  user32,\
        DefWindowProc,      'DefWindowProcA',\
        CreateWindowEx,     'CreateWindowExA',\
        GetMessage,         'GetMessageA',\
        TranslateMessage,   'TranslateMessage',\
        DispatchMessage,    'DispatchMessageA',\
        PostQuitMessage,    'PostQuitMessage',\
        GetWindowText,      'GetWindowTextA',\
        SetWindowText,      'SetWindowTextA',\
        LoadCursor,         'LoadCursorA',\
        RegisterClass,      'RegisterClassA',\
        SetTimer,           'SetTimer',\
        KillTimer,          'KillTimer',\
        mouse_event,        'mouse_event',\
        keybd_event,        'keybd_event',\
        RegisterHotKey,     'RegisterHotKey',\
        SendMessage,        'SendMessageA',\
        UnregisterHotKey,   'UnregisterHotKey'
