;------------------------------------------------------------------------------
; IEex.exe - Loader for IEex to inject IEex.dll by github.com/mrfearless
;
; IEex by Bubb: github.com/Bubb13/IEex 
;
;------------------------------------------------------------------------------
include windows.inc

include user32.inc
include kernel32.inc
include version.inc

includelib user32.lib
includelib kernel32.lib
includelib version.lib


;------------------------------------------------------------------------------
; IEex Prototypes
;------------------------------------------------------------------------------
ProcessCmdLine          PROTO
WinMain                 PROTO :DWORD, :DWORD, :DWORD, :DWORD
EnumWindowsProc         PROTO :DWORD, :DWORD
CheckFileVersion        PROTO :DWORD, :DWORD
InjectDLL               PROTO :DWORD, :DWORD

DisplayErrorMessage     PROTO :DWORD, :DWORD
LogMessage              PROTO :DWORD


IFNDEF LANGANDCODEPAGE
LANGANDCODEPAGE         STRUCT
   wLanguage            DW ?
   wCodepage            DW ?
LANGANDCODEPAGE         ENDS
ENDIF

.CONST
IEEX_ALIGN              TEXTEQU <ALIGN 16>

.DATA
;------------------------------------------------------------------------------
; IEex Initialized Data
;------------------------------------------------------------------------------
AppName                 DB "IEex loader",0
szAppName               DB "[IEex loader]",0
szAppVersion            DB " v1.0.0.3",0
szIEexLoaderByfearless  DB "IEex loader by fearless: github.com/mrfearless/IEexLoader",0
szIEexByBubb            DB "IEex by Bubb: github.com/Bubb13/IEex",0
szCRLF                  DB 13,10,0
szInfoEntry             DB "[*] ",0
szStatusEntry           DB "[-] ",0
szErrorEntry            DB "[!] ",0

; Bioware / Black Isle Studios game executables:
szBioware_BG            DB "BGMain.exe",0
szBioware_BG2           DB "BGMain.exe",0
szBlackIsle_IWD         DB "IDMain.exe",0
szBlackIsle_IWD2        DB "IWD2.exe",0
szBlackIsle_PST         DB "Torment.exe",0

szBioware_BGExeVersion  DB "2.5.0.0",0
szBioware_BG2ExeVersion DB "2.5.0.0",0
szBlackIsle_IWDExeVersion DB "1.4.2.0",0
szBlackIsle_IWD2ExeVersion DB "2.0.1.0",0
szBlackIsle_PSTExeVersion DB "1.0.0.1",0


szOverride              DB "\override\",0
szUImenu                DB "UI.menu",0
szTRIGGERids            DB "TRIGGER.ids",0
szOBJECTids             DB "OBJECT.ids",0
szACTIONids             DB "ACTION.ids",0
szM__IEexlua            DB "M__IEex.lua",0
szIEexDB                DB "\IEex.db",0

szIEexDLL               DB "IEex.dll",0
szKernel32Dll           DB "kernel32.dll",0
szLoadLibraryProc       DB "LoadLibraryA",0

szVerRoot               DB "\\",0
szLang                  DB "\VarFileInfo\Translation",0
szProductVersion        DB "\StringFileInfo\%04x%04x\ProductVersion",0
szFileVersion           DB "%d.%d.%d.%d",0
szFormatErrorMessage    DB 'Error: ', '%s', 0

;------------------------------------------------------------------------------
; Error Strings
;------------------------------------------------------------------------------

; IE Game Locate And Execute Error Messages:
szErrorIEGameRunning    DB "A classic Infinity Engine game is already running, please close it before launching IEex.",0
szErrorIEGameExecute    DB "CreateProcess failed to execute classic Infinity Engine game executable. ",0
szErrorIEGameEXE        DB "Failed to locate a classic Infinity Engine game executable.",0
szErrorIEexDLLFind      DB "Failed to locate IEex.dll. Make sure it is located in the game folder along with IEex.exe",0   
szErrorM__IEexMissing   DB "M__IEex.lua is missing in the override folder - cannot continue.",0
szErrorIEexDBMissing    DB "IEex.db is missing - cannot continue.",0

; IE Game Version Check Error Messages:
szErrorBioware_BG       DB "Your version of Baldur's Gate is incompatible with IEex.",0
szErrorBioware_BG2      DB "Your version of Baldur's Gate II: Throne of Bhaal is incompatible with IEex.",0
szErrorBlackIsle_IWD    DB "Your version of Icewind Dale is incompatible with IEex.",0
szErrorBlackIsle_IWD2   DB "Your version of Icewind Dale II is incompatible with IEex.",0
szErrorBlackIsle_PST    DB "Your version of Planescape Torment is incompatible with IEex.",0
 
; CheckFileVersion Error Messages:
szErrorGetVersionInfo   DB "CheckFileVersion: GetFileVersionInfo failed.",0
szErrorVerQueryValue    DB "CheckFileVersion: VerQueryValue failed.",0
szErrorGetVersionSize   DB "CheckFileVersion: GetFileVersionInfoSizeA failed.",0
szErrorHeap             DB "CheckFileVersion: GetProcessHeap failed.",0
szErrorHeapAlloc        DB "CheckFileVersion: HeapAlloc failed.",0

; InjectDLL Error Messages:
szErrorVirtualAllocEx   DB "InjectDLL: VirtualAllocEx failed. ",0
szErrorWriteProcessMem  DB "InjectDLL: WriteProcessMemory failed. ",0
szErrorGetModuleHandle  DB "InjectDLL: GetModuleHandle failed. ",0
szErrorGetProcAddress   DB "InjectDLL: GetProcAddress failed. ",0
szErrorRemoteThread     DB "InjectDLL: CreateRemoteThread failed. ", 0
szErrorWaitSingleObj    DB "InjectDLL: WaitForSingleObject failed. ",0
szErrorWaitSingleInv    DB "InjectDLL: WaitForSingleObject returned invalid value. ",0
szErrorExitCodeThread   DB "InjectDLL: GetExitCodeThread failed. ",0
szErrorThreadActive     DB "InjectDLL: hRemoteThread still active. ",0

szStatusLaunchingIEGame DB "Launching IE game executable: ",0
szStatusInjectingDLL    DB "Injecting IEex.dll into IE game executable.",0
szStatusRedirectCon     DB "Redirecting console output of IE game executable: ",0

szCurrentFolder         DB MAX_PATH DUP (0)
szIEGameEXE             DB MAX_PATH DUP (0)
szIEGameOverrideFolder  DB MAX_PATH DUP (0)

szFileM__IEexlua        DB MAX_PATH DUP (0)
szFileIEexDB            DB MAX_PATH DUP (0)




.DATA?
;------------------------------------------------------------------------------
; IEex Uninitialized Data
;------------------------------------------------------------------------------
szFileVersionBuffer     DB 64 DUP (?)
szClassName             DB MAX_PATH DUP (?)
szWindowTitle           DB MAX_PATH DUP (?)
szErrorMessage          DB 512 DUP (?)
hInstance               DD ?
CommandLine             DD ?
hWnd                    DD ?
startinfo               STARTUPINFO <>
pi                      PROCESS_INFORMATION <>
wfd                     WIN32_FIND_DATA <>
ExitCode                DD ?
hConOutput              DD ?

