;------------------------------------------------------------------------------
; IEex.DLL - Loader for IEex to inject IEex.dll by github.com/mrfearless
;
; IEex by Bubb: github.com/Bubb13/IEex 
;
;------------------------------------------------------------------------------

IEEX_LOGLUACALLS        EQU 1 ; comment out to disable logging of the lua calls
                              ; requires gIEexLog >= LOGLEVEL_DEBUG if using
                              
;------------------------------------------------------------------------------
; Devnote: Static lua lib functions that dont work/crash:
; luaL_loadstring, lua_setglobal
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; IEexLua Prototypes
;------------------------------------------------------------------------------
IEexLuaInit             PROTO   :DWORD          ; lpszLuaFile
IEexLuaRegisterFunction PROTO   :DWORD, :DWORD  ; lpFuncAddress, lpszFuncName

;------------------------------------------------------------------------------
; LUA Function Prototypes
;------------------------------------------------------------------------------
IEex_Init               PROTO C :VARARG         ; (lua_State)
IEex_WriteByte          PROTO C :VARARG         ; (lua_State), Address, Byte
IEex_ExposeToLua        PROTO C :VARARG         ; (lua_State), FunctionAddress, FunctionName
IEex_Call               PROTO C :VARARG         ; (lua_State)

IEex_AddressList        PROTO C :DWORD          ; (lua_State)
;IEex_ReadDWORD          PROTO C :DWORD, :DWORD  ; (lua_State), dwAddress

IFDEF IEEX_LUALIB       ; use this internal one rather than static version as it crashes
lua_setglobalx          PROTO C :DWORD, :DWORD  ; (lua_State), Name
ENDIF



;------------------------------------------------------------------------------
; IEexLua Structures
;------------------------------------------------------------------------------
ALENTRY                 STRUCT ; Address List entry for pAddressList array
    lpszName            DD 0
    dwAddress           DD 0
ALENTRY                 ENDS


.CONST
IFDEF IEEX_LOGLUACALLS
IEEX_WRITEBYTE_LOGCOUNT EQU 2048                ; logs IEex_WriteByte every x calls
ENDIF

.DATA
szIEex_Init             DB "IEex_Init",0        
szIEex_WriteByte        DB "IEex_WriteByte",0   
szIEex_ExposeToLua      DB "IEex_ExposeToLua",0
szIEex_Call             DB "IEex_Call",0
szIEex_AddressList      DB "IEex_AddressList",0
;szIEex_ReadDWORD        DB "IEex_ReadDWORD",0

pAddressList            DD 0 ; points to array of ALENTRY entries x TotalPatterns 

IFDEF IEEX_LOGLUACALLS
IEex_WriteByte_Count    DD 0
ENDIF


.CODE


IEEX_ALIGN
;------------------------------------------------------------------------------
; IEexLuaInit: Initialize IEex for the IE Game
; Registers IEex_Init LUA Function
;------------------------------------------------------------------------------
IEexLuaInit PROC lpszLuaFile:DWORD

    IFDEF DEBUG32
    PrintText 'IEexLuaInit'
    ENDIF

    Invoke F_LuaL_newstate
    mov g_lua, eax

    Invoke F_LuaL_openlibs, g_lua
    
    IFDEF IEEX_LOGGING
    ;--------------------------------------------------------------------------
    ; Log some EE game globals
    ;--------------------------------------------------------------------------
    .IF gIEexLog >= LOGLEVEL_DEBUG
        Invoke LogMessage, CTEXT("IEexLuaInit:"), LOG_INFO, 0
        Invoke LogMessage, CTEXT("g_lua"), LOG_NONEWLINE, 1
        Invoke LogMessageAndHexValue, 0, g_lua    
        Invoke LogMessage, 0, LOG_CRLF, 0
    .ENDIF
    ENDIF

    ;--------------------------------------------------------------------------
    ; Register the Lua IEex_Init
    ;--------------------------------------------------------------------------
    Invoke IEexLuaRegisterFunction, Addr IEex_Init, Addr szIEex_Init
    IFDEF IEEX_LOGGING
    .IF gIEexLog >= LOGLEVEL_DEBUG
        Invoke LogMessage, CTEXT("Register Function -  IEex_Init"), LOG_NONEWLINE, 1
        Invoke LogMessageAndHexValue, 0, Addr IEex_Init
    .ENDIF    
    ENDIF
    
    IFDEF IEEX_LOGGING
    .IF gIEexLog >= LOGLEVEL_DEBUG
        Invoke LogMessage, CTEXT("Loading IEex lua file: "), LOG_NONEWLINE, 1
        Invoke LogMessage, lpszLuaFile, LOG_STANDARD, 0
    .ENDIF    
    ENDIF
    Invoke F_LuaL_loadfilex, g_lua, lpszLuaFile, CTEXT("t")
    .IF eax != LUA_OK
        IFDEF IEEX_LOGGING
        .IF gIEexLog >= LOGLEVEL_DEBUG
            Invoke LogMessage, CTEXT("Error loading IEex lua file"), LOG_STANDARD, 1
        .ENDIF    
        ENDIF
        IFDEF DEBUG32
        PrintText 'F_LuaL_loadfilex error'
        ENDIF
        .IF eax == LUA_ERRFILE ; cannot open or read the file
        
        .ELSEIF eax == LUA_ERRSYNTAX ; syntax error during precompilation
        
        .ELSEIF eax == LUA_ERRMEM ; memory allocation (out-of-memory) error
        
        .ELSEIF eax == LUA_ERRGCMM ; error while running a __gc metamethod
        
        .ENDIF
        mov eax, FALSE
        ret
    .ENDIF
    IFDEF IEEX_LOGGING
    .IF gIEexLog >= LOGLEVEL_DEBUG
        Invoke LogMessage, CTEXT("Successfully loaded IEex lua file"), LOG_STANDARD, 1
    .ENDIF    
    ENDIF
    
    IFDEF IEEX_LOGGING
    .IF gIEexLog >= LOGLEVEL_DEBUG
        Invoke LogMessage, CTEXT("Executing IEex lua file"), LOG_STANDARD, 1
    .ENDIF    
    ENDIF
    
    Invoke F_Lua_pcallk, g_lua, 0, LUA_MULTRET, 0, 0, 0
    .IF eax != LUA_OK
        IFDEF IEEX_LOGGING
        .IF gIEexLog >= LOGLEVEL_DEBUG
            Invoke LogMessage, CTEXT("Error executing IEex lua file"), LOG_STANDARD, 1
        .ENDIF    
        ENDIF
        IFDEF DEBUG32
        PrintText 'F_Lua_pcallk error'
        ENDIF
        .IF eax == LUA_ERRRUN ; a runtime error
        
        .ELSEIF eax == LUA_ERRMEM ; memory allocation error
        
        .ELSEIF eax == LUA_ERRERR ;  error while running the message handler.
        
        .ELSEIF eax == LUA_ERRGCMM ; error while running a __gc metamethod
        
        .ENDIF
        mov eax, FALSE
        ret
    .ENDIF
    
    mov eax, TRUE
    ret
IEexLuaInit ENDP


IEEX_ALIGN
;------------------------------------------------------------------------------
; IEexLuaRegisterFunction: Registers LUA Functions in IE Game
; Devnote: This function is PROTO STDCALL
;------------------------------------------------------------------------------
IEexLuaRegisterFunction PROC lpFunctionAddress:DWORD, lpszFunctionName:DWORD
    Invoke F_Lua_pushcclosure, g_lua, lpFunctionAddress, 0
    Invoke F_Lua_setglobal, g_lua, lpszFunctionName
    ret
IEexLuaRegisterFunction ENDP


IEEX_ALIGN
;------------------------------------------------------------------------------
; [LUA] IEex_Init: Registers LUA Functions and allocates global memory for IEex
; 
; IEex_Init()
;------------------------------------------------------------------------------
OPTION PROLOGUE:NONE
OPTION EPILOGUE:NONE
IEex_Init PROC C arg:VARARG
    push ebp
    mov ebp, esp

    IFDEF DEBUG32
    PrintText 'IEex_Init'
    ENDIF
    IFDEF IEEX_LOGGING
    .IF gIEexLog >= LOGLEVEL_DEBUG
        Invoke LogMessage, 0, LOG_CRLF, 0
        Invoke LogMessage, CTEXT("IEex_Init:"), LOG_INFO, 0
    .ENDIF
    ENDIF
    
    Invoke IEexLuaRegisterFunction, Addr IEex_WriteByte, Addr szIEex_WriteByte
    IFDEF IEEX_LOGGING
    .IF gIEexLog >= LOGLEVEL_DEBUG
        Invoke LogMessage, CTEXT("Register Function -  IEex_WriteByte"), LOG_NONEWLINE, 1
        Invoke LogMessageAndHexValue, 0, Addr IEex_WriteByte
    .ENDIF
    ENDIF
    Invoke IEexLuaRegisterFunction, Addr IEex_ExposeToLua, Addr szIEex_ExposeToLua
    IFDEF IEEX_LOGGING
    .IF gIEexLog >= LOGLEVEL_DEBUG
        Invoke LogMessage, CTEXT("Register Function -  IEex_ExposeToLua"), LOG_NONEWLINE, 1
        Invoke LogMessageAndHexValue, 0, Addr IEex_ExposeToLua
    .ENDIF
    ENDIF
    
    Invoke IEexLuaRegisterFunction, Addr IEex_Call, Addr szIEex_Call
    IFDEF IEEX_LOGGING
    Invoke LogMessage, CTEXT("Register Function -  IEex_Call"), LOG_NONEWLINE, 1
    Invoke LogMessageAndHexValue, 0, Addr IEex_Call
    ENDIF
;
;    Invoke IEexLuaRegisterFunction, Addr IEex_AddressList, Addr szIEex_AddressList
;    IFDEF IEEX_LOGGING
;    .IF gIEexLog >= LOGLEVEL_DEBUG
;        Invoke LogMessage, CTEXT("Register Function -  IEex_AddressList"), LOG_NONEWLINE, 1
;        Invoke LogMessageAndHexValue, 0, Addr IEex_AddressList
;    .ENDIF
;    ENDIF






;    Invoke IEexLuaRegisterFunction, Addr IEex_ReadDWORD, Addr szIEex_ReadDWORD
;    IFDEF IEEX_LOGGING
;    .IF gIEexLog >= LOGLEVEL_DEBUG
;        Invoke LogMessage, CTEXT("Register Function -  IEex_ReadDWORD"), LOG_NONEWLINE, 1
;        Invoke LogMessageAndHexValue, 0, Addr IEex_ReadDWORD
;    .ENDIF
;    ENDIF
    
;    Invoke IEexLuaRegisterFunction, Addr IEex_AddressListAsm, Addr szIEex_AddressListAsm
;    IFDEF IEEX_LOGGING
;    .IF gIEexLog >= LOGLEVEL_DEBUG
;        Invoke LogMessage, CTEXT("Register Function -  IEex_AddressListAsm"), LOG_NONEWLINE, 1
;        Invoke LogMessageAndHexValue, 0, Addr IEex_AddressListAsm
;    .ENDIF
;    ENDIF    
;    
;    Invoke IEexLuaRegisterFunction, Addr IEex_AddressListCount, Addr szIEex_AddressListCount
;    IFDEF IEEX_LOGGING
;    .IF gIEexLog >= LOGLEVEL_DEBUG
;        Invoke LogMessage, CTEXT("Register Function -  IEex_AddressListCount"), LOG_NONEWLINE, 1
;        Invoke LogMessageAndHexValue, 0, Addr IEex_AddressListCount
;    .ENDIF
;    ENDIF      

    IFDEF IEEX_LOGGING
    .IF gIEexLog >= LOGLEVEL_DEBUG
        Invoke LogMessage, 0, LOG_CRLF, 0
        Invoke LogMessage, CTEXT("VirtualAlloc 4096 bytes"), LOG_INFO, 0
        Invoke LogMessage, 0, LOG_CRLF, 0
    .ENDIF
    IFDEF IEEX_LOGLUACALLS
    .IF gIEexLog >= LOGLEVEL_DEBUG
        Invoke LogMessage, CTEXT("IEex Lua Functions: "), LOG_INFO, 0
    .ENDIF
    ENDIF
    ENDIF
    
    IFDEF DEBUG32
    PrintText 'VirtualAlloc'
    ENDIF    
    
    Invoke VirtualAlloc, 0, 1000h, MEM_COMMIT or MEM_RESERVE, PAGE_EXECUTE_READWRITE
    push eax
    fild dword ptr [esp]
    sub esp, 4h
    fstp qword ptr [esp]
    push dword ptr [ebp+8h]
    call F_Lua_pushnumber
    add esp,0Ch
    mov eax,1h
    pop ebp
    ret
IEex_Init ENDP
OPTION PROLOGUE:PrologueDef
OPTION EPILOGUE:EpilogueDef


IEEX_ALIGN
;------------------------------------------------------------------------------
; [LUA] IEex_WriteByte: Writes byte at address
;
; IEex_WriteByte(Address, Byte)
;------------------------------------------------------------------------------
OPTION PROLOGUE:NONE
OPTION EPILOGUE:NONE
IEex_WriteByte PROC C arg:VARARG
    push ebp
    mov ebp, esp
    IFDEF IEEX_LOGGING
    IFDEF IEEX_LOGLUACALLS
    .IF gIEexLog >= LOGLEVEL_DEBUG
        .IF IEex_WriteByte_Count == 0
            IFDEF DEBUG32
            PrintText 'IEex_WriteByte'
            ENDIF             
            Invoke LogMessage, Addr szIEex_WriteByte, LOG_STANDARD, 1
        .ENDIF
        inc IEex_WriteByte_Count
        mov eax, IEex_WriteByte_Count
        .IF eax >= IEEX_WRITEBYTE_LOGCOUNT
            mov IEex_WriteByte_Count, 0
        .ENDIF
    .ENDIF
    ENDIF
    ENDIF
    push 0h
    push 1h
    push dword ptr [ebp+8h]
    call F_Lua_tonumberx
    add esp, 0Ch
    call F__ftol2_sse
    mov edi, eax
    push 0h
    push 2h
    push dword ptr [ebp+8h]
    call F_Lua_tonumberx
    add esp, 0Ch
    call F__ftol2_sse
    mov byte ptr [edi], al
    mov eax, 0h
    pop ebp
    ret 
IEex_WriteByte ENDP
OPTION PROLOGUE:PrologueDef
OPTION EPILOGUE:EpilogueDef


IEEX_ALIGN
;------------------------------------------------------------------------------
; [LUA] IEex_ExposeToLua: Expose EE Internal Function to LUA
;
; IEex_ExposeToLua(FunctionAddress, FunctionName)
;------------------------------------------------------------------------------
OPTION PROLOGUE:NONE
OPTION EPILOGUE:NONE
IEex_ExposeToLua PROC C arg:VARARG
    push ebp
    mov ebp, esp
    
    IFDEF DEBUG32
    PrintText 'IEex_ExposeToLua'
    ENDIF        
    
    IFDEF IEEX_LOGGING
    IFDEF IEEX_LOGLUACALLS
    .IF gIEexLog >= LOGLEVEL_DEBUG
        Invoke LogMessage, Addr szIEex_ExposeToLua, LOG_STANDARD, 1
    .ENDIF
    ENDIF
    ENDIF    
    push 0h
    push 1h
    push dword ptr [ebp+8h]
    call F_Lua_tonumberx
    add esp, 0Ch
    call F__ftol2_sse
    push 0h
    push eax
    push dword ptr [g_lua]
    call F_Lua_pushcclosure
    add esp, 0Ch
    push 0h
    push 2h
    push dword ptr [ebp+8h]
    call F_Lua_tolstring
    add esp, 0Ch
    push eax
    push dword ptr [g_lua]
    call F_Lua_setglobal
    add esp, 8h
    mov eax, 0h
    pop ebp
    ret 
IEex_ExposeToLua ENDP
OPTION PROLOGUE:PrologueDef
OPTION EPILOGUE:EpilogueDef


IEEX_ALIGN
;------------------------------------------------------------------------------
; [LUA] IEex_Call: Calls an internal function at the given address.
;
; IEex_Call(number address, table stackArgs, number ecx, number popSize)
;------------------------------------------------------------------------------
OPTION PROLOGUE:NONE
OPTION EPILOGUE:NONE
IEex_Call PROC C arg:VARARG
    push ebp
    mov ebp, esp
	push 2h
	push dword ptr [ebp+8h]
	call F_Lua_rawlen
	add esp, 8h
	test eax, eax
	je no_args
	mov edi, eax
	mov esi, 1;#01
arg_loop:
	push esi
	push 2h
	push dword ptr [ebp+8h]
	call F_Lua_rawgeti
	add esp, 0Ch
	push 0h
	push 0FFh
	push dword ptr [ebp+8h]
	call F_Lua_tonumberx
	add esp, 0Ch
	call F__ftol2_sse
	push eax
	push 0FEh
	push dword ptr [ebp+8h]
	call F_Lua_settop
	add esp, 8h
	inc esi
	cmp esi, edi
	jle arg_loop
no_args:
	push 0h
	push 3h
	push dword ptr [ebp+8h]
	call F_Lua_tonumberx
	add esp, 0Ch
	call F__ftol2_sse
	push eax
	push 0h
	push 1h
	push dword ptr [ebp+8h]
	call F_Lua_tonumberx
	add esp, 0Ch
	call F__ftol2_sse
	pop ecx
	call eax
	push eax
	fild dword ptr [esp]
	sub esp, 4h
	fstp qword ptr [esp]
	push dword ptr [ebp+8h]
	call F_Lua_pushnumber
	add esp, 0Ch
	push 0h
	push 4h
	push dword ptr [ebp+8h]
	call F_Lua_tonumberx
	add esp, 0Ch
	call F__ftol2_sse
	add esp, eax
	mov eax, 1;#01
    pop ebp
    ret 
IEex_Call ENDP
OPTION PROLOGUE:PrologueDef
OPTION EPILOGUE:EpilogueDef


;------------------------------------------------------------------------------
; [LUA] lua_setglobalx: Alternative version of lua_setglobal
;
; lua_setglobalx(luastate, name)
;------------------------------------------------------------------------------
IFDEF IEEX_LUALIB
IEEX_ALIGN
OPTION PROLOGUE:NONE
OPTION EPILOGUE:NONE
lua_setglobalx PROC C USES EBX ESI lua_State:DWORD, lpname:DWORD
    push ebp
    mov ebp,esp
    push ebx
    push esi
    mov esi, lua_State
    mov edx,2h
    push edi
    mov eax,dword ptr [esi+0Ch]
    mov ecx,dword ptr [eax+28h]
    call luaH_getint
    mov edi,dword ptr [esi+8h]
    mov ebx,eax
    mov edx, dword ptr [lpname]
    lea ecx,dword ptr [edi+8h]
    mov dword ptr [esi+8h],ecx
    mov ecx,edx
    lea eax,dword ptr [ecx+1h]
    mov [lua_State], eax
    nop 
    
LABEL_1:
    mov al,byte ptr [ecx]
    inc ecx
    test al,al
    jne LABEL_1
    sub ecx, lua_State
    push ecx
    mov ecx,esi
    call luaS_newlstr
    mov dword ptr [edi],eax
    mov edx,ebx
    movzx eax,byte ptr [eax+4h]
    or eax,7FF7A540h
    mov dword ptr [edi+4h],eax
    mov ecx,dword ptr [esi+8h]
    lea eax,dword ptr [ecx-10h]
    push eax
    lea eax,dword ptr [ecx-8h]
    mov ecx,esi
    push eax
    call luaV_settable
    add esp,0Ch
    add dword ptr [esi+8h],0FFFFFFF0h
    pop edi
    pop esi
    pop ebx
    pop ebp
    ret     
lua_setglobalx ENDP
OPTION PROLOGUE:PrologueDef
OPTION EPILOGUE:EpilogueDef
ENDIF


IEEX_ALIGN
;------------------------------------------------------------------------------
; [LUA] IEex_AddressList: Return a table of function and global addresses
;
; IEex_AddressList()
;------------------------------------------------------------------------------
IEex_AddressList PROC C USES EBX lua_State:DWORD
    LOCAL nPattern:DWORD
    LOCAL ptrCurrentPattern:DWORD
    LOCAL lpszPatternName:DWORD
    LOCAL dwPatternAddress:DWORD
    LOCAL nTotal:DWORD
    LOCAL nCount:DWORD
    LOCAL pT2Array:DWORD
    LOCAL pT2Entry:DWORD
    LOCAL qwAddress:QWORD
    LOCAL qwIndex:QWORD
    
    IFDEF IEEX_LOGGING
    IFDEF IEEX_LOGLUACALLS
    .IF gIEexLog >= LOGLEVEL_DEBUG
        Invoke LogMessage, Addr szIEex_AddressList, LOG_STANDARD, 1
    .ENDIF
    ENDIF
    ENDIF
    
;    mov eax, TotalPatterns
;    add eax, 3 ; for extra at end
;    Invoke F_Lua_createtable, lua_State, 0, eax
;
;    mov ebx, PatternsDatabase
;    mov ptrCurrentPattern, ebx
;    mov nPattern, 0
;    mov eax, 0
;    .WHILE eax < TotalPatterns
;        .IF [ebx].PATTERN.bFound == TRUE
;            mov eax, [ebx].PATTERN.PatName
;            mov lpszPatternName, eax
;            
;            .IF [ebx].PATTERN.PatType == 2
;                ;--------------------------------------------------------------
;                ; Handle type 2 pattern: name=table/array of addresses
;                ;--------------------------------------------------------------
;                mov eax, [ebx].PATTERN.VerAdj ; used to store count of array entries
;                mov nTotal, eax
;                mov eax, [ebx].PATTERN.PatAddress ; used to store pointer to array
;                .IF eax != NULL && nTotal != 0
;                    mov pT2Array, eax
;                    mov pT2Entry, eax
;                    
;                    Invoke F_Lua_pushstring, lua_State, lpszPatternName
;                    Invoke F_Lua_createtable, lua_State, 0, nCount
;                    mov nCount, 0
;                    mov eax, 0
;                    .WHILE eax < nTotal
;                        mov ebx, pT2Entry
;                        mov eax, [ebx]
;                        mov dwPatternAddress, eax
;                        
;                        inc nCount ; for lua 1 based indexes
;                        fild nCount
;                        dec nCount ; restore nCount to its proper value for loop condition
;                        fstp qword ptr [qwIndex]
;                        Invoke F_Lua_pushnumber, lua_State, qwIndex
;                        fild dwPatternAddress
;                        fstp qword ptr [qwAddress]            
;                        Invoke F_Lua_pushnumber, lua_State, qwAddress ; dwPatternAddress
;                        Invoke F_Lua_settable, lua_State, -3
;                        
;                        add pT2Entry, SIZEOF DWORD
;                        inc nCount
;                        mov eax, nCount
;                    .ENDW
;                    Invoke F_Lua_settable, lua_State, -3
;                    
;                .ENDIF
;                
;            .ELSE
;                ;--------------------------------------------------------------
;                ; Handle all other pattern types: name=address / var=value
;                ;--------------------------------------------------------------
;                mov eax, [ebx].PATTERN.PatAddress
;                mov dwPatternAddress, eax
;                Invoke F_Lua_pushstring, lua_State, lpszPatternName
;                fild dwPatternAddress
;                fstp qword ptr [qwAddress]            
;                Invoke F_Lua_pushnumber, lua_State, qwAddress ; dwPatternAddress
;                Invoke F_Lua_settable, lua_State, -3
;            .ENDIF
;            
;        .ENDIF
;        add ptrCurrentPattern, SIZEOF PATTERN
;        mov ebx, ptrCurrentPattern
;        inc nPattern
;        mov eax, nPattern
;    .ENDW

    ; handle special cases, like GetProcAddress, LoadLibrary etc
    Invoke F_Lua_pushstring, lua_State, Addr szGetProcAddress
    fild F_GetProcAddress
    fstp qword ptr [qwAddress]      
    Invoke F_Lua_pushnumber, lua_State, qwAddress ; F_GetProcAddress
    Invoke F_Lua_settable, lua_State, -3
    
    Invoke F_Lua_pushstring, lua_State, Addr szLoadLibrary
    fild F_LoadLibrary
    fstp qword ptr [qwAddress]     
    Invoke F_Lua_pushnumber, lua_State, qwAddress ; F_LoadLibrary
    Invoke F_Lua_settable, lua_State, -3
    
    ;Invoke F_Lua_setglobal, lua_State, Addr szIEex_LuaAddressList
    
    mov eax, 1
    ret
IEex_AddressList ENDP


IEEX_ALIGN
;------------------------------------------------------------------------------
; [LUA] IEex_ReadDWORD: Read DWORD at address
;
; IEex_ReadDWORD(Address)
;------------------------------------------------------------------------------
IEex_ReadDWORD PROC C USES EBX lua_State:DWORD, dwAddress:DWORD
;    LOCAL qwAddressContent:QWORD
;    LOCAL dwAddressContent:DWORD
;    
;    .IF dwAddress == 0
;        xor eax, eax
;        ret
;    .ENDIF
;    
;    mov ebx, dwAddress
;    mov eax, [ebx]
;    mov dwAddressContent, eax
;    
;    fild dwAddressContent
;    fstp qword ptr [qwAddressContent]            
;    Invoke F_Lua_pushnumber, lua_State, qwAddressContent
;    mov eax, 1
;    ret
IEex_ReadDWORD ENDP





