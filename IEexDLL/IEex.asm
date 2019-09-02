;------------------------------------------------------------------------------
; IEex.DLL - Loader for IEex to inject IEex.dll by github.com/mrfearless
;
; IEex by Bubb: github.com/Bubb13/IEex 
;
;------------------------------------------------------------------------------
.686
.MMX
.XMM
.model flat,stdcall
option casemap:none


IEEX_ALIGN TEXTEQU <ALIGN 16>
IEEX_LOGGING EQU 1 ; comment out if we dont require logging
;IEEX_LUALIB EQU 1 ; comment out to use lua function found in lua.dll. Otherwise use some lua functions from static lib


;DEBUG32 EQU 1
;IFDEF DEBUG32
;    PRESERVEXMMREGS equ 1
;    includelib M:\Masm32\lib\Debug32.lib
;    DBG32LIB equ 1
;    DEBUGEXE textequ <'M:\Masm32\DbgWin.exe'>
;    include M:\Masm32\include\debug32.inc
;ENDIF

CTEXT MACRO Text        ; Macro for defining text in place 
    LOCAL szText
    .DATA
    szText DB Text, 0
    .CODE
    EXITM <Offset szText>
ENDM


include IEex.inc        ; Basic include file. Error messages, strings for function names, buffers etc
include IEexIni.asm     ; Ini functions, strings for sections and key names
include IEexLog.asm     ; Log functions, strings for logging output
include IEexLua.asm     ; IEexLuaInit, IEex_Init and other Lua functions used by IEex


.CODE


IEEX_ALIGN
;------------------------------------------------------------------------------
; DllEntry - Main entry function
;------------------------------------------------------------------------------
DllEntry PROC hInst:HINSTANCE, reason:DWORD, reserved:DWORD
    .IF reason == DLL_PROCESS_ATTACH
        mov eax, hInst
        mov hInstance, eax
        mov hIEGameModule, eax
        Invoke IEexInitDll
    .ENDIF
    mov eax,TRUE
    ret
DllEntry Endp


IEEX_ALIGN
;------------------------------------------------------------------------------
; IEexInitDll - Intialize IEex.dll
; Read ini file (if exists) for saved pattern address information and begin
; verifying / searching for function addresses or game global address.
;
; Patchs a specific address location to forward a call to our IEexLuaInit.
; Returns: None
;------------------------------------------------------------------------------
IEexInitDll PROC USES EBX
    LOCAL ptrNtHeaders:DWORD
    LOCAL ptrSections:DWORD
    LOCAL ptrCurrentSection:DWORD
    LOCAL CurrentSection:DWORD
    
    Invoke GetCurrentProcess
    mov hIEGameProcess, eax
    
    Invoke IEexInitGlobals
    .IF eax == FALSE
        Invoke TerminateProcess, hIEGameProcess, NULL
        ret ; error occured - probably lua.dll not found/loaded
    .ENDIF
    
    Invoke IEexLogInformation, INFO_GAME

    ;--------------------------------------------------------------------------
    ; IE Game Module Info And Sections Stage
    ;--------------------------------------------------------------------------

    Invoke GetModuleInformation, hIEGameProcess, 0, Addr modinfo, SIZEOF MODULEINFO
    .IF eax != 0
        mov eax, modinfo.SizeOfImage
        mov IEGameImageSize, eax
        mov eax, modinfo.EntryPoint
        mov IEGameAddressEP, eax
        add eax, IEGameAddressStart
        mov IEGameAddressFinish, eax
        mov eax, modinfo.lpBaseOfDll
        .IF eax == 0
            mov eax, 00400000h
        .ENDIF
        mov IEGameBaseAddress, eax
        mov IEGameAddressStart, eax
        add eax, IEGameImageSize
        mov IEGameAddressFinish, eax

        mov ebx, IEGameBaseAddress
        .IF [ebx].IMAGE_DOS_HEADER.e_magic == IMAGE_DOS_SIGNATURE
            mov eax, [ebx].IMAGE_DOS_HEADER.e_lfanew
            add ebx, eax ; ebx ptr to IMAGE_NT_HEADERS32
            .IF [ebx].IMAGE_NT_HEADERS32.Signature == IMAGE_NT_SIGNATURE
                ;--------------------------------------------------------------
                ; Read PE Sections .text, .rdata and .data
                ;--------------------------------------------------------------
                movzx eax, word ptr [ebx].IMAGE_NT_HEADERS32.FileHeader.NumberOfSections
                mov IEGameNoSections, eax
                mov eax, SIZEOF IMAGE_NT_HEADERS32
                add ebx, eax ; ebx ptr to IMAGE_SECTION_HEADER
                mov ptrCurrentSection, ebx
                mov CurrentSection, 0
                mov eax, 0
                .WHILE eax < IEGameNoSections
                    mov ebx, ptrCurrentSection
                    lea eax, [ebx].IMAGE_SECTION_HEADER.Name1
                    mov eax, [eax]
                    .IF eax == 'xet.' || eax == 'XET.' || eax == 'doc.' || eax == 'DOC.'; .tex .cod .TEX .COD
                        mov eax, [ebx].IMAGE_SECTION_HEADER.SizeOfRawData
                        mov IEGameSectionTEXTSize, eax
                        mov eax, [ebx].IMAGE_SECTION_HEADER.VirtualAddress
                        add eax, IEGameBaseAddress
                        mov IEGameSectionTEXTPtr, eax
                        .BREAK
                    .ENDIF
                    add ptrCurrentSection, SIZEOF IMAGE_SECTION_HEADER
                    inc CurrentSection
                    mov eax, CurrentSection
                .ENDW
                ;--------------------------------------------------------------
                ; Finished Reading PE Sections
                ;--------------------------------------------------------------

                ;--------------------------------------------------------------
                ; Continue Onwards To Verify / Search Stage
                ;--------------------------------------------------------------
            .ELSE ; IMAGE_NT_SIGNATURE Failed
                IFDEF IEEX_LOGGING
                .IF gIEexLog > LOGLEVEL_NONE
                    Invoke LogOpen, FALSE
                    Invoke LogMessage, Addr szErrorImageNtSig, LOG_ERROR, 0
                    Invoke LogClose
                .ENDIF
                ENDIF
                ret ; Exit EEexInitDll
            .ENDIF
        .ELSE ; IMAGE_DOS_SIGNATURE Failed
            IFDEF IEEX_LOGGING
            .IF gIEexLog > LOGLEVEL_NONE
                Invoke LogOpen, FALSE
                Invoke LogMessage, Addr szErrorImageDosSig, LOG_ERROR, 0
                Invoke LogClose
            .ENDIF
            ENDIF
            ret ; Exit IEexInitDll
        .ENDIF
    .ELSE ; GetModuleInformation Failed
        IFDEF IEEX_LOGGING
        .IF gIEexLog > LOGLEVEL_NONE
            Invoke LogOpen, FALSE
            Invoke LogMessage, Addr szErrorGetModuleInfo, LOG_ERROR, 0
            Invoke LogClose
        .ENDIF
        ENDIF
        ret ; Exit IEexInitDll
    .ENDIF
    ;--------------------------------------------------------------------------
    ; Finished IE Game Module Info And Sections Stage
    ;--------------------------------------------------------------------------

    Invoke IEexLogInformation, INFO_DEBUG
    
    ; Patch NO-CD into EXE?
    
    IFDEF DEBUG32
    PrintString IEexLuaFile
    PrintDec F_LuaL_newstate
    
    ENDIF
    Invoke IEexLuaInit, Addr IEexLuaFile
    
    ;--------------------------------------------------------------------------
    ; IEex.dll EXITS HERE - Execution continues with IE game
    ;--------------------------------------------------------------------------
    xor eax, eax
    ret
IEexInitDll ENDP


IEEX_ALIGN
;------------------------------------------------------------------------------
; IEexInitGlobals - Initialize global variables & read ini file for addresses.
; Returns: None
;------------------------------------------------------------------------------
IEexInitGlobals PROC USES EBX
    LOCAL nLength:DWORD

    ; Construct ini filename
    Invoke GetModuleFileName, 0, Addr IEexExeFile, SIZEOF IEexExeFile
    Invoke GetModuleFileName, hInstance, Addr IEexIniFile, SIZEOF IEexIniFile
    Invoke lstrcpy, Addr IEexLogFile, Addr IEexIniFile
    Invoke lstrlen, Addr IEexIniFile
    mov nLength, eax
    lea ebx, IEexIniFile
    add ebx, eax
    sub ebx, 3 ; move back past 'dll' extention
    mov byte ptr [ebx], 0 ; null so we can use lstrcat
    Invoke lstrcat, ebx, Addr szIni ; add 'ini' to end of string instead

    ; Construct log filename
    lea ebx, IEexLogFile
    add ebx, nLength
    sub ebx, 3 ; move back past 'dll' extention
    mov byte ptr [ebx], 0 ; null so we can use lstrcat
    Invoke lstrcat, ebx, Addr szLog ; add 'log' to end of string instead
    
;    ; Construct lua filename
    Invoke GetCurrentDirectory, SIZEOF szCurrentFolder, Addr szCurrentFolder
    Invoke lstrcpy, Addr IEexLuaFile, Addr szCurrentFolder
    Invoke lstrcat, Addr IEexLuaFile, Addr szOverride
    Invoke lstrcat, Addr IEexLuaFile, Addr szM__IEexlua

    Invoke IEexIEFileInformation
    .IF eax == TRUE
        Invoke IEexIEGameInformation
        IFDEF DEBUG32
        PrintDec gIEGameType
        ;PrintString IEexPatFile
        ENDIF
    .ENDIF

    Invoke IniGetOptionLog
    mov gIEexLog, eax
    Invoke IniGetOptionLua
    mov gIEexLua, eax
    Invoke IniGetOptionHex
    mov gIEexHex, eax
    Invoke IniGetOptionMsg
    mov gIEexMsg, eax
    
    Invoke IniSetOptionLog, gIEexLog
    Invoke IniSetOptionLua, gIEexLua
    Invoke IniSetOptionHex, gIEexHex
    Invoke IniSetOptionMsg, gIEexMsg

    ;--------------------------------------------------------------------------
    ; Get addresses of win32 api functions
    ;--------------------------------------------------------------------------
    Invoke GetModuleHandle, Addr szKernel32Dll
    mov hKernel32, eax
    Invoke GetProcAddress, hKernel32, Addr szGetProcAddressProc
    mov F_GetProcAddress, eax
    Invoke GetProcAddress, hKernel32, Addr szLoadLibraryProc
    mov F_LoadLibrary, eax
    
    ; MSVCRT.DLL Functions:
    Invoke GetModuleHandle, Addr szMsvcrtDll
    mov hMsvcrt, eax
    Invoke GetProcAddress, hMsvcrt, Addr sz_ftol2_sse
    mov F__ftol2_sse, eax
    Invoke GetProcAddress, hMsvcrt, Addr sz_malloc
    mov F_Malloc, eax
    Invoke GetProcAddress, hMsvcrt, Addr sz_free
    mov F_Free, eax

    IFDEF DEBUG32
    PrintText 'Api calls and exports'
    PrintDec F_GetProcAddress
    PrintDec F_LoadLibrary
    PrintDec F__ftol2_sse
    PrintDec F_Malloc
    PrintDec F_Free
    ENDIF

    ;--------------------------------------------------------------------------
    ; Get addresses of lua functions
    ;--------------------------------------------------------------------------
    IFDEF IEEX_LUALIB ; USE LUA.LIB
    IFDEF DEBUG32
    PrintText 'Using LUA.LIB'
    ENDIF
    lea eax, luaL_newstate
    mov F_LuaL_newstate, eax
    lea eax, luaL_openlibs
    mov F_LuaL_openlibs, eax 
    lea eax, luaL_loadfilex
    mov F_LuaL_loadfilex, eax

    lea eax, lua_createtable
    mov F_Lua_createtable, eax
    mov F_Lua_createtablex, eax
    lea eax, lua_getglobal
    mov F_Lua_getglobal, eax
    lea eax, lua_gettop
    mov F_Lua_gettop, eax
    lea eax, lua_pcallk
    mov F_Lua_pcallk, eax
    lea eax, lua_pushcclosure
    mov F_Lua_pushcclosure, eax
    lea eax, lua_pushlightuserdata
    mov F_Lua_pushlightuserdata, eax
    lea eax, lua_pushlstring
    mov F_Lua_pushlstring, eax
    lea eax, lua_pushnumber
    mov F_Lua_pushnumber, eax
    lea eax, lua_pushstring
    mov F_Lua_pushstring, eax
    lea eax, lua_rawgeti
    mov F_Lua_rawgeti, eax
    lea eax, lua_rawlen
    mov F_Lua_rawlen, eax
    lea eax, lua_setfield
    mov F_Lua_setfield, eax
    lea eax, lua_setglobal
    mov F_Lua_setglobal, eax
    lea eax, lua_settable
    mov F_Lua_settable, eax
    lea eax, lua_settop
    mov F_Lua_settop, eax
    lea eax, lua_toboolean
    mov F_Lua_toboolean, eax
    lea eax, lua_tolstring
    mov F_Lua_tolstring, eax
    lea eax, lua_tonumberx
    mov F_Lua_tonumberx, eax
    lea eax, lua_touserdata
    mov F_Lua_touserdata, eax
    lea eax, lua_type
    mov F_Lua_type, eax
    lea eax, lua_typename
    mov F_Lua_typename, eax
    lea eax, luaL_loadstring
    mov F_LuaL_loadstring, eax
    
    ELSE ; USE LUA52.DLL
    IFDEF DEBUG32
    PrintText 'Using LUA52.DLL'
    ENDIF
    Invoke LoadLibrary, Addr szLuaDLL
    .IF eax == NULL
        IFDEF IEEX_LOGGING
        .IF gIEexLog > LOGLEVEL_NONE
            Invoke LogOpen, FALSE
            Invoke LogMessage, Addr szErrorLuaDll, LOG_ERROR, 0 ; CTEXT("Cannot load or find lua.dll - aborting.")
            Invoke LogClose
        .ENDIF
        ENDIF
        .IF gIEexMsg == TRUE
            Invoke MessageBox, 0, Addr szErrorLuaDll, Addr AppName, MB_OK
        .ENDIF
        mov eax, FALSE
        ret
    .ENDIF
    mov hLua, eax
    IFDEF DEBUG32
    PrintDec hLua
    ENDIF
    Invoke GetProcAddress, hLua, Addr szLuaL_newstate
    mov F_LuaL_newstate, eax
    Invoke GetProcAddress, hLua, Addr szLuaL_openlibs
    mov F_LuaL_openlibs, eax
    Invoke GetProcAddress, hLua, Addr szLuaL_loadfilex
    mov F_LuaL_loadfilex, eax
    
    Invoke GetProcAddress, hLua, Addr szLua_createtable
    mov F_Lua_createtable, eax
    mov F_Lua_createtablex, eax
    Invoke GetProcAddress, hLua, Addr szLua_getglobal
    mov F_Lua_getglobal, eax
    Invoke GetProcAddress, hLua, Addr szLua_gettop
    mov F_Lua_gettop, eax
    Invoke GetProcAddress, hLua, Addr szLua_pcallk
    mov F_Lua_pcallk, eax
    Invoke GetProcAddress, hLua, Addr szLua_pushcclosure
    mov F_Lua_pushcclosure, eax
    Invoke GetProcAddress, hLua, Addr szLua_pushlightuserdata
    mov F_Lua_pushlightuserdata, eax
    Invoke GetProcAddress, hLua, Addr szLua_pushlstring
    mov F_Lua_pushlstring, eax
    Invoke GetProcAddress, hLua, Addr szLua_pushnumber
    mov F_Lua_pushnumber, eax
    Invoke GetProcAddress, hLua, Addr szLua_pushstring
    mov F_Lua_pushstring, eax
    Invoke GetProcAddress, hLua, Addr szLua_rawgeti
    mov F_Lua_rawgeti, eax
    Invoke GetProcAddress, hLua, Addr szLua_rawlen
    mov F_Lua_rawlen, eax
    Invoke GetProcAddress, hLua, Addr szLua_setfield
    mov F_Lua_setfield, eax
    Invoke GetProcAddress, hLua, Addr szLua_setglobal
    mov F_Lua_setglobal, eax
    Invoke GetProcAddress, hLua, Addr szLua_settable
    mov F_Lua_settable, eax
    Invoke GetProcAddress, hLua, Addr szLua_settop
    mov F_Lua_settop, eax
    Invoke GetProcAddress, hLua, Addr szLua_toboolean
    mov F_Lua_toboolean, eax
    Invoke GetProcAddress, hLua, Addr szLua_tolstring
    mov F_Lua_tolstring, eax
    Invoke GetProcAddress, hLua, Addr szLua_tonumberx
    mov F_Lua_tonumberx, eax
    Invoke GetProcAddress, hLua, Addr szLua_touserdata
    mov F_Lua_touserdata, eax
    Invoke GetProcAddress, hLua, Addr szLua_type
    mov F_Lua_type, eax
    Invoke GetProcAddress, hLua, Addr szLua_typename
    mov F_Lua_typename, eax
    Invoke GetProcAddress, hLua, Addr szLuaL_loadstring
    mov F_LuaL_loadstring, eax
    
    ENDIF

    mov eax, TRUE
    ret
IEexInitGlobals ENDP




IEEX_ALIGN
;------------------------------------------------------------------------------
; IEexLogInformation - Output some information to the log.
; dwType: 
;
;  INFO_ALL                EQU 0
;  INFO_GAME               EQU 1
;  INFO_DEBUG              EQU 2
;  INFO_IMPORTED           EQU 3
;  INFO_VERIFIED           EQU 4
;  INFO_SEARCHED           EQU 5
;
; Returns: None
;------------------------------------------------------------------------------
IEexLogInformation PROC dwType:DWORD
    LOCAL wfad:WIN32_FILE_ATTRIBUTE_DATA
    LOCAL dwFilesizeLow:DWORD

    .IF gIEexLog == LOGLEVEL_NONE
        xor eax, eax
        ret
    .ENDIF

;    IFDEF DEBUG32
;    PrintText 'IEexLogInformation'
;    PrintDec dwType
;    ENDIF  

    Invoke LogOpen, FALSE
    ;--------------------------------------------------------------------------
    ; Log basic game information
    ;--------------------------------------------------------------------------
    .IF dwType == INFO_GAME && gIEexLog > LOGLEVEL_NONE
        Invoke LogMessage, CTEXT("Game Information:"), LOG_INFO, 0
        Invoke LogMessage, CTEXT("Filename: "), LOG_NONEWLINE, 0
        Invoke LogMessage, Addr IEexExeFile, LOG_STANDARD, 0
        Invoke GetFileAttributesEx, Addr IEexExeFile, 0, Addr wfad
        mov eax, wfad.nFileSizeLow
        mov dwFilesizeLow, eax
        Invoke LogMessageAndValue, CTEXT("Filesize"), dwFilesizeLow
        Invoke LogMessage, CTEXT("FileVersion: "), LOG_NONEWLINE, 0
        Invoke LogMessage, Addr szFileVersionBuffer, LOG_STANDARD, 0
        Invoke LogMessage, CTEXT("ProductName: "), LOG_NONEWLINE, 0
        Invoke LogMessage, Addr IEGameProductName, LOG_STANDARD, 0
        Invoke LogMessage, CTEXT("ProductVersion: "), LOG_NONEWLINE, 0
        Invoke LogMessage, Addr IEGameProductVersion, LOG_STANDARD, 0
        Invoke LogMessage, 0, LOG_CRLF, 0
        Invoke LogMessage, CTEXT("Options:"), LOG_INFO, 0
        Invoke LogMessageAndValue, CTEXT("Log"), gIEexLog
        Invoke LogMessageAndValue, CTEXT("Lua"), gIEexLua
        Invoke LogMessageAndValue, CTEXT("Hex"), gIEexHex
        Invoke LogMessageAndValue, CTEXT("Msg"), gIEexMsg
        Invoke LogMessage, 0, LOG_CRLF, 0
    .ENDIF

    ;--------------------------------------------------------------------------
    ; Log debugging information
    ;--------------------------------------------------------------------------
    .IF dwType == INFO_DEBUG && gIEexLog >= LOGLEVEL_DEBUG
        Invoke LogMessage, CTEXT("Debug Information:"), LOG_INFO, 0
        Invoke LogMessageAndHexValue, CTEXT("hProcess"), hIEGameProcess
        Invoke LogMessageAndHexValue, CTEXT("hModule"), hIEGameModule
        Invoke LogMessageAndHexValue, CTEXT("OEP"), IEGameAddressEP
        Invoke LogMessageAndHexValue, CTEXT("BaseAddress"), IEGameBaseAddress
        Invoke LogMessageAndHexValue, CTEXT("ImageSize"), IEGameImageSize
        Invoke LogMessageAndHexValue, CTEXT("AddressStart"), IEGameAddressStart
        Invoke LogMessageAndHexValue, CTEXT("AddressFinish"), IEGameAddressFinish
        Invoke LogMessageAndValue,    CTEXT("PE Sections"), IEGameNoSections
        Invoke LogMessageAndHexValue, CTEXT(".text address"), IEGameSectionTEXTPtr
        Invoke LogMessageAndHexValue, CTEXT(".text size"), IEGameSectionTEXTSize
        Invoke LogMessage, 0, LOG_CRLF, 0
    .ENDIF

    .IF dwType == INFO_ADDRESSES
        .IF gIEexLog > LOGLEVEL_NONE
            Invoke LogMessage, CTEXT("Address List:"), LOG_INFO, 0
            ; Handle extras like GetProcAddress, LoadLibrary etc
            Invoke LogMessage, Addr szGetProcAddress, LOG_NONEWLINE, 1
            Invoke LogMessageAndHexValue, 0, F_GetProcAddress
            Invoke LogMessage, Addr szLoadLibrary, LOG_NONEWLINE, 1
            Invoke LogMessageAndHexValue, 0, F_LoadLibrary
            Invoke LogMessage, 0, LOG_CRLF, 0
        .ENDIF
    .ENDIF

    xor eax, eax
    ret
IEexLogInformation ENDP


IEEX_ALIGN
;------------------------------------------------------------------------------
; IEexIEFileInformation - Get IE File ProductVersion, ProductName & FileVersion
; Returns: TRUE if successful or FALSE otherwise
;------------------------------------------------------------------------------
IEexIEFileInformation PROC USES EBX
    LOCAL verHandle:DWORD
    LOCAL verData:DWORD
    LOCAL verSize:DWORD
    LOCAL verInfo:DWORD
    LOCAL hHeap:DWORD
    LOCAL pBuffer:DWORD
    LOCAL lenBuffer:DWORD
    LOCAL lpszProductVersion:DWORD
    LOCAL lpszProductName:DWORD
    LOCAL FileVersion1:DWORD
    LOCAL FileVersion2:DWORD
    LOCAL FileVersion3:DWORD
    LOCAL FileVersion4:DWORD

    Invoke GetFileVersionInfoSize, Addr IEexExeFile, Addr verHandle
    .IF eax != 0
        mov verSize, eax
        Invoke GetProcessHeap
        .IF eax != 0
            mov hHeap, eax
            Invoke HeapAlloc, eax, 0, verSize
            .IF eax != 0
                mov verData, eax
                Invoke GetFileVersionInfo, Addr IEexExeFile, 0, verSize, verData
                .IF eax != 0

                    Invoke VerQueryValue, verData, Addr szLang, Addr pBuffer, Addr lenBuffer
                    .IF eax != 0 && lenBuffer != 0
                        ; Get ProductVersion String
                        mov ebx, pBuffer
                        movzx eax,[ebx.LANGANDCODEPAGE].wLanguage
                        movzx ebx,[ebx.LANGANDCODEPAGE].wCodepage
                        Invoke wsprintf, Addr szProductVersionBuffer, Addr szProductVersion, eax, ebx
                        Invoke VerQueryValue, verData, Addr szProductVersionBuffer, Addr lpszProductVersion, addr lenBuffer
                        .IF eax != 0 && lenBuffer != 0
                            Invoke lstrcpyn, Addr IEGameProductVersion, lpszProductVersion, SIZEOF IEGameProductVersion
                        .ENDIF

                        ; Get ProductName String
                        mov ebx, pBuffer
                        movzx eax,[ebx.LANGANDCODEPAGE].wLanguage
                        movzx ebx,[ebx.LANGANDCODEPAGE].wCodepage
                        Invoke wsprintf, Addr szProductNameBuffer, Addr szProductName, eax, ebx
                        Invoke VerQueryValue, verData, Addr szProductNameBuffer, Addr lpszProductName, addr lenBuffer
                        .IF eax != 0 && lenBuffer != 0
                            Invoke lstrcpyn, Addr IEGameProductName, lpszProductName, SIZEOF IEGameProductName
                        .ENDIF
                    .ELSE
                        Invoke HeapFree, hHeap, 0, verData
                        mov eax, FALSE
                        ret
                    .ENDIF
                    ; Get FILEVERSION
                    Invoke VerQueryValue, verData, Addr szVerRoot, Addr pBuffer, Addr lenBuffer
                    .IF eax != 0 && lenBuffer != 0
                        lea ebx, pBuffer
                        mov eax, [ebx]
                        mov verInfo, eax
                        mov ebx, eax
                        .IF [ebx].VS_FIXEDFILEINFO.dwSignature == 0FEEF04BDh
                            mov ebx, verInfo
                            mov eax, [ebx].VS_FIXEDFILEINFO.dwFileVersionMS
                            shr eax, 16d
                            and eax, 0FFFFh
                            mov FileVersion1, eax
                            mov eax, [ebx].VS_FIXEDFILEINFO.dwFileVersionMS
                            shr eax, 0
                            and eax, 0FFFFh
                            mov FileVersion2, eax
                            mov eax, [ebx].VS_FIXEDFILEINFO.dwFileVersionLS
                            shr eax, 16d
                            and eax, 0FFFFh
                            mov FileVersion3, eax
                            mov eax, [ebx].VS_FIXEDFILEINFO.dwFileVersionLS
                            shr eax, 0
                            and eax, 0FFFFh
                            mov FileVersion4, eax
                            Invoke wsprintf, Addr szFileVersionBuffer, Addr szFileVersion, FileVersion1, FileVersion2, FileVersion3, FileVersion4
                        .ENDIF
                    .ELSE
                        Invoke HeapFree, hHeap, 0, verData
                        mov eax, FALSE
                        ret
                    .ENDIF
                    ; Free Heap after getting information
                    Invoke HeapFree, hHeap, 0, verData
                    mov eax, TRUE
                    ret

                .ELSE
                    Invoke HeapFree, hHeap, 0, verData
                    mov eax, FALSE
                    ret
                .ENDIF
            .ELSE
                mov eax, FALSE
                ret
            .ENDIF
        .ELSE
            mov eax, FALSE
            ret
        .ENDIF
    .ELSE
        mov eax, FALSE
        ret
    .ENDIF
    ret
IEexIEFileInformation ENDP


IEEX_ALIGN
;------------------------------------------------------------------------------
; IEexIEGameInformation - Determine IE game type and stores it in gIEGameType
; Returns: eax will contain IE Game Type:
;
; GAME_UNKNOWN            EQU 0h
; GAME_BG                 EQU 1h
; GAME_BG2                EQU 2h
; GAME_IWD                EQU 4h
; GAME_IWD2               EQU 8h
; GAME_PST                EQU 10h
;
; Devnote: Defined as a bit mask - might be used in future for combining game 
; types in a pattern field to include/exclude specific patterns based on game?
;------------------------------------------------------------------------------
IEexIEGameInformation PROC USES ECX EDI ESI
    ; walk backwards filepath to get the \ or / and get just the filename.exe
    Invoke lstrlen, Addr IEexExeFile
    lea edi, IEGameExeName
    lea esi, IEexExeFile
    add esi, eax
    mov ecx, eax
    .WHILE ecx != 0
        movzx eax, byte ptr [esi]
        .IF al == '\' || al == '/'
            inc esi
            movzx eax, byte ptr [esi] ; copy bytes onwards
            .WHILE al != 0
                .IF al >= 'a' && al <= 'z'
                    sub al, 32 ; convert to uppercase
                .ENDIF
                mov byte ptr [edi], al
                inc edi
                inc esi
                movzx eax, byte ptr [esi]
            .ENDW
            .BREAK
        .ENDIF
        dec esi
        dec ecx
    .ENDW
    mov byte ptr [edi], 0 ; null end of EEGameExeName string

    Invoke lstrlen, Addr IEGameExeName
    .IF eax != 0
        Invoke lstrcmp, Addr IEGameExeName, Addr szBioware_BG
        .IF eax == 0 ; found match
            ;  do additional check to decide which it is BG or BG2
            IFDEF DEBUG32
            PrintString IEGameProductName
            PrintString szBioware_BG2_Name
            ENDIF
            Invoke lstrcmp, Addr szBioware_BG2_Name, Addr IEGameProductName
            .IF eax == 0 ; found match
                mov gIEGameType, GAME_BG2
            .ELSE
                mov gIEGameType, GAME_BG
            .ENDIF
            ret
        .ENDIF
        Invoke lstrcmpi, Addr IEGameExeName, Addr szBlackIsle_IWD
        .IF eax == 0 ; found match
            mov gIEGameType, GAME_IWD
            ret
        .ENDIF
        Invoke lstrcmpi, Addr IEGameExeName, Addr szBlackIsle_IWD2
        .IF eax == 0 ; found match
            mov gIEGameType, GAME_IWD2
            ret
        .ENDIF
        Invoke lstrcmpi, Addr IEGameExeName, Addr szBlackIsle_PST
        .IF eax == 0 ; found match
            mov gIEGameType, GAME_PST
            ret
        .ENDIF
    .ENDIF
    mov gIEGameType, GAME_UNKNOWN
    ret
IEexIEGameInformation ENDP


IEEX_ALIGN
;------------------------------------------------------------------------------
; IEexDwordToAscii - Paul Dixon's utoa_ex function. unsigned dword to ascii.
; Returns: Buffer pointed to by lpszAsciiString will contain ascii string
;------------------------------------------------------------------------------
OPTION PROLOGUE:NONE
OPTION EPILOGUE:NONE
IEexDwordToAscii PROC dwValue:DWORD, lpszAsciiString:DWORD
    mov eax, [esp+4]                ; uvar      : unsigned variable to convert
    mov ecx, [esp+8]                ; pbuffer   : pointer to result buffer

    push esi
    push edi

    jmp udword

  align 4
  chartab:
    dd "00","10","20","30","40","50","60","70","80","90"
    dd "01","11","21","31","41","51","61","71","81","91"
    dd "02","12","22","32","42","52","62","72","82","92"
    dd "03","13","23","33","43","53","63","73","83","93"
    dd "04","14","24","34","44","54","64","74","84","94"
    dd "05","15","25","35","45","55","65","75","85","95"
    dd "06","16","26","36","46","56","66","76","86","96"
    dd "07","17","27","37","47","57","67","77","87","97"
    dd "08","18","28","38","48","58","68","78","88","98"
    dd "09","19","29","39","49","59","69","79","89","99"

  udword:
    mov esi, ecx                    ; get pointer to answer
    mov edi, eax                    ; save a copy of the number

    mov edx, 0D1B71759h             ; =2^45\10000    13 bit extra shift
    mul edx                         ; gives 6 high digits in edx

    mov eax, 68DB9h                 ; =2^32\10000+1

    shr edx, 13                     ; correct for multiplier offset used to give better accuracy
    jz short skiphighdigits         ; if zero then don't need to process the top 6 digits

    mov ecx, edx                    ; get a copy of high digits
    imul ecx, 10000                 ; scale up high digits
    sub edi, ecx                    ; subtract high digits from original. EDI now = lower 4 digits

    mul edx                         ; get first 2 digits in edx
    mov ecx, 100                    ; load ready for later

    jnc short next1                 ; if zero, supress them by ignoring
    cmp edx, 9                      ; 1 digit or 2?
    ja   ZeroSupressed              ; 2 digits, just continue with pairs of digits to the end

    mov edx, chartab[edx*4]         ; look up 2 digits
    mov [esi], dh                   ; but only write the 1 we need, supress the leading zero
    inc esi                         ; update pointer by 1
    jmp  ZS1                        ; continue with pairs of digits to the end

  align 16
  next1:
    mul ecx                         ; get next 2 digits
    jnc short next2                 ; if zero, supress them by ignoring
    cmp edx, 9                      ; 1 digit or 2?
    ja   ZS1a                       ; 2 digits, just continue with pairs of digits to the end

    mov edx, chartab[edx*4]         ; look up 2 digits
    mov [esi], dh                   ; but only write the 1 we need, supress the leading zero
    add esi, 1                      ; update pointer by 1
    jmp  ZS2                        ; continue with pairs of digits to the end

  align 16
  next2:
    mul ecx                         ; get next 2 digits
    jnc short next3                 ; if zero, supress them by ignoring
    cmp edx, 9                      ; 1 digit or 2?
    ja   ZS2a                       ; 2 digits, just continue with pairs of digits to the end

    mov edx, chartab[edx*4]         ; look up 2 digits
    mov [esi], dh                   ; but only write the 1 we need, supress the leading zero
    add esi, 1                      ; update pointer by 1
    jmp  ZS3                        ; continue with pairs of digits to the end

  align 16
  next3:

  skiphighdigits:
    mov eax, edi                    ; get lower 4 digits
    mov ecx, 100

    mov edx, 28F5C29h               ; 2^32\100 +1
    mul edx
    jnc short next4                 ; if zero, supress them by ignoring
    cmp edx, 9                      ; 1 digit or 2?
    ja  short ZS3a                  ; 2 digits, just continue with pairs of digits to the end

    mov edx, chartab[edx*4]         ; look up 2 digits
    mov [esi], dh                   ; but only write the 1 we need, supress the leading zero
    inc esi                         ; update pointer by 1
    jmp short  ZS4                  ; continue with pairs of digits to the end

  align 16
  next4:
    mul ecx                         ; this is the last pair so don; t supress a single zero
    cmp edx, 9                      ; 1 digit or 2?
    ja  short ZS4a                  ; 2 digits, just continue with pairs of digits to the end

    mov edx, chartab[edx*4]         ; look up 2 digits
    mov [esi], dh                   ; but only write the 1 we need, supress the leading zero
    mov byte ptr [esi+1], 0         ; zero terminate string

    pop edi
    pop esi
    ret 8

  align 16
  ZeroSupressed:
    mov edx, chartab[edx*4]         ; look up 2 digits
    mov [esi], dx
    add esi, 2                      ; write them to answer

  ZS1:
    mul ecx                         ; get next 2 digits
  ZS1a:
    mov edx, chartab[edx*4]         ; look up 2 digits
    mov [esi], dx                   ; write them to answer
    add esi, 2

  ZS2:
    mul ecx                         ; get next 2 digits
  ZS2a:
    mov edx, chartab[edx*4]         ; look up 2 digits
    mov [esi], dx                   ; write them to answer
    add esi, 2

  ZS3:
    mov eax, edi                    ; get lower 4 digits
    mov edx, 28F5C29h               ; 2^32\100 +1
    mul edx                         ; edx= top pair
  ZS3a:
    mov edx, chartab[edx*4]         ; look up 2 digits
    mov [esi], dx                   ; write to answer
    add esi, 2                      ; update pointer

  ZS4:
    mul ecx                         ; get final 2 digits
  ZS4a:
    mov edx, chartab[edx*4]         ; look them up
    mov [esi], dx                   ; write to answer

    mov byte ptr [esi+2], 0         ; zero terminate string

  sdwordend:

    pop edi
    pop esi
    ret 8
IEexDwordToAscii ENDP
OPTION PROLOGUE:PrologueDef
OPTION EPILOGUE:EpilogueDef
;------------------------------------------------------------------------------


IEEX_ALIGN
;------------------------------------------------------------------------------
; IEexAsciiHexToDword - Masm32 htodw function. hex string into dword value.
; Returns: dword value of the decoded hex string.
;------------------------------------------------------------------------------
IEexAsciiHexToDword PROC lpszAsciiHexString:DWORD
    ; written by Alexander Yackubtchik

    push ebx
    push ecx
    push edx
    push edi
    push esi

    mov edi, lpszAsciiHexString
    mov esi, lpszAsciiHexString

    ALIGN 4

again:
    mov al,[edi]
    inc edi
    or  al,al
    jnz again
    sub esi,edi
    xor ebx,ebx
    add edi,esi
    xor edx,edx
    not esi             ;esi = lenth

    .WHILE esi != 0
        mov al, [edi]
        cmp al,'A'
        jb figure
        sub al,'a'-10
        adc dl,0
        shl dl,5            ;if cf set we get it bl 20h else - 0
        add al,dl
        jmp next
    figure:
        sub al,'0'
    next:
        lea ecx,[esi-1]
        and eax, 0Fh
        shl ecx,2           ;mul ecx by log 16(2)
        shl eax,cl          ;eax * 2^ecx
        add ebx, eax
        inc edi
        dec esi
    .ENDW

    mov eax,ebx

    pop esi
    pop edi
    pop edx
    pop ecx
    pop ebx

    ret
IEexAsciiHexToDword ENDP


IEEX_ALIGN
;------------------------------------------------------------------------------
; IEexDwordToAsciiHex - Convert dword to ascii hex string.
; lpszAsciiHexString must be at least 11 bytes long.
; Returns: Buffer pointed to by lpszAsciiHexString will contain ascii hex string
;------------------------------------------------------------------------------
IEexDwordToAsciiHex PROC USES EDI dwValue:DWORD, lpszAsciiHexString:DWORD, bUppercase:DWORD
    LOCAL dwVal:DWORD
    LOCAL lpHexStart:DWORD

    mov edi, lpszAsciiHexString
    mov byte ptr [edi], '0'     ; 0
    mov byte ptr [edi+1], 'x'   ; x
    mov eax, edi
    add eax, 2
    mov lpHexStart, eax
    add edi, 10d
    mov byte ptr [edi], 0       ; null string
    dec edi

    mov eax, dwValue
    mov dwVal, eax

convert:
    mov eax, dwVal
    and eax, 0Fh                ; get digit
    .IF al < 10
        add al, "0"             ; convert digits 0-9 to ascii
    .ELSE
        .IF bUppercase == TRUE
            add al, ("A"-10)    ; convert digits 0Ah to 0Fh to uppercase ascii A-F
        .ELSE
            add al, ("a"-10)    ; convert digits 0Ah to 0Fh to lowercase ascii a-f
        .ENDIF
    .ENDIF
    mov byte ptr [edi], al
    dec edi
    ror dwVal, 4
    cmp edi, lpHexStart
    jae convert
    ret
IEexDwordToAsciiHex ENDP


IEEX_ALIGN
;-------------------------------------------------------------------------------------
; Convert a human readable hex based string to raw bytes
; lpRaw should be at least half the size of the lpszAsciiHexString
; Returns: On success eax contains size of raw bytes in lpRaw, or 0 if failure.
;-------------------------------------------------------------------------------------
IEexHexStringToRaw PROC USES EBX EDI ESI lpszAsciiHexString:DWORD, lpRaw:DWORD
    LOCAL pos:DWORD
    LOCAL dwLenHexString:DWORD
    LOCAL dwLenRaw:DWORD
    
    .IF lpRaw == NULL || lpszAsciiHexString == NULL
        mov eax, 0
        ret
    .ENDIF

    Invoke lstrlen, lpszAsciiHexString
    .IF eax == 0
        ret
    .ENDIF
    mov dwLenHexString, eax

    xor ebx, ebx
    mov dwLenRaw, 0
    mov pos, 0d
    mov edi, lpRaw
    mov esi, lpszAsciiHexString
    mov eax, 0
    .WHILE eax < dwLenHexString
        ; first ascii char
        movzx eax, byte ptr [esi]
        .IF al >= 48 && al <=57d
            sub al, 48d
        .ELSEIF al >= 65d && al <= 90d
            sub al, 55d
        .ELSEIF al >= 97d && al <= 122d
            sub al, 87d
        .ELSEIF al == ' '           ; skip space character
            inc esi
            inc pos
            mov eax, pos
            .CONTINUE
        .ELSEIF al == 0             ; null
            .BREAK                  ; exit as we hit null
        .ELSE
            mov dwLenRaw, 0         ; set to 0 for error
            .BREAK                  ; exit as not 0-9, a-f, A-F
        .ENDIF

        shl al, 4
        mov bl, al
        inc esi

        ; second ascii char
        movzx eax, byte ptr [esi]
        .IF al >= 48 && al <=57d
            sub al, 48d
        .ELSEIF al >= 65d && al <= 90d
            sub al, 55d
        .ELSEIF al >= 97d && al <= 122d
            sub al, 87d
        .ELSEIF al == ' '           ; skip space character
            mov byte ptr [edi], al  ; store the asciihex(AL) in the raw buffer 
            inc dwLenRaw
            inc edi
            inc esi
            inc pos
            mov eax, pos
            .CONTINUE               ; loop again to get next chars
        .ELSEIF al == 0             ; null
            mov byte ptr [edi], al  ; store the asciihex(AL) in the raw buffer
            inc dwLenRaw
            .BREAK                  ; exit as we hit null
        .ELSE
            mov dwLenRaw, 0         ; set to 0 for error
            .BREAK                  ; exit as not 0-9, a-f, A-F
        .ENDIF
        
        add al, bl
        mov byte ptr [edi], al      ; store the asciihex(AL) in the raw buffer   
        
        inc dwLenRaw
        inc edi
        inc esi
        inc pos
        mov eax, pos
    .ENDW

    mov eax, dwLenRaw
    ret
IEexHexStringToRaw ENDP


IEEX_ALIGN
;-------------------------------------------------------------------------------------
; Convert raw bytes to a human readable hex based string
; lpszAsciiHexString should be at least twice the size of dwRawSize +1 byte for null
; Returns: TRUE if success, FALSE otherwise
;-------------------------------------------------------------------------------------
IEexRawToHexString PROC USES EDI ESI lpRaw:DWORD, dwRawSize:DWORD, lpszAsciiHexString:DWORD, bUpperCase:DWORD
    LOCAL pos:DWORD
    
    .IF lpRaw == NULL || dwRawSize == 0 || lpszAsciiHexString == NULL
        mov eax, FALSE
        ret
    .ENDIF

    mov pos, 0d
    mov edi, lpszAsciiHexString
    mov esi, lpRaw
    mov eax, 0
    .WHILE eax < dwRawSize
        movzx eax, byte ptr [esi]
        mov ah,al
        ror al, 4                   ; shift in next hex digit
        and al, 0FH                 ; get digit
        .IF al < 10
            add al, "0"             ; convert digits 0-9 to ascii
        .ELSE
            .IF bUpperCase == TRUE
                add al, ("A"-10)    ; convert digits 0Ah to 0Fh to uppercase ascii A-F
            .ELSE
                add al, ("a"-10)    ; convert digits 0Ah to 0Fh to lowercase ascii a-f
            .ENDIF
        .ENDIF
        mov byte ptr [edi], al      ; store the asciihex(AL) in the string   
        inc edi
        mov al,ah
        
        and al, 0FH                 ; get digit
        .IF al < 10
            add al, "0"             ; convert digits 0-9 to ascii
        .ELSE
            .IF bUpperCase == TRUE
                add al, ("A"-10)    ; convert digits 0Ah to 0Fh to uppercase ascii A-F
            .ELSE
                add al, ("a"-10)    ; convert digits 0Ah to 0Fh to lowercase ascii a-f
            .ENDIF
        .ENDIF
        mov byte ptr [edi], al      ; store the asciihex(AL) in the string   

        inc edi
        inc esi
        inc pos
        mov eax, pos
    .ENDW
    mov byte ptr [edi], 0
    
    mov eax, TRUE
    ret
IEexRawToHexString ENDP





END DllEntry



