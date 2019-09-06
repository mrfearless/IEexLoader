;------------------------------------------------------------------------------
; IEex.DLL - Loader for IEex to inject IEex.dll by github.com/mrfearless
;
; IEex by Bubb: github.com/Bubb13/IEex 
;
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; IEexPrint Prototypes
;------------------------------------------------------------------------------
IFDEF IEEX_SDLINT
SDL_Log                 PROTO C lpszString:DWORD, lpszFmt:DWORD
SDL_LogMessageV         PROTO C priority:DWORD, lpszFmt:DWORD, lpszString:DWORD
SDL_LogOutput           PROTO C priority:DWORD, message:DWORD
ENDIF

;------------------------------------------------------------------------------
; LUA Function Prototypes
;------------------------------------------------------------------------------
l_log_print             PROTO C :VARARG         ; (lua_State)


.CONST
SDL_LOG_PRIORITY_VERBOSE    EQU 1
SDL_LOG_PRIORITY_DEBUG      EQU 2
SDL_LOG_PRIORITY_INFO       EQU 3
SDL_LOG_PRIORITY_WARN       EQU 4
SDL_LOG_PRIORITY_ERROR      EQU 5
SDL_LOG_PRIORITY_CRITICAL   EQU 6
SDL_NUM_LOG_PRIORITIES      EQU 7


.DATA
IFDEF IEEX_SDLINT
szLogMessageBuffer      DB 4096 DUP (0)
szLogOutputBuffer       DB 4096 DUP (0)

consoleAttached         DD 0
stderrHandle            DD NULL

szLogOutputFmt          DB "%s: %s",13,10,0

;szPriorityPrefixNull    DB 0,0
;szPriorityPrefixVerbose DB "VERBOSE",0
;szPriorityPrefixDebug   DB "DEBUG",0
szPriorityPrefixInfo    DB "INFO",0
;szPriorityPrefixWarn    DB "WARN",0
;szPriorityPrefixError   DB "ERROR",0
;szPriorityPrefixCrit    DB "CRITICAL",0

;szPriorityPrefixes      DD Offset szPriorityPrefixNull
;                        DD Offset szPriorityPrefixVerbose
;                        DD Offset szPriorityPrefixDebug
;                        DD Offset szPriorityPrefixInfo
;                        DD Offset szPriorityPrefixWarn
;                        DD Offset szPriorityPrefixError
;                        DD Offset szPriorityPrefixCrit
ENDIF

.CODE


IEEX_ALIGN
;------------------------------------------------------------------------------
; [LUA] l_log_print
; Taken from EE game's lua "Print" function
;------------------------------------------------------------------------------
OPTION PROLOGUE:NONE
OPTION EPILOGUE:NONE
l_log_print PROC C arg:VARARG
    push ebp
    mov ebp,esp
    push ebx
    push esi
    push edi
    mov edi,dword ptr [ebp+8h]
    push edi
    call lua_gettop
    mov ebx,eax
    mov esi,1h
    add esp,4h
    cmp ebx,esi
    jl LABEL_0x00516DCA
    lea ecx,dword ptr [ecx]
    
LABEL_0x00516D90:
    push esi
    push edi
    call lua_isstring
    add esp,8h
    test eax,eax
    je LABEL_0x00516DAF
    push 0h
    push esi
    push edi
    call lua_tolstring
    push eax
    push CTEXT("%s")
    jmp LABEL_0x00516DBD
    
LABEL_0x00516DAF:
    push esi
    push edi
    call lua_typename
    push eax
    push esi
    push CTEXT("Unable to convert arg %d a %s to string")
    
LABEL_0x00516DBD:
    call SDL_Log
    inc esi
    add esp,14h
    cmp esi,ebx
    jle LABEL_0x00516D90
    
LABEL_0x00516DCA:
    pop edi
    pop esi
    xor eax,eax
    pop ebx
    pop ebp
    ret 
l_log_print ENDP
OPTION PROLOGUE:PrologueDef
OPTION EPILOGUE:EpilogueDef


IFDEF IEEX_SDLINT
IEEX_ALIGN
;------------------------------------------------------------------------------
; SDL_Log
;------------------------------------------------------------------------------
SDL_Log PROC C lpszFmt:DWORD, lpszString:DWORD
    IFDEF DEBUG32
    PrintText 'SDL_Log'
    ENDIF
    Invoke SDL_LogMessageV, SDL_LOG_PRIORITY_INFO, lpszFmt, lpszString
    ret
SDL_Log ENDP


IEEX_ALIGN
;------------------------------------------------------------------------------
; SDL_LogMessageV
;------------------------------------------------------------------------------
SDL_LogMessageV PROC C priority:DWORD, lpszFmt:DWORD, lpszString:DWORD
    LOCAL len:DWORD

    IFDEF DEBUG32
    PrintText 'SDL_LogMessageV'
    ENDIF

    .IF sdword ptr priority < 0 || priority >= SDL_NUM_LOG_PRIORITIES
        ret
    .ENDIF
    
    ;Invoke RtlZeroMemory, Addr szLogMessageBuffer, 4096d
    Invoke wsprintf, Addr szLogMessageBuffer, lpszFmt, lpszString
    
;    Invoke lstrlen, Addr szLogMessageBuffer
;    mov len, eax
;    .IF eax > 0
;        lea ebx, szLogMessageBuffer
;        add ebx, len
;        dec ebx
;        movzx eax, byte ptr [ebx]
;        .IF al == 10d
;            mov byte ptr [ebx], 0h
;        .ENDIF
;        dec ebx
;        movzx eax, byte ptr [ebx]
;        .IF al == 13d
;            mov byte ptr [ebx], 0h
;        .ENDIF
;    .ENDIF

    Invoke SDL_LogOutput, priority, Addr szLogMessageBuffer

    ret
SDL_LogMessageV ENDP


IEEX_ALIGN
;------------------------------------------------------------------------------
; SDL_LogOutput
;------------------------------------------------------------------------------
SDL_LogOutput PROC C USES EBX ECX priority:DWORD, message:DWORD
    LOCAL attachResult:DWORD
    LOCAL attachError:DWORD
    LOCAL charsToWrite:DWORD
    LOCAL charsWritten:DWORD
    LOCAL consoleMode:DWORD
    LOCAL lpszPriority:DWORD
    
    IFDEF DEBUG32
    PrintText 'SDL_LogOutput'
    ENDIF
    
    .IF consoleAttached == 0
        
        Invoke AttachConsole, ATTACH_PARENT_PROCESS
        mov attachResult, eax
        
        .IF attachResult != TRUE
            Invoke  GetLastError
            mov attachError, eax
            .IF eax == ERROR_INVALID_HANDLE
                IFDEF DEBUG32
                PrintText 'Parent process has no console'
                ENDIF
                mov consoleAttached, -1
            .ELSEIF eax == ERROR_GEN_FAILURE
                IFDEF DEBUG32
                PrintText 'Could not attach to console of parent process'
                ENDIF
                mov consoleAttached, -1
            .ELSEIF eax == ERROR_ACCESS_DENIED
                IFDEF DEBUG32
                PrintText 'Already attached'
                ENDIF
                mov consoleAttached, 1
            .ELSE
                IFDEF DEBUG32
                PrintText 'Error attaching console'
                ENDIF
                mov consoleAttached, -1
            .ENDIF
            
        .ELSE
            IFDEF DEBUG32
            PrintText 'Newly attached'
            ENDIF
            mov consoleAttached, 1
        .ENDIF
        
        .IF consoleAttached == 1
            Invoke GetStdHandle, STD_ERROR_HANDLE
            mov stderrHandle, eax
        .ENDIF

    .ELSEIF eax == -1
        IFDEF IEEX_LOGGING
        .IF gIEexLog >= LOGLEVEL_DETAIL
            ;Invoke RtlZeroMemory, Addr szLogOutputBuffer, 4096d
            Invoke wsprintf, Addr szLogOutputBuffer, Addr szLogOutputFmt, Addr szPriorityPrefixInfo, message ; lpszPriority
            Invoke LogMessage, Addr szLogOutputBuffer, LOG_NONEWLINE, 0
        .ENDIF
        ENDIF
        ret

    .ENDIF
    
    ; Get priority text
;    mov ecx, priority
;    lea ebx, szPriorityPrefixes
;    lea eax, [ebx+ecx*4]
;    mov eax, [eax]
;    mov lpszPriority, eax
    
    ;Invoke RtlZeroMemory, Addr szLogOutputBuffer, 4096d
    Invoke wsprintf, Addr szLogOutputBuffer, Addr szLogOutputFmt, Addr szPriorityPrefixInfo, message ; lpszPriority

    .IF consoleAttached == 1
        Invoke lstrlen, Addr szLogOutputBuffer
        mov charsToWrite, eax
        Invoke WriteFile, stderrHandle, Addr szLogOutputBuffer, charsToWrite, Addr charsWritten, NULL
    .ENDIF
    
    IFDEF IEEX_LOGGING
    .IF gIEexLog >= LOGLEVEL_DETAIL
        Invoke LogMessage, Addr szLogOutputBuffer, LOG_NONEWLINE, 0
    .ENDIF
    ENDIF
    
    ret
SDL_LogOutput ENDP

ENDIF ; IEEX_SDLINT


