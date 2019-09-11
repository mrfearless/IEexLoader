;------------------------------------------------------------------------------
; IEex.exe - Loader for IEex to inject IEex.dll by github.com/mrfearless
;
; IEex by Bubb: github.com/Bubb13/IEex 
; https://forums.beamdog.com/discussion/71798/mod-IEex-v0-2-1-alpha/p1
;------------------------------------------------------------------------------
.686
.MMX
.XMM
.model flat,stdcall
option casemap:none
include \masm32\macros\macros.asm
;
;DEBUG32 EQU 1
;IFDEF DEBUG32
;    PRESERVEXMMREGS equ 1
;    includelib M:\Masm32\lib\Debug32.lib
;    DBG32LIB equ 1
;    DEBUGEXE textequ <'M:\Masm32\DbgWin.exe'>
;    include M:\Masm32\include\debug32.inc
;ENDIF



include IEex.inc
include IEexConsole.asm

CHECK_EXE_FILEVERSION       EQU 1 ; uncomment for exe file version checks
CHECK_IEexDLL_EXISTS        EQU 1 ; uncomment to check if IEex.dll exists
;CHECK_IEexDB_EXISTS         EQU 1 ; uncomment to check if IEex.db exists
CHECK_IEexLUA_EXISTS        EQU 1 ; uncomment to check if M___IEex.lua exists
;CHECK_OVERRIDE_FILES        EQU 1 ; uncomment to check if override files exists

.CODE

;------------------------------------------------------------------------------
; Start
;------------------------------------------------------------------------------
start:

    Invoke GetModuleHandle, NULL
    mov hInstance, eax
    Invoke GetCommandLine
    mov CommandLine, eax
    
    Invoke ConsoleInit    
    Invoke WinMain, hInstance, NULL, CommandLine, SW_SHOWDEFAULT
    Invoke ConsoleExit
    
    Invoke ExitProcess, eax
    ret


IEEX_ALIGN
;------------------------------------------------------------------------------
; WinMain
;------------------------------------------------------------------------------
WinMain PROC USES EBX hInst:HINSTANCE, hPrevInst:HINSTANCE, CmdLine:LPSTR, CmdShow:DWORD
    LOCAL dwExitCode:DWORD
    LOCAL dwIEGameRunning:DWORD
    LOCAL bIEGameFound:DWORD
    LOCAL lpszIEGame:DWORD
    LOCAL lenIEGame:DWORD
    LOCAL lenOverride:DWORD
    LOCAL bMissingOverrides:DWORD
    LOCAL childconsolesize:COORD
    
    mov bMissingOverrides, FALSE
    mov bIEGameFound, FALSE
    mov lpszIEGame, 0
    
    Invoke RtlZeroMemory, Addr startinfo, SIZEOF STARTUPINFO
    mov startinfo.cb, SIZEOF STARTUPINFO
    
    ;--------------------------------------------------------------------------
    ; Check if we can attach a console or not, which helps determine if
    ; we started via explorer or via a command line (cmd)
    ;--------------------------------------------------------------------------
    .IF gConsoleStartedMode == TRUE
        Invoke GetStdHandle, STD_OUTPUT_HANDLE
        mov hConOutput, eax
        Invoke ConsoleClearScreen
        Invoke ConsoleText, Addr szAppName
        Invoke ConsoleText, Addr szAppVersion
        Invoke ConsoleText, Addr szCRLF
        Invoke ConsoleText, Addr szCRLF
        Invoke ConsoleText, Addr szInfoEntry
        Invoke ConsoleText, Addr szIEexLoaderByfearless
        Invoke ConsoleText, Addr szCRLF
        Invoke ConsoleText, Addr szInfoEntry
        Invoke ConsoleText, Addr szIEexByBubb
        Invoke ConsoleText, Addr szCRLF
        Invoke ConsoleText, Addr szCRLF
    .ENDIF
    

    ;--------------------------------------------------------------------------
    ; Check IE game is not already running
    ;--------------------------------------------------------------------------
    mov dwIEGameRunning, FALSE
    Invoke EnumWindows, Addr EnumWindowsProc, Addr dwIEGameRunning
    .IF dwIEGameRunning == TRUE
        .IF gConsoleStartedMode == TRUE
            Invoke ConsoleText, Addr szErrorEntry
            Invoke ConsoleText, Addr szErrorIEGameRunning
            Invoke ConsoleText, Addr szCRLF
        .ELSE
            Invoke DisplayErrorMessage, Addr szErrorIEGameRunning, 0
        .ENDIF
        ret
    .ENDIF
    IFDEF DEBUG32
    PrintText 'Check IE game is not already running'
    ENDIF
    
    
    ;--------------------------------------------------------------------------
    ; Search for known IE game executables and check file version
    ;--------------------------------------------------------------------------
    
    ; BG1
    Invoke FindFirstFile, Addr szBioware_BG, Addr wfd
    .IF eax != INVALID_HANDLE_VALUE
        lea eax, wfd.cFileName
        Invoke lstrcpy, Addr szIEGameEXE, eax
        Invoke FindClose, eax
;        IFDEF CHECK_EXE_FILEVERSION
;        Invoke CheckFileVersion, Addr szBioware_BG, Addr szBioware_BGExeVersion ; "2, 5, 0, 0" - dont have this exe to check file version
;        .IF eax == FALSE
;            .IF gConsoleStartedMode == TRUE
;                Invoke ConsoleText, Addr szErrorEntry
;                Invoke ConsoleText, Addr szErrorBioware_BG
;                Invoke ConsoleText, Addr szCRLF
;            .ELSE
;                Invoke DisplayErrorMessage, Addr szErrorBioware_BG, 0
;            .ENDIF
;            ret
;        .ENDIF
;        ENDIF
        mov bIEGameFound, TRUE
        lea eax, szBioware_BG
        mov lpszIEGame, eax
    .ELSE
        IFDEF DEBUG32
        PrintText 'No BG'
        ENDIF
    .ENDIF
    
    ; BG2
    .IF bIEGameFound == FALSE
        Invoke FindFirstFile, Addr szBioware_BG2, Addr wfd
        .IF eax != INVALID_HANDLE_VALUE
            lea eax, wfd.cFileName
            Invoke lstrcpy, Addr szIEGameEXE, eax
            Invoke FindClose, eax
            IFDEF CHECK_EXE_FILEVERSION
            Invoke CheckFileVersion, Addr szBioware_BG2, Addr szBioware_BG2ExeVersion ; "2, 5, 0, 0"
            .IF eax == FALSE
                .IF gConsoleStartedMode == TRUE
                    Invoke ConsoleText, Addr szErrorEntry
                    Invoke ConsoleText, Addr szErrorBioware_BG2
                    Invoke ConsoleText, Addr szCRLF
                .ELSE
                    Invoke DisplayErrorMessage, Addr szErrorBioware_BG2, 0
                .ENDIF
                ret
            .ENDIF
            ENDIF
            mov bIEGameFound, TRUE
            lea eax, szBioware_BG2
            mov lpszIEGame, eax
        .ELSE
            IFDEF DEBUG32
            PrintText 'No BG2'
            ENDIF
        .ENDIF
    .ENDIF

    ; IWD
    .IF bIEGameFound == FALSE
        Invoke FindFirstFile, Addr szBlackIsle_IWD, Addr wfd
        .IF eax != INVALID_HANDLE_VALUE
            lea eax, wfd.cFileName
            Invoke lstrcpy, Addr szIEGameEXE, eax
            Invoke FindClose, eax
            IFDEF CHECK_EXE_FILEVERSION
            Invoke CheckFileVersion, Addr szBlackIsle_IWD, Addr szBlackIsle_IWDExeVersion ; "1, 4, 2, 0"
            .IF eax == FALSE
                .IF gConsoleStartedMode == TRUE
                    Invoke ConsoleText, Addr szErrorEntry
                    Invoke ConsoleText, Addr szErrorBlackIsle_IWD
                    Invoke ConsoleText, Addr szCRLF
                .ELSE
                    Invoke DisplayErrorMessage, Addr szErrorBlackIsle_IWD, 0
                .ENDIF
                ret
            .ENDIF
            ENDIF
            mov bIEGameFound, TRUE
            lea eax, szBlackIsle_IWD
            mov lpszIEGame, eax
        .ELSE
            IFDEF DEBUG32
            PrintText 'No IWD'
            ENDIF
        .ENDIF
    .ENDIF
    
    ; IWD2
    .IF bIEGameFound == FALSE
        Invoke FindFirstFile, Addr szBlackIsle_IWD2, Addr wfd
        .IF eax != INVALID_HANDLE_VALUE
            lea eax, wfd.cFileName
            Invoke lstrcpy, Addr szIEGameEXE, eax
            Invoke FindClose, eax
            IFDEF CHECK_EXE_FILEVERSION
            Invoke CheckFileVersion, Addr szBlackIsle_IWD2, Addr szBlackIsle_IWD2ExeVersion ; "2, 0, 1, 0"
            .IF eax == FALSE
                .IF gConsoleStartedMode == TRUE
                    Invoke ConsoleText, Addr szErrorEntry
                    Invoke ConsoleText, Addr szErrorBlackIsle_IWD2
                    Invoke ConsoleText, Addr szCRLF
                .ELSE
                    Invoke DisplayErrorMessage, Addr szErrorBlackIsle_IWD, 0
                .ENDIF
                ret
            .ENDIF
            ENDIF
            mov bIEGameFound, TRUE
            lea eax, szBlackIsle_IWD2
            mov lpszIEGame, eax
        .ELSE
            IFDEF DEBUG32
            PrintText 'No IWD2'
            ENDIF
        .ENDIF
    .ENDIF
    
    ; PST
    .IF bIEGameFound == FALSE
        Invoke FindFirstFile, Addr szBlackIsle_PST, Addr wfd
        .IF eax != INVALID_HANDLE_VALUE
            lea eax, wfd.cFileName
            Invoke lstrcpy, Addr szIEGameEXE, eax
            Invoke FindClose, eax
            IFDEF CHECK_EXE_FILEVERSION
            Invoke CheckFileVersion, Addr szBlackIsle_PST, Addr szBlackIsle_PSTExeVersion ; "1, 0, 0, 1"
            .IF eax == FALSE
                .IF gConsoleStartedMode == TRUE
                    Invoke ConsoleText, Addr szErrorEntry
                    Invoke ConsoleText, Addr szErrorBlackIsle_PST
                    Invoke ConsoleText, Addr szCRLF
                .ELSE
                    Invoke DisplayErrorMessage, Addr szErrorBlackIsle_PST, 0
                .ENDIF
                ret
            .ENDIF
            ENDIF
            mov bIEGameFound, TRUE
            lea eax, szBlackIsle_PST
            mov lpszIEGame, eax
        .ELSE
            IFDEF DEBUG32
            PrintText 'No PST'
            ENDIF
        .ENDIF
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Have we found any IE game exe? Display error message and exit if not
    ;--------------------------------------------------------------------------
    .IF bIEGameFound == FALSE
        IFDEF DEBUG32
        PrintText 'No IE game'
        ENDIF
        .IF gConsoleStartedMode == TRUE
            Invoke ConsoleText, Addr szErrorEntry
            Invoke ConsoleText, Addr szErrorIEGameEXE
            Invoke ConsoleText, Addr szCRLF
        .ELSE
            Invoke DisplayErrorMessage, Addr szErrorIEGameEXE, 0
        .ENDIF
        ret 
    .ELSE
        IFDEF DEBUG32
        PrintText 'Found IE game'
        ENDIF
    .ENDIF
    
    
    ;--------------------------------------------------------------------------
    ; Check IEex.dll is present? Display error message and exit if not
    ;--------------------------------------------------------------------------
    IFDEF CHECK_IEexDLL_EXISTS
    Invoke FindFirstFile, Addr szIEexDLL, Addr wfd
    .IF eax != INVALID_HANDLE_VALUE
        Invoke FindClose, eax
        IFDEF DEBUG32
        PrintText 'IEex.dll found'
        ENDIF
    .ELSE
        IFDEF DEBUG32
        PrintText 'No IEex.dll'
        ENDIF
        .IF gConsoleStartedMode == TRUE
            Invoke ConsoleText, Addr szErrorEntry
            Invoke ConsoleText, Addr szErrorIEexDLLFind
            Invoke ConsoleText, Addr szCRLF
        .ELSE
            Invoke DisplayErrorMessage, Addr szErrorIEexDLLFind, 0
        .ENDIF
        ret
    .ENDIF
    ENDIF
    
    ;--------------------------------------------------------------------------
    ; check M__IEex.lua in override folder
    ;--------------------------------------------------------------------------    
    IFDEF CHECK_IEexLUA_EXISTS
    Invoke GetCurrentDirectory, SIZEOF szCurrentFolder, Addr szCurrentFolder
    Invoke lstrcpy, Addr szIEGameOverrideFolder, Addr szCurrentFolder
    Invoke lstrcat, Addr szIEGameOverrideFolder, Addr szOverride
    
    Invoke lstrcpy, Addr szFileM__IEexlua, Addr szIEGameOverrideFolder
    Invoke lstrcat, Addr szFileM__IEexlua, Addr szM__IEexlua    
    IFDEF DEBUG32
    PrintString szIEGameOverrideFolder
    PrintString szFileM__IEexlua
    ENDIF
    Invoke GetFileAttributes, Addr szFileM__IEexlua
    .IF eax == INVALID_FILE_ATTRIBUTES
        Invoke GetLastError
        .IF eax == ERROR_FILE_NOT_FOUND
            IFDEF DEBUG32
            PrintText 'M__IEex.lua is missing in the override folder - cannot continue.'
            ENDIF
            .IF gConsoleStartedMode == TRUE
                Invoke ConsoleText, Addr szErrorEntry
                Invoke ConsoleText, Addr szErrorM__IEexMissing
                Invoke ConsoleText, Addr szCRLF
            .ELSE
                Invoke DisplayErrorMessage, Addr szErrorM__IEexMissing, 0
            .ENDIF
            ret
        .ENDIF
    .ENDIF
    IFDEF DEBUG32
    PrintText 'M__IEex.lua found'
    ENDIF
    ENDIF  
    
    ;--------------------------------------------------------------------------
    ; check IEex.db in current folder
    ;--------------------------------------------------------------------------  
    IFDEF CHECK_IEexDB_EXISTS
    Invoke lstrcpy, Addr szFileIEexDB, Addr szCurrentFolder
    Invoke lstrcat, Addr szFileIEexDB, Addr szIEexDB
    IFDEF DEBUG32
    PrintString szFileIEexDB
    ENDIF
    Invoke GetFileAttributes, Addr szFileIEexDB
    .IF eax == INVALID_FILE_ATTRIBUTES
        Invoke GetLastError
        .IF eax == ERROR_FILE_NOT_FOUND
            IFDEF DEBUG32
            PrintText 'IEex.db is missing - cannot continue.'
            ENDIF
            .IF gConsoleStartedMode == TRUE
                Invoke ConsoleText, Addr szErrorEntry
                Invoke ConsoleText, Addr szErrorIEexDBMissing
                Invoke ConsoleText, Addr szCRLF
            .ELSE
                Invoke DisplayErrorMessage, Addr szErrorIEexDBMissing, 0
            .ENDIF
            ret
        .ENDIF
    .ENDIF
    IFDEF DEBUG32
    PrintText 'IEex.db found'
    ENDIF
    ENDIF   
    
    ;--------------------------------------------------------------------------
    ; Prepare Startup info for pipe redirection if IEex.exe started via console
    ;--------------------------------------------------------------------------
    .IF gConsoleStartedMode == TRUE ; started via Console
        IFDEF DEBUG32
        PrintText 'Console mode - redirection of child process stdout'
        ENDIF

        mov SecuAttr.nLength, SIZEOF SECURITY_ATTRIBUTES
        mov SecuAttr.lpSecurityDescriptor, NULL
        mov SecuAttr.bInheritHandle, TRUE
;        
;        Invoke CreatePipe, Addr hChildStd_OUT_Rd, Addr hChildStd_OUT_Wr, Addr SecuAttr, 0 
;        Invoke SetHandleInformation, hChildStd_OUT_Rd, HANDLE_FLAG_INHERIT, 0
;        
;        Invoke CreatePipe, Addr hChildStd_IN_Rd, Addr hChildStd_IN_Wr, Addr SecuAttr, 0
;        Invoke SetHandleInformation, hChildStd_IN_Wr, HANDLE_FLAG_INHERIT, 0
        
;        mov eax, hChildStd_OUT_Wr
;        mov startinfo.hStdError, eax
;        mov startinfo.hStdOutput, eax
;        mov eax, hChildStd_IN_Rd
;        mov startinfo.hStdInput, eax
;        mov startinfo.dwFlags, STARTF_USESTDHANDLES
    .ELSE
        IFDEF DEBUG32
        PrintText 'GUI mode - no console redirection'
        ENDIF    
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Launch IE game's executable, ready for injection of our IEex.dll
    ;--------------------------------------------------------------------------
    IFDEF DEBUG32
    PrintText 'Launching IE game executable'
    ENDIF
    .IF gConsoleStartedMode == TRUE
        Invoke ConsoleText, Addr szStatusEntry
        Invoke ConsoleText, Addr szStatusLaunchingIEGame
        Invoke ConsoleText, lpszIEGame
        Invoke ConsoleText, Addr szCRLF
    .ENDIF
    Invoke CreateProcess, lpszIEGame, NULL, NULL, NULL, TRUE, CREATE_SUSPENDED, NULL, NULL, Addr startinfo, Addr pi
    .IF eax != 0 ; CreateProcess success
        ;----------------------------------------------------------------------
        ; Inject IEex.dll into IE game and resume IE game execution
        ;
        ; IEex.dll will be loaded by IE game and call its DllEntry procedure
        ; which will call IEex.dll:IEexInitDll to begin searching for lua
        ; functions and patching the IE game to redirect a call to IEexLuaInit
        ;  
        ; call XXXIEgame:luaL_loadstring replaced with call IEex.dll:IEexLuaInit
        ;----------------------------------------------------------------------
        .IF gConsoleStartedMode == TRUE
            Invoke ConsoleText, Addr szStatusEntry
            Invoke ConsoleText, Addr szStatusInjectingDLL
            Invoke ConsoleText, Addr szCRLF
        .ENDIF

        IFDEF DEBUG32
        PrintText 'InjectDLL'
        ENDIF
        Invoke InjectDLL, pi.hProcess, Addr szIEexDLL
        mov dwExitCode, eax
        Invoke ResumeThread, pi.hThread

        .IF gConsoleStartedMode == TRUE
            ;------------------------------------------------------------------
            ; Redirect IE game output to our allocated console
            ;------------------------------------------------------------------
            ;mov childconsolesize.x, 80
            ;mov childconsolesize.y, 1
            ;Invoke SetConsoleScreenBufferSize, hChildStd_OUT_Rd, Addr childconsolesize
            
;            Invoke ConsoleText, Addr szStatusEntry
;            Invoke ConsoleText, Addr szStatusRedirectCon
;            Invoke ConsoleText, Addr szCRLF
;            Invoke ConsoleText, Addr szCRLF
;            
;            IFDEF DEBUG32
;            PrintText 'ReadFromPipe'
;            ENDIF            
;
;            ;Invoke ReadFromPipe
;            
;            IFDEF DEBUG32
;            PrintText 'Exit From ReadFromPipe'
;            ENDIF                 
            Invoke ConsoleText, Addr szCRLF
            ;Invoke ConsoleSendEnterKey
            ;Invoke FreeConsole
            Invoke CloseHandle, hChildStd_OUT_Rd
            Invoke CloseHandle, hChildStd_OUT_Wr
            Invoke CloseHandle, hChildStd_IN_Rd
            Invoke CloseHandle, hChildStd_IN_Wr
            .IF hLogFile != 0
                Invoke CloseHandle, hLogFile
            .ENDIF
        .ENDIF

;        IFDEF DEBUG32
;        PrintText 'CloseHandle for thread and process'
;        ENDIF  

        ;Invoke CloseHandle, pi.hThread
        ;Invoke CloseHandle, pi.hProcess
        .IF dwExitCode != TRUE
            ret
        .ENDIF
    .ELSE ; CreateProcess failed
        .IF gConsoleStartedMode == TRUE
            Invoke ConsoleText, Addr szErrorEntry
            Invoke ConsoleText, Addr szErrorIEGameExecute
            Invoke ConsoleText, Addr szCRLF
        .ELSE    
            Invoke GetLastError
            Invoke DisplayErrorMessage, Addr szErrorIEGameExecute, eax
        .ENDIF
        ret
    .ENDIF    

    mov eax, 0
    ret
WinMain ENDP

IEEX_ALIGN
;------------------------------------------------------------------------------
; EnumWindowsProc - enumerates all top-level windows
; Search for SDLapp class and if found check window title for IE game
;------------------------------------------------------------------------------
EnumWindowsProc PROC USES EBX hWindow:DWORD, lParam:DWORD
    Invoke GetClassName, hWindow, Addr szClassName, SIZEOF szClassName
    .IF eax != 0
        lea ebx, szClassName
        mov eax, [ebx]
        .IF eax == 'tihC' ; 'Chit'in reversed ; ChitinClass
            Invoke GetWindowText, hWindow, Addr szWindowTitle, SIZEOF szWindowTitle
            .IF eax != 0
                lea ebx, szWindowTitle
                mov eax, [ebx]
                .IF eax == 'dalB' || eax == 'geiS' || eax == 'wecI' || eax == 'nalP' ; Bald, Sieg, Icew, Plan
                    mov ebx, lParam
                    mov eax, TRUE
                    mov [ebx], eax
                    mov eax, FALSE
                    ret
                .ENDIF
            .ENDIF
        .ENDIF
    .ENDIF
    mov eax, TRUE
    ret
EnumWindowsProc ENDP

IEEX_ALIGN
;------------------------------------------------------------------------------
; Displays Error Messages
;------------------------------------------------------------------------------
DisplayErrorMessage PROC USES EDX szMessage:DWORD, dwError:DWORD
    LOCAL lpError:DWORD
    LOCAL nFormatLength:DWORD
    LOCAL nMessageLength:DWORD
    LOCAL szFormat[255]:BYTE
    LOCAL pMessage[255]:BYTE
    LOCAL dwLanguageId:DWORD

    .IF dwError != 0
        xor edx, edx
        mov dl, SUBLANG_DEFAULT
        shl edx, 10
        or edx, LANG_NEUTRAL
        mov dwLanguageId, edx ; dwLanguageId
        Invoke FormatMessage, FORMAT_MESSAGE_ALLOCATE_BUFFER or FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS, NULL, dwError, edx, Addr lpError, 0, NULL
        Invoke wsprintf, Addr szErrorMessage, Addr szFormatErrorMessage, lpError
        Invoke MessageBox, NULL, Addr szErrorMessage, Addr AppName, MB_OK
        Invoke LocalFree, lpError
    .ELSE
        Invoke MessageBox, NULL, szMessage, Addr AppName, MB_OK
    .ENDIF
    xor eax, eax
    ret
DisplayErrorMessage ENDP

IEEX_ALIGN
;------------------------------------------------------------------------------
; Does the actual injection into the IE executable to load the IEex.DLL 
;------------------------------------------------------------------------------
InjectDLL PROC hProcess:HANDLE, szDLLPath:DWORD
    LOCAL szLibPathSize:DWORD
    LOCAL lpLibAddress:DWORD
    LOCAL lpStartRoutine:DWORD
    LOCAL hMod:DWORD
    LOCAL hKernel32:DWORD
    LOCAL BytesWritten:DWORD
    LOCAL hRemoteThread:DWORD
    LOCAL dwRemoteThreadID:DWORD  
    LOCAL dwExitCode:DWORD

    Invoke lstrlen, szDLLPath
    mov szLibPathSize, eax

    Invoke VirtualAllocEx, hProcess, NULL, szLibPathSize, MEM_COMMIT, PAGE_READWRITE
    mov lpLibAddress, eax
    .IF eax == NULL
        .IF gConsoleStartedMode == TRUE
            Invoke ConsoleText, Addr szErrorEntry
            Invoke ConsoleText, Addr szErrorVirtualAllocEx
            Invoke ConsoleText, Addr szCRLF
        .ELSE
            Invoke GetLastError
            Invoke DisplayErrorMessage, Addr szErrorVirtualAllocEx, eax
        .ENDIF
        mov eax, FALSE
        ret
    .ENDIF
    
    Invoke WriteProcessMemory, hProcess, lpLibAddress, szDLLPath, szLibPathSize, Addr BytesWritten
    .IF eax == 0
        .IF gConsoleStartedMode == TRUE
            Invoke ConsoleText, Addr szErrorEntry
            Invoke ConsoleText, Addr szErrorWriteProcessMem
            Invoke ConsoleText, Addr szCRLF
        .ELSE
            Invoke GetLastError
            Invoke DisplayErrorMessage, Addr szErrorWriteProcessMem, eax
        .ENDIF
        mov eax, FALSE
        ret
    .ENDIF

    Invoke GetModuleHandle, 0
    mov hMod, eax
    Invoke GetModuleHandle, Addr szKernel32Dll
    mov hKernel32, eax
    .IF eax == NULL
        .IF gConsoleStartedMode == TRUE
            Invoke ConsoleText, Addr szErrorEntry
            Invoke ConsoleText, Addr szErrorGetModuleHandle
            Invoke ConsoleText, Addr szCRLF
        .ELSE
            Invoke GetLastError
            Invoke DisplayErrorMessage, Addr szErrorGetModuleHandle, eax
        .ENDIF
        mov eax, FALSE
        ret
    .ENDIF

    Invoke GetProcAddress, hKernel32, Addr szLoadLibraryProc
    mov lpStartRoutine, eax        
    .IF eax == NULL
        .IF gConsoleStartedMode == TRUE
            Invoke ConsoleText, Addr szErrorEntry
            Invoke ConsoleText, Addr szErrorGetProcAddress
            Invoke ConsoleText, Addr szCRLF
        .ELSE
            Invoke GetLastError
            Invoke DisplayErrorMessage, Addr szErrorGetProcAddress, eax
        .ENDIF
        mov eax, FALSE
        ret
    .ENDIF
    
    IFDEF DEBUG32
    PrintText 'InjectDLL::CreateRemoteThread'
    ENDIF
    
    Invoke CreateRemoteThread, hProcess, NULL, 0, lpStartRoutine, lpLibAddress, 0, Addr dwRemoteThreadID
    mov hRemoteThread, eax
    .IF eax == NULL
        .IF gConsoleStartedMode == TRUE
            Invoke ConsoleText, Addr szErrorEntry
            Invoke ConsoleText, Addr szErrorRemoteThread
            Invoke ConsoleText, Addr szCRLF
        .ELSE
            Invoke GetLastError
            Invoke DisplayErrorMessage, Addr szErrorRemoteThread, eax
        .ENDIF
        mov eax, FALSE
        ret
    .ENDIF
    
    IFDEF DEBUG32
    PrintText 'InjectDLL::WaitForSingleObject'
    ENDIF
    
    Invoke WaitForSingleObject, hRemoteThread, INFINITE

    .IF eax == WAIT_ABANDONED
        
    .ELSEIF eax == WAIT_OBJECT_0

    .ELSEIF eax == WAIT_TIMEOUT
    
    .ELSEIF eax == WAIT_FAILED
        Invoke GetLastError
        Invoke DisplayErrorMessage, Addr szErrorWaitSingleObj, eax
        mov eax, FALSE
        ret    
    .ELSE    
        Invoke GetLastError
        Invoke DisplayErrorMessage, Addr szErrorWaitSingleInv, 0
        mov eax, FALSE
        ret               
    .ENDIF

    Invoke GetExitCodeThread, hRemoteThread, Addr dwExitCode
    .IF eax == 0
        Invoke GetLastError
        Invoke DisplayErrorMessage, Addr szErrorExitCodeThread, 0
        mov eax, FALSE
        ret   
    .ENDIF

    .IF dwExitCode == STILL_ACTIVE
        Invoke GetLastError
        Invoke DisplayErrorMessage, Addr szErrorThreadActive, 0
        mov eax, FALSE
        ret       
    .ENDIF
    
    Invoke CloseHandle, hRemoteThread
    Invoke VirtualFreeEx, hProcess, lpLibAddress, 0, MEM_RELEASE

    mov eax, dwExitCode    
    ret
InjectDLL endp

IEEX_ALIGN
;------------------------------------------------------------------------------
; Checks file version of the filename for the correct version of IE game
; Returns: eax contains TRUE if version matches, otherwise returns FALSE
;------------------------------------------------------------------------------
IFDEF CHECK_EXE_FILEVERSION
CheckFileVersion PROC USES EBX szVersionFile:DWORD, szVersion:DWORD
    LOCAL verHandle:DWORD
    LOCAL verData:DWORD
    LOCAL verSize:DWORD
    LOCAL verInfo:DWORD
    LOCAL hHeap:DWORD
    LOCAL pBuffer:DWORD
    LOCAL lenBuffer:DWORD
    LOCAL ver1:DWORD
    LOCAL ver2:DWORD
    LOCAL ver3:DWORD
    LOCAL ver4:DWORD

    Invoke GetFileVersionInfoSize, szVersionFile, Addr verHandle
    .IF eax != 0
        mov verSize, eax
        Invoke GetProcessHeap 
        .IF eax != 0 
            mov hHeap, eax 
            Invoke HeapAlloc, eax, 0, verSize
            .IF eax != 0 
                mov verData, eax    
                Invoke GetFileVersionInfo, szVersionFile, 0, verSize, verData
                .IF eax != 0
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
                            mov ver1, eax
                            mov eax, [ebx].VS_FIXEDFILEINFO.dwFileVersionMS
                            shr eax, 0
                            and eax, 0FFFFh
                            mov ver2, eax
                            mov eax, [ebx].VS_FIXEDFILEINFO.dwFileVersionLS
                            shr eax, 16d
                            and eax, 0FFFFh
                            mov ver3, eax
                            mov eax, [ebx].VS_FIXEDFILEINFO.dwFileVersionLS
                            shr eax, 0
                            and eax, 0FFFFh
                            mov ver4, eax
                            
                            Invoke HeapFree, hHeap, 0, verData
                            
                            Invoke wsprintf, Addr szFileVersionBuffer, Addr szFileVersion, ver1, ver2, ver3, ver4
                            Invoke lstrcmp, szVersion, Addr szFileVersionBuffer
                            .IF eax == 0 ; match
                                mov eax, TRUE
                            .ELSE
                                mov eax, FALSE
                            .ENDIF
                        .ELSE
                            Invoke HeapFree, hHeap, 0, verData
                            Invoke GetLastError
                            Invoke DisplayErrorMessage, Addr szErrorVerQueryValue, eax
                            mov eax, FALSE
                            ret                         
                        .ENDIF
                    .ELSE
                        Invoke HeapFree, hHeap, 0, verData
                        mov eax, FALSE
                        ret   
                    .ENDIF
                .ELSE
                    Invoke HeapFree, hHeap, 0, verData
                    Invoke GetLastError
                    Invoke DisplayErrorMessage, Addr szErrorGetVersionInfo, eax
                    mov eax, FALSE
                    ret 
                .ENDIF          
            .ELSE
                Invoke GetLastError
                Invoke DisplayErrorMessage, Addr szErrorHeapAlloc, eax
                mov eax, FALSE
                ret                 
            .ENDIF  
        .ELSE
            Invoke GetLastError
            Invoke DisplayErrorMessage, Addr szErrorHeap, eax
            mov eax, FALSE
            ret             
        .ENDIF                                     
    .ELSE
        Invoke GetLastError
        Invoke DisplayErrorMessage, Addr szErrorGetVersionSize, eax
        mov eax, FALSE
        ret         
    .ENDIF      
    ret
CheckFileVersion endp
ENDIF





end start


