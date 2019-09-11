ConsoleInit             PROTO
ConsoleExit             PROTO
ConsoleClearScreen      PROTO
ConsoleText             PROTO :DWORD
ConsoleStarted          PROTO
ConsoleAttach           PROTO
ConsoleSendEnterKey     PROTO
ReadFromPipe            PROTO 

.DATA
szBackslash             DB "\",0

hLogFile                DD 0

gConsoleStartedMode     DD 0

dwBytesRead             DD 0 
TotalBytesAvail         DD 0 
BytesLeftThisMessage    DD 0

szLogFile               DB MAX_PATH DUP (0)

szParameter1Buffer      DB MAX_PATH DUP (0)
CmdLineParameters       DB 512 DUP (0)

PIPEBUFFER              DB 4096 DUP (0) ;4096 DUP (0) - modified to 1 char as console output was cutting off/lagging until it 'filled' buffer size


.DATA?
SecuAttr                SECURITY_ATTRIBUTES <>
hChildStd_OUT_Rd        DD ?
hChildStd_OUT_Wr        DD ?
hChildStd_IN_Rd         DD ?
hChildStd_IN_Wr         DD ?



.CODE


IEEX_ALIGN
;------------------------------------------------------------------------------
; ConsoleInit
;------------------------------------------------------------------------------
ConsoleInit PROC
    Invoke ConsoleAttach
    Invoke ConsoleStarted
    mov gConsoleStartedMode, eax
    ret
ConsoleInit ENDP

IEEX_ALIGN
;------------------------------------------------------------------------------
; ConsoleExit
;------------------------------------------------------------------------------
ConsoleExit PROC
    .IF gConsoleStartedMode == TRUE
        Invoke ConsoleSendEnterKey
        Invoke FreeConsole
    .ENDIF
    ret
ConsoleExit ENDP

IEEX_ALIGN
;------------------------------------------------------------------------------
; ConsoleText
;------------------------------------------------------------------------------
ConsoleText PROC lpszConText:DWORD
    LOCAL dwBytesWritten:DWORD
    LOCAL dwBytesToWrite:DWORD

    .IF hConOutput != 0 && lpszConText != 0
        Invoke lstrlen, lpszConText
        mov dwBytesToWrite, eax
        Invoke WriteFile, hConOutput, lpszConText, dwBytesToWrite, Addr dwBytesWritten, NULL
        mov eax, dwBytesWritten
    .ELSE
        xor eax, eax
    .ENDIF
    ret
ConsoleText ENDP

IEEX_ALIGN
;------------------------------------------------------------------------------
; ClearConsoleScreen 
;------------------------------------------------------------------------------
ConsoleClearScreen PROC USES EBX
    LOCAL noc:DWORD
    LOCAL cnt:DWORD
    LOCAL sbi:CONSOLE_SCREEN_BUFFER_INFO
    .IF hConOutput != 0
        Invoke GetConsoleScreenBufferInfo, hConOutput, Addr sbi
        mov eax, sbi.dwSize ; 2 word values returned for screen size
    
        ; extract the 2 values and multiply them together
        mov ebx, eax
        shr eax, 16
        mul bx
        mov cnt, eax
    
        Invoke FillConsoleOutputCharacter, hConOutput, 32, cnt, NULL, Addr noc
        movzx ebx, sbi.wAttributes
        Invoke FillConsoleOutputAttribute, hConOutput, ebx, cnt, NULL, Addr noc
        Invoke SetConsoleCursorPosition, hConOutput, NULL
    .ENDIF
    ret
ConsoleClearScreen ENDP

IEEX_ALIGN
;------------------------------------------------------------------------------
; ConsoleStarted - For GUI Apps - Return TRUE if started from console or FALSE 
; if started via GUI (explorer) 
;------------------------------------------------------------------------------
ConsoleStarted PROC
    LOCAL pidbuffer[8]:DWORD
    Invoke GetConsoleProcessList, Addr pidbuffer, 4
    .IF eax == 2
        mov eax, TRUE
    .ELSE    
        mov eax, FALSE
    .ENDIF
    ret
ConsoleStarted ENDP

IEEX_ALIGN
;------------------------------------------------------------------------------
; ConsoleSendEnterKey
;------------------------------------------------------------------------------
ConsoleSendEnterKey PROC
    Invoke GetConsoleWindow
    .IF eax != 0
        Invoke SendMessage, eax, WM_CHAR, VK_RETURN, 0
    .ENDIF
    ret
ConsoleSendEnterKey ENDP

IEEX_ALIGN
;------------------------------------------------------------------------------
; ConsoleAttach
;------------------------------------------------------------------------------
ConsoleAttach PROC
    Invoke AttachConsole, ATTACH_PARENT_PROCESS
    ret
ConsoleAttach ENDP

IEEX_ALIGN
;------------------------------------------------------------------------------
; Read output from the child process's pipe for STDOUT
; and write to the parent process's pipe for STDOUT. 
; Stop when there is no more data. 
;------------------------------------------------------------------------------
ReadFromPipe PROC
    LOCAL dwTotalBytesToRead:DWORD
    LOCAL dwRead:DWORD
    LOCAL dwWritten:DWORD
    LOCAL hParentStdOut:DWORD
    LOCAL hParentStdErr:DWORD
    LOCAL bSuccess:DWORD

    IFDEF DEBUG32
    PrintText 'ReadFromPipe'
    ENDIF

    mov bSuccess, FALSE
    Invoke GetStdHandle, STD_OUTPUT_HANDLE
    mov hParentStdOut, eax
    Invoke GetStdHandle, STD_ERROR_HANDLE
    mov hParentStdErr, eax

    IFDEF DEBUG32
    PrintText 'ReadFromPipe Loop'
    ENDIF

    .WHILE TRUE
        Invoke GetExitCodeProcess, pi.hProcess, Addr ExitCode
        .IF eax == 0
            IFDEF DEBUG32
            PrintText 'GetExitCodeProcess error'
            Invoke GetLastError
            PrintDec eax
            ENDIF
        .ENDIF
        .IF ExitCode != STILL_ACTIVE
            IFDEF DEBUG32
            PrintText 'Exit from ReadFromPipe::GetExitCodeProcess'
            ENDIF
            ret
        .ENDIF
        
        Invoke PeekNamedPipe, hChildStd_OUT_Rd, NULL, NULL, NULL, Addr dwTotalBytesToRead, NULL
        .IF eax == 0
            IFDEF DEBUG32
            PrintText 'PeekNamedPipe Error'
            Invoke GetLastError
            PrintDec eax
            ENDIF
        .ENDIF
        
        .IF dwTotalBytesToRead != 0
            IFDEF DEBUG32
            PrintDec dwTotalBytesToRead
            ENDIF
            Invoke ReadFile, hChildStd_OUT_Rd, Addr PIPEBUFFER, SIZEOF PIPEBUFFER, Addr dwRead, NULL
            mov bSuccess, eax
            .IF bSuccess == FALSE || dwRead == 0
                IFDEF DEBUG32
                PrintText 'Exit from ReadFromPipe::ReadFile'
                ENDIF
                ret
            .ENDIF
            
            .IF hLogFile != 0
                Invoke WriteFile, hLogFile, Addr PIPEBUFFER, dwRead, Addr dwWritten, NULL
            .ENDIF
            
            Invoke WriteFile, hParentStdOut, Addr PIPEBUFFER, dwRead, Addr dwWritten, NULL
            mov bSuccess, eax
            .IF bSuccess == FALSE
                IFDEF DEBUG32
                PrintText 'Exit from ReadFromPipe::WriteFile'
                ENDIF
                ret
            .ENDIF
        .ENDIF
        
        Invoke Sleep, 100
        
    .ENDW
    
    ret
ReadFromPipe ENDP





















