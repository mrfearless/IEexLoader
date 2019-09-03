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
IEexLuaBootstrap        PROTO                   ; 
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
l_log_print             PROTO C :VARARG         ; (lua_State)

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
    
    IFDEF IEEX_USESDL
    Invoke IEexLuaBootstrap
    ELSE
    Invoke luaL_newstate
    mov g_lua, eax
    Invoke luaL_openlibs, g_lua
    ENDIF
    
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
    Invoke luaL_loadfilex, g_lua, lpszLuaFile, CTEXT("t")
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
    
    Invoke lua_pcallk, g_lua, 0, LUA_MULTRET, 0, 0, 0
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


IFDEF IEEX_USESDL
IEEX_ALIGN
;------------------------------------------------------------------------------
; IEexLuaBootstrap: Initialize Lua
;------------------------------------------------------------------------------
IEexLuaBootstrap PROC

    Invoke luaL_newstate
    mov g_lua, eax
    
    Invoke luaL_requiref, g_lua, CTEXT("_G"), Addr luaopen_base, 1
    Invoke lua_settop, g_lua, -2
    
    Invoke lua_pushcclosure, g_lua, Addr l_log_print, 0
    Invoke lua_setglobal, g_lua, CTEXT("print")
    
    Invoke luaL_requiref, g_lua, CTEXT("table"), Addr luaopen_table, 1
    Invoke lua_settop, g_lua, -2
    
    Invoke luaL_requiref, g_lua, CTEXT("string"), Addr luaopen_string, 1
    Invoke lua_settop, g_lua, -2
    
    Invoke luaL_requiref, g_lua, CTEXT("bit32"), Addr luaopen_bit32, 1
    Invoke lua_settop, g_lua, -2
    
    Invoke luaL_requiref, g_lua, CTEXT("math"), Addr luaopen_math, 1
    Invoke lua_settop, g_lua, -2
    
    Invoke luaL_requiref, g_lua, CTEXT("debug"), Addr luaopen_debug, 1
    Invoke lua_settop, g_lua, -2

    ret
IEexLuaBootstrap ENDP
ENDIF


IEEX_ALIGN
;------------------------------------------------------------------------------
; IEexLuaRegisterFunction: Registers LUA Functions in IE Game
; Devnote: This function is PROTO STDCALL
;------------------------------------------------------------------------------
IEexLuaRegisterFunction PROC lpFunctionAddress:DWORD, lpszFunctionName:DWORD
    Invoke lua_pushcclosure, g_lua, lpFunctionAddress, 0
    Invoke lua_setglobal, g_lua, lpszFunctionName
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

    Invoke IEexLuaRegisterFunction, Addr IEex_AddressList, Addr szIEex_AddressList
    IFDEF IEEX_LOGGING
    .IF gIEexLog >= LOGLEVEL_DEBUG
        Invoke LogMessage, CTEXT("Register Function -  IEex_AddressList"), LOG_NONEWLINE, 1
        Invoke LogMessageAndHexValue, 0, Addr IEex_AddressList
    .ENDIF
    ENDIF

;    Invoke IEexLuaRegisterFunction, Addr IEex_ReadDWORD, Addr szIEex_ReadDWORD
;    IFDEF IEEX_LOGGING
;    .IF gIEexLog >= LOGLEVEL_DEBUG
;        Invoke LogMessage, CTEXT("Register Function -  IEex_ReadDWORD"), LOG_NONEWLINE, 1
;        Invoke LogMessageAndHexValue, 0, Addr IEex_ReadDWORD
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
    call lua_pushnumber
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
    call lua_tonumberx
    add esp, 0Ch
    call F__ftol2_sse
    mov edi, eax
    push 0h
    push 2h
    push dword ptr [ebp+8h]
    call lua_tonumberx
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
    call lua_tonumberx
    add esp, 0Ch
    call F__ftol2_sse
    push 0h
    push eax
    push dword ptr [g_lua]
    call lua_pushcclosure
    add esp, 0Ch
    push 0h
    push 2h
    push dword ptr [ebp+8h]
    call lua_tolstring
    add esp, 0Ch
    push eax
    push dword ptr [g_lua]
    call lua_setglobal
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
	call lua_rawlen
	add esp, 8h
	test eax, eax
	je no_args
	mov edi, eax
	mov esi, 1;#01
arg_loop:
	push esi
	push 2h
	push dword ptr [ebp+8h]
	call lua_rawgeti
	add esp, 0Ch
	push 0h
	push 0FFh
	push dword ptr [ebp+8h]
	call lua_tonumberx
	add esp, 0Ch
	call F__ftol2_sse
	push eax
	push 0FEh
	push dword ptr [ebp+8h]
	call lua_settop
	add esp, 8h
	inc esi
	cmp esi, edi
	jle arg_loop
no_args:
	push 0h
	push 3h
	push dword ptr [ebp+8h]
	call lua_tonumberx
	add esp, 0Ch
	call F__ftol2_sse
	push eax
	push 0h
	push 1h
	push dword ptr [ebp+8h]
	call lua_tonumberx
	add esp, 0Ch
	call F__ftol2_sse
	pop ecx
	call eax
	push eax
	fild dword ptr [esp]
	sub esp, 4h
	fstp qword ptr [esp]
	push dword ptr [ebp+8h]
	call lua_pushnumber
	add esp, 0Ch
	push 0h
	push 4h
	push dword ptr [ebp+8h]
	call lua_tonumberx
	add esp, 0Ch
	call F__ftol2_sse
	add esp, eax
	mov eax, 1;#01
    pop ebp
    ret 
IEex_Call ENDP
OPTION PROLOGUE:PrologueDef
OPTION EPILOGUE:EpilogueDef


IEEX_ALIGN
;------------------------------------------------------------------------------
; [LUA] IEex_AddressList: Return a table of function and global addresses
;
; IEex_AddressList()
;------------------------------------------------------------------------------
IEex_AddressList PROC C USES EBX lua_State:DWORD
    LOCAL qwAddress:QWORD
    
    IFDEF IEEX_LOGGING
    IFDEF IEEX_LOGLUACALLS
    .IF gIEexLog >= LOGLEVEL_DEBUG
        Invoke LogMessage, Addr szIEex_AddressList, LOG_STANDARD, 1
    .ENDIF
    ENDIF
    ENDIF
    
    Invoke lua_createtable, lua_State, 0, 34

    Invoke lua_pushstring, lua_State, Addr szGetProcAddress
    fild F_GetProcAddress
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3
    
    Invoke lua_pushstring, lua_State, Addr szLoadLibrary
    fild F_LoadLibrary
    fstp qword ptr [qwAddress]     
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("__ftol2_sse")
    fild F__ftol2_sse
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_malloc")
    fild F_Malloc
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_free")
    fild F_Free
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_luaL_newstate")
    fild F_LuaL_newstate
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_luaL_openlibs")
    fild F_LuaL_openlibs
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_luaL_loadfilex") 
    fild F_LuaL_loadfilex
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_createtable") 
    fild F_Lua_createtable
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_getglobal") 
    fild F_Lua_getglobal
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_gettop") 
    fild F_Lua_gettop
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_pcallk") 
    fild F_Lua_pcallk
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_pushcclosure") 
    fild F_Lua_pushcclosure
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_pushlightuserdata") 
    fild F_Lua_pushlightuserdata
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_pushlstring") 
    fild F_Lua_pushlstring
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_pushnumber") 
    fild F_Lua_pushnumber
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_pushstring") 
    fild F_Lua_pushstring
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_rawgeti") 
    fild F_Lua_rawgeti
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_rawlen") 
    fild F_Lua_rawlen
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_setfield") 
    fild F_Lua_setfield
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_setglobal") 
    fild F_Lua_setglobal
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_settable") 
    fild F_Lua_settable
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_settop") 
    fild F_Lua_settop
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_toboolean") 
    fild F_Lua_toboolean
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_tolstring") 
    fild F_Lua_tolstring
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_tonumberx") 
    fild F_Lua_tonumberx
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_touserdata") 
    fild F_Lua_touserdata
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_type") 
    fild F_Lua_type
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_lua_typename") 
    fild F_Lua_typename
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_luaL_loadstring") 
    fild F_LuaL_loadstring
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

    Invoke lua_pushstring, lua_State, CTEXT("_g_lua") 
    fild g_lua
    fstp qword ptr [qwAddress]
    Invoke lua_pushnumber, lua_State, qwAddress
    Invoke lua_settable, lua_State, -3

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
;    Invoke lua_pushnumber, lua_State, qwAddressContent
;    mov eax, 1
;    ret
IEex_ReadDWORD ENDP


IFDEF IEEX_USESDL
IEEX_ALIGN
;------------------------------------------------------------------------------
; [LUA] l_log_print
;
; 
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
    push CTEXT("LPRINT: %s")
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
ENDIF


