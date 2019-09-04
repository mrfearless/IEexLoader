;------------------------------------------------------------------------------
; IEex.DLL - Loader for IEex to inject IEex.dll by github.com/mrfearless
;
; IEex by Bubb: github.com/Bubb13/IEex 
;
;------------------------------------------------------------------------------
include windows.inc

include user32.inc
include kernel32.inc
include psapi.inc
include version.inc

includelib user32.lib
includelib kernel32.lib
includelib psapi.lib
includelib version.lib

IFDEF IEEX_LUALIB
include lua52.inc
includelib lua523.lib ; nil value for lua_setglobal
includelib msvcrt12.lib
ELSE ; for lua52.dll
include lua52.inc
includelib lua52dll.lib
ECHO Using LUA Dynamic Link Library
ENDIF
IFDEF IEEX_SDLDLL
include SDL2.inc
includelib SDL2dll.lib
ECHO Using SDL Dynamic Link Library
ELSE
include SDL2.inc
includelib SDLlog.lib ;SDL2.lib
;includelib msvcrt12.lib
ECHO Using SDL Static Library
ENDIF

;------------------------------------------------------------------------------
; IEex.dll Prototypes
;------------------------------------------------------------------------------
IEexInitDll             PROTO                            ;
IEexInitGlobals         PROTO                            ;

IEexLogInformation      PROTO :DWORD                     ; dwType
IEexIEFileInformation   PROTO                            ;
IEexIEGameInformation   PROTO                            ;

IEexDwordToAscii        PROTO :DWORD,:DWORD              ; dwValue, lpszAsciiString
IEexAsciiHexToDword     PROTO :DWORD                     ; lpszAsciiHexString
IEexDwordToAsciiHex     PROTO :DWORD,:DWORD,:DWORD       ; dwValue, lpszAsciiHexString, bUppercase

IEexRawToHexString      PROTO :DWORD,:DWORD,:DWORD,:DWORD; lpRaw, dwRawSize, lpszAsciiHexString, bUpperCase
IEexHexStringToRaw      PROTO :DWORD,:DWORD              ; lpszAsciiHexString, lpRaw

PUBLIC g_lua


;------------------------------------------------------------------------------
; IEex.dll Structures
;------------------------------------------------------------------------------
IFNDEF MODULEINFO
MODULEINFO              STRUCT
    lpBaseOfDll         LPVOID ?
    SizeOfImage         DWORD ?
    EntryPoint          LPVOID ?
MODULEINFO              ENDS  
ENDIF

IFNDEF LANGANDCODEPAGE
LANGANDCODEPAGE         STRUCT
   wLanguage            DW ?
   wCodepage            DW ?
LANGANDCODEPAGE         ENDS
ENDIF


.CONST
LUA_OK		            EQU 0
LUA_YIELD	            EQU 1
LUA_ERRRUN	            EQU 2
LUA_ERRSYNTAX	        EQU 3
LUA_ERRMEM	            EQU 4
LUA_ERRGCMM	            EQU 5
LUA_ERRERR	            EQU 6
LUA_ERRFILE             EQU (LUA_ERRERR+1)

LUA_MULTRET	            EQU (-1)

; IEexLogInformation dwType:
INFO_ALL                EQU 0
INFO_GAME               EQU 1
INFO_DEBUG              EQU 2
INFO_IMPORTED           EQU 3
INFO_VERIFIED           EQU 4
INFO_SEARCHED           EQU 5
INFO_ADDRESSES          EQU 6

; IE Game Type:
GAME_UNKNOWN            EQU 0h
GAME_BG                 EQU 1h
GAME_BG2                EQU 2h
GAME_IWD                EQU 4h
GAME_IWD2               EQU 8h
GAME_PST                EQU 10h


.DATA
;------------------------------------------------------------------------------
; IEex.dll Initialized Data
;------------------------------------------------------------------------------
AppName                 DB "IEex.dll",0

szBioware_BG            DB "BGMAIN.EXE",0
szBioware_BG2           DB "BGMAIN.EXE",0
szBlackIsle_IWD         DB "IDMMAIN.EXE",0
szBlackIsle_IWD2        DB "IWD2.EXE",0
szBlackIsle_PST         DB "TORMENT.EXE",0
szBioware_BG2_Name      DB "Baldur's Gate II - Shadows of Amn - Throne of Bhaal",0
gIEGameType             DD 0 ; Bioware / Black Isle Studio's IE Game Type
szOverride              DB "\override\",0
szM__IEexlua            DB "M__IEex.lua",0

;---------------------------
; Error Log Messages
;---------------------------
szErrorGetModuleInfo    DB "GetModuleInformation Failed",0
szErrorImageDosSig      DB "IMAGE_DOS_SIGNATURE Failed",0
szErrorImageNtSig       DB "IMAGE_NT_SIGNATURE Failed",0
szErrorLuaDll           DB "Cannot load or find lua52.dll - aborting.",0

;---------------------------
; Version Info
;---------------------------
szVerRoot               DB "\\",0
szLang                  DB "\VarFileInfo\Translation",0
szProductVersion        DB "\StringFileInfo\%04x%04x\ProductVersion",0
szProductName           DB "\StringFileInfo\%04x%04x\ProductName",0
szFileVersion           DB "%d.%d.%d.%d",0

;---------------------------
; Functions/globals names:
;---------------------------
szGetProcAddress        DB "__imp__GetProcAddress",0
szLoadLibrary           DB "__imp__LoadLibraryA",0
szGetProcAddressProc    DB "GetProcAddress",0
szLoadLibraryProc       DB "LoadLibraryA",0
sz_ftol2_sse            DB "_ftol2_sse",0
sz_malloc               DB "malloc",0
sz_free                 DB "free",0
szKernel32Dll           DB "kernel32.dll",0
szMsvcrtDll             DB "msvcrt.dll",0

F_GetProcAddress        DD 0 ; 
F_LoadLibrary           DD 0 ;
g_lua                   DD 0 ; actual content of global lua variable

IFNDEF IEEX_LUALIB
szLuaDLL                DB "lua52.dll",0
szLuaL_newstate         DB "luaL_newstate",0
szLuaL_openlibs         DB "luaL_openlibs",0
szLuaL_loadfilex        DB "luaL_loadfilex",0
szLua_createtable       DB "lua_createtable",0
szLua_createtablex      DB "lua_createtablex",0
szLua_getglobal         DB "lua_getglobal",0
szLua_gettop            DB "lua_gettop",0
szLua_pcallk            DB "lua_pcallk",0
szLua_pushcclosure      DB "lua_pushcclosure",0
szLua_pushlightuserdata DB "lua_pushlightuserdata",0
szLua_pushlstring       DB "lua_pushlstring",0
szLua_pushnumber        DB "lua_pushnumber",0
szLua_pushstring        DB "lua_pushstring",0
szLua_rawgeti           DB "lua_rawgeti",0
szLua_rawlen            DB "lua_rawlen",0
szLua_setfield          DB "lua_setfield",0
szLua_setglobal         DB "lua_setglobal",0
szLua_settable          DB "lua_settable",0
szLua_settop            DB "lua_settop",0
szLua_toboolean         DB "lua_toboolean",0
szLua_tolstring         DB "lua_tolstring",0
szLua_tonumberx         DB "lua_tonumberx",0
szLua_touserdata        DB "lua_touserdata",0
szLua_type              DB "lua_type",0
szLua_typename          DB "lua_typename",0
szLuaL_loadstring       DB "luaL_loadstring",0
ENDIF


;---------------------------
; Lua Function pointers
;---------------------------
; typedef prototypes:
LuaL_newstateProto      TYPEDEF PROTO C
LuaL_newstatePtr        TYPEDEF PTR LuaL_newstateProto
LuaL_openlibsProto      TYPEDEF PROTO C luastate:DWORD
LuaL_openlibsPtr        TYPEDEF PTR LuaL_openlibsProto
LuaL_loadfilexProto     TYPEDEF PROTO C luastate:DWORD, filename:DWORD, mode:DWORD
LuaL_loadfilexPtr       TYPEDEF PTR LuaL_loadfilexProto
Lua_createtableProto    TYPEDEF PROTO C :VARARG ;luastate:DWORD, narr:DWORD, nrec:DWORD
Lua_createtablePtr      TYPEDEF PTR Lua_createtableProto
Lua_createtablexProto   TYPEDEF PROTO C :VARARG ;luastate:DWORD ; override for no narr and nrec params of lua_createtable
Lua_createtablexPtr     TYPEDEF PTR Lua_createtablexProto
Lua_getglobalProto      TYPEDEF PROTO C luastate:DWORD, ptr_name:DWORD
Lua_getglobalPtr        TYPEDEF PTR Lua_getglobalProto
Lua_gettopProto         TYPEDEF PROTO C luastate:DWORD
Lua_gettopPtr           TYPEDEF PTR Lua_gettopProto
Lua_pcallkProto         TYPEDEF PROTO C luastate:DWORD, nargs:DWORD, nresults:DWORD, msgh:DWORD, lua_KContext_ctx:DWORD, lua_KFunction_k:DWORD
Lua_pcallkPtr           TYPEDEF PTR Lua_pcallkProto
Lua_pushcclosureProto   TYPEDEF PROTO C :VARARG ;luastate:DWORD, lua_CFunction:DWORD, n:DWORD
Lua_pushcclosurePtr     TYPEDEF PTR Lua_pushcclosureProto
Lua_pushlightuserdataProto TYPEDEF PROTO C luastate:DWORD, p:DWORD
Lua_pushlightuserdataPtr TYPEDEF PTR Lua_pushlightuserdataProto
Lua_pushlstringProto    TYPEDEF PROTO C luastate:DWORD, ptr_string:DWORD, stringlen:DWORD
Lua_pushlstringPtr      TYPEDEF PTR Lua_pushlstringProto
Lua_pushnumberProto     TYPEDEF PROTO C :VARARG ;luastate:DWORD, lua_Number:DWORD
Lua_pushnumberPtr       TYPEDEF PTR Lua_pushnumberProto
Lua_pushstringProto     TYPEDEF PROTO C :VARARG ;luastate:DWORD, ptr_string:DWORD
Lua_pushstringPtr       TYPEDEF PTR Lua_pushstringProto
Lua_rawgetiProto        TYPEDEF PROTO C luastate:DWORD, index:DWORD, n:DWORD
Lua_rawgetiPtr          TYPEDEF PTR Lua_rawgetiProto
Lua_rawlenProto         TYPEDEF PROTO C luastate:DWORD, index:DWORD
Lua_rawlenPtr           TYPEDEF PTR Lua_rawlenProto
Lua_setfieldProto       TYPEDEF PROTO C luastate:DWORD, index:DWORD, ptr_string:DWORD
Lua_setfieldPtr         TYPEDEF PTR Lua_setfieldProto
Lua_setglobalProto      TYPEDEF PROTO C :VARARG ;luastate:DWORD, ptr_name:DWORD
Lua_setglobalPtr        TYPEDEF PTR Lua_setglobalProto
Lua_settableProto       TYPEDEF PROTO C :VARARG ;luastate:DWORD, index:DWORD
Lua_settablePtr         TYPEDEF PTR Lua_settableProto
Lua_settopProto         TYPEDEF PROTO C luastate:DWORD, index:DWORD
Lua_settopPtr           TYPEDEF PTR Lua_settopProto
Lua_tobooleanProto      TYPEDEF PROTO C luastate:DWORD, index:DWORD
Lua_tobooleanPtr        TYPEDEF PTR Lua_tobooleanProto
Lua_tolstringProto      TYPEDEF PROTO C luastate:DWORD, index:DWORD, ptr_len:DWORD
Lua_tolstringPtr        TYPEDEF PTR Lua_tolstringProto
Lua_tonumberxProto      TYPEDEF PROTO C luastate:DWORD, index:DWORD, ptr_isnum:DWORD
Lua_tonumberxPtr        TYPEDEF PTR Lua_tonumberxProto
Lua_touserdataProto     TYPEDEF PROTO C luastate:DWORD, index:DWORD
Lua_touserdataPtr       TYPEDEF PTR Lua_touserdataProto
Lua_typeProto           TYPEDEF PROTO C luastate:DWORD, index:DWORD
Lua_typePtr             TYPEDEF PTR Lua_typeProto
Lua_typenameProto       TYPEDEF PROTO C luastate:DWORD, tp:DWORD
Lua_typenamePtr         TYPEDEF PTR Lua_typenameProto
LuaL_loadstringProto    TYPEDEF PROTO C :VARARG ;luastate:DWORD, ptr_string:DWORD
LuaL_loadstringPtr      TYPEDEF PTR LuaL_loadstringProto

ftol2_sseProto          TYPEDEF PROTO C :VARARG
ftol2_ssePtr            TYPEDEF PTR ftol2_sseProto
MallocProto             TYPEDEF PROTO C :VARARG
MallocPtr               TYPEDEF PTR MallocProto
FreeProto               TYPEDEF PROTO C :VARARG
FreePtr                 TYPEDEF PTR FreeProto


; Lua function pointers
F_LuaL_newstate         LuaL_newstatePtr 0
F_LuaL_openlibs         LuaL_openlibsPtr 0
F_LuaL_loadfilex        LuaL_loadfilexPtr 0
F_Lua_createtable       Lua_createtablePtr 0
F_Lua_createtablex      Lua_createtablexPtr 0 ; override for no params of lua_createtable
F_Lua_getglobal         Lua_getglobalPtr 0
F_Lua_gettop            Lua_gettopPtr 0
F_Lua_pcallk            Lua_pcallkPtr 0
F_Lua_pushcclosure      Lua_pushcclosurePtr 0
F_Lua_pushlightuserdata Lua_pushlightuserdataPtr 0
F_Lua_pushlstring       Lua_pushlstringPtr 0
F_Lua_pushnumber        Lua_pushnumberPtr 0
F_Lua_pushstring        Lua_pushstringPtr 0
F_Lua_rawgeti           Lua_rawgetiPtr 0
F_Lua_rawlen            Lua_rawlenPtr 0
F_Lua_setfield          Lua_setfieldPtr 0
F_Lua_setglobal         Lua_setglobalPtr 0
F_Lua_settable          Lua_settablePtr 0
F_Lua_settop            Lua_settopPtr 0
F_Lua_toboolean         Lua_tobooleanPtr 0
F_Lua_tolstring         Lua_tolstringPtr 0
F_Lua_tonumberx         Lua_tonumberxPtr 0
F_Lua_touserdata        Lua_touserdataPtr 0
F_Lua_type              Lua_typePtr 0
F_Lua_typename          Lua_typenamePtr 0
F_LuaL_loadstring       LuaL_loadstringPtr 0

F__ftol2_sse            ftol2_ssePtr 0
F_Malloc                MallocPtr 0
F_Free                  FreePtr 0



;---------------------------
; Module and section info
;---------------------------
hKernel32               DD 0
hMsvcrt                 DD 0
hLua                    DD 0
hModule                 DD 0
hIEGameModule           DD 0
hIEGameProcess          DD 0
IEGameBaseAddress       DD 0
IEGameImageSize         DD 0
IEGameNoSections        DD 0
IEGameSectionTEXTSize   DD 0
IEGameSectionTEXTPtr    DD 0
IEGameAddressEP         DD 0
IEGameAddressStart      DD 0
IEGameAddressFinish     DD 0
modinfo                 MODULEINFO <>

;---------------------------
; Filenames 
;---------------------------
IEexExeFile             DB MAX_PATH DUP (0)
IEexIniFile             DB MAX_PATH DUP (0)
IEexLogFile             DB MAX_PATH DUP (0)
IEexLuaFile             DB MAX_PATH DUP (0)
IEexPatFile             DB MAX_PATH DUP (0)
szCurrentFolder         DB MAX_PATH DUP (0)


;---------------------------
; Version buffers 
;---------------------------
IEGameProductVersion    DB 64 DUP (0)
IEGameProductName       DB 128 DUP (0)
IEGameExeName           DB 64 DUP (0)


.DATA?
;------------------------------------------------------------------------------
; IEex.dll Uninitialized Data
;------------------------------------------------------------------------------
hInstance               DD ?
hWnd                    DD ?
szFileVersionBuffer     DB 32 DUP (?)
szProductVersionBuffer  DB MAX_PATH DUP (?)
szProductNameBuffer     DB MAX_PATH DUP (?)

