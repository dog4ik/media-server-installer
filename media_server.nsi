!verbose 3
;SetCompressor /SOLID bzip2 TODO Review if this is best option
ShowInstDetails show
ShowUninstDetails show
Unicode True

; Global variables that we'll use
Var _MEDIASERVERDATADIR_
Var _SETUPTYPE_
Var _EXISTINGINSTALLATION_
Var _FOLDEREXISTS_


!define INSTALL_DIRECTORY "$PROGRAMFILES64\MediaServer"
!define INSTDIR_REG_ROOT "HKLM" ;Define root hive to use
!define INSTDIR_REG_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\MediaServer" ;Registry to show up in Add/Remove Programs

;--------------------------------
;Include Modern UI

!include "MUI2.nsh"

;--------------------------------
;General

!define REG_CONFIG_KEY "Software\MediaServer" ;Registry to store all configuration

Name "Media Server" ; This is referred in various header text labels
OutFile "media-server-setup-win-x64.exe" ;
BrandingText "Media Server Installer" ; This shows in just over the buttons

; installer attributes, these show up in details tab on installer properties
VIProductVersion "0.1.0.0" ; VIProductVersion format, should be X.X.X.X
VIFileVersion "0.1.0.0" ; VIFileVersion format, should be X.X.X.X
VIAddVersionKey "ProductName" "Media Server"
VIAddVersionKey "FileVersion" "0.1.0.0"
VIAddVersionKey "LegalCopyright" "(c) 2024 Vadim Gerasimov. Code released under the GNU General Public License."
VIAddVersionKey "FileDescription" "Media Server: Download and watch content on any device"

InstallDir ${INSTALL_DIRECTORY} ;Default installation folder
InstallDirRegKey HKLM "${REG_CONFIG_KEY}" "InstallFolder" ;Read the registry for install folder,

;Request application privileges
RequestExecutionLevel admin

CRCCheck on ; make sure the installer wasn't corrupted while downloading

;--------------------------------
;Interface Settings

!define MUI_ABORTWARNING ;Prompts user in case of aborting install

;--------------------------------

!ifdef UXPATH
!define MUI_ICON "${UXPATH}\branding\NSIS\modern-install.ico" ; Installer Icon
!define MUI_UNICON "${UXPATH}\branding\NSIS\modern-install.ico" ; Uninstaller Icon

!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "${UXPATH}\branding\NSIS\installer-header.bmp"
!define MUI_WELCOMEFINISHPAGE_BITMAP "${UXPATH}\branding\NSIS\installer-right.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "${UXPATH}\branding\NSIS\installer-right.bmp"
!endif

;Pages

;Welcome
!define MUI_WELCOMEPAGE_TEXT "The installer will ask for details to install Media Server."
!insertmacro MUI_PAGE_WELCOME

;License
!insertmacro MUI_PAGE_LICENSE "media-server\LICENSE" ; picking up generic GPL

;Install folder page
!define MUI_PAGE_CUSTOMFUNCTION_PRE HideInstallDirectoryPage ; Controls when to hide / show
!define MUI_DIRECTORYPAGE_TEXT_DESTINATION "Install folder" ; shows just above the folder selection dialog
!define MUI_DIRECTORYPAGE_TEXT_TOP "Setup will install Media Server in the following folder."
!insertmacro MUI_PAGE_DIRECTORY

!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

;--------------------------------
;Languages

!insertmacro MUI_LANGUAGE "English"

;--------------------------------
;Installer Sections

Section "!Media Server (required)" InstallMediaServer
  SectionIn RO ; Mandatory section, isn't this the whole purpose to run the installer.

  StrCmp "$_EXISTINGINSTALLATION_" "Yes" RunUninstaller ; Silently uninstall in case of previous installation
  RunUninstaller:
  DetailPrint "Looking for uninstaller at $INSTDIR"
  FindFirst $0 $1 "$INSTDIR\Uninstall.exe"
  FindClose $0
  StrCmp $1 "" CarryOn ; the registry key was there but uninstaller was not found

  DetailPrint "Silently running the uninstaller at $INSTDIR"
  ExecWait '"$INSTDIR\Uninstall.exe" /S _?=$INSTDIR' $0
  DetailPrint "Uninstall finished, $0"

  CarryOn:

  SetOutPath "$INSTDIR"

  File icon.ico
  File media-server\target\release\media-server.exe
  File ffmpeg\bin\ffmpeg.exe
  File ffmpeg\bin\ffprobe.exe

  SetOutPath "$INSTDIR\dist"
  File "media-server-web\dist\"
  SetOutPath "$INSTDIR\dist\assets"
  File "media-server-web\dist\assets\"
  SetOutPath "$INSTDIR"

  ;Store installation folder
  ;Write the InstallFolder into the registry for later use
  WriteRegExpandStr HKLM "${REG_CONFIG_KEY}" "InstallFolder" "$INSTDIR"

  ;Write the uninstall keys for Windows
  WriteRegStr HKLM "${INSTDIR_REG_KEY}" "DisplayName" "Media Server"
  WriteRegExpandStr HKLM "${INSTDIR_REG_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKLM "${INSTDIR_REG_KEY}" "DisplayIcon" '"$INSTDIR\Uninstall.exe",0'
  WriteRegStr HKLM "${INSTDIR_REG_KEY}" "Publisher" "The Media Server"
  WriteRegStr HKLM "${INSTDIR_REG_KEY}" "URLInfoAbout" "https://github.com/dog4ik/media-server"
  WriteRegStr HKLM "${INSTDIR_REG_KEY}" "DisplayVersion" "0.0.1"
  WriteRegDWORD HKLM "${INSTDIR_REG_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${INSTDIR_REG_KEY}" "NoRepair" 1

  ;Create uninstaller
  WriteUninstaller "$INSTDIR\Uninstall.exe"
SectionEnd

Section "Create Shortcuts" CreateWinShortcuts
  CreateDirectory "$SMPROGRAMS\Media Server"
  CreateShortCut "$DESKTOP\Media Server.lnk" "$INSTDIR\media-server.exe" "--tmdb-token ${TMDB_TOKEN}" "$INSTDIR\icon.ico" 0
SectionEnd

;--------------------------------
;Descriptions

;Language strings
LangString DESC_InstallMediaServer ${LANG_ENGLISH} "Install Media Server"

;Assign language strings to sections
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
!insertmacro MUI_DESCRIPTION_TEXT ${InstallMediaServer} $(DESC_InstallMediaServer)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

;--------------------------------
;Uninstaller Section

Section "Uninstall"

  ReadRegStr $INSTDIR HKLM "${REG_CONFIG_KEY}" "InstallFolder" ; read the installation folder
  DetailPrint "Media server Install location: $INSTDIR"

  MessageBox MB_YESNO|MB_ICONINFORMATION "Do you want to keep the Media Server data folder? $\r$\nIf unsure choose YES." /SD IDYES IDYES PreserveData IDNO DeleteData

  ;TODO: Remove media server AppData/Local dirs
  DeleteData:
  ;Try to delete only known data dir folders
  RMDir /r /REBOOTOK "$_MEDIASERVERDATADIR_\cache"
  RMDir /r /REBOOTOK "$_MEDIASERVERDATADIR_\config"
  RMDir /r /REBOOTOK "$_MEDIASERVERDATADIR_\data"
  RMDir /r /REBOOTOK "$_MEDIASERVERDATADIR_\log"
  RMDir /r /REBOOTOK "$_MEDIASERVERDATADIR_\metadata"
  RMDir /r /REBOOTOK "$_MEDIASERVERDATADIR_\plugins"
  RMDir /r /REBOOTOK "$_MEDIASERVERDATADIR_\root"
  RMDir /REBOOTOK "$_MEDIASERVERDATADIR_" ; Delete final dir only if empty

  PreserveData:
  ; noop

  RMDir /r "$SMPROGRAMS\MediaServer"
  Delete "$DESKTOP\Media Server.lnk"

  Delete "$INSTDIR\Uninstall.exe"

  RMDir /r /REBOOTOK "$INSTDIR\dist"
  Delete "$INSTDIR\ffmpeg.exe"
  Delete "$INSTDIR\ffprobe.exe"
  Delete "$INSTDIR\icon.ico"
  Delete "$INSTDIR\media-server.exe"
  RMDir "$INSTDIR"

  DeleteRegKey HKLM "Software\MediaServer"
  DeleteRegKey HKLM "${INSTDIR_REG_KEY}"
SectionEnd

Function .onInit
  ; Setting up defaults
  StrCpy $_EXISTINGINSTALLATION_ "No"

  SetShellVarContext current
  StrCpy $_MEDIASERVERDATADIR_ "$%ProgramData%\Media Server"

  ; This blocks another installer from running at the same time
  System::Call 'kernel32::CreateMutex(p 0, i 0, t "MediaServerMutex") p .r1 ?e'
  Pop $R0
  StrCmp $R0 0 +3
  MessageBox MB_OK|MB_ICONSTOP "The installer is already running."
  Abort

  ; Read Registry for previous installation
  ClearErrors
  ReadRegStr "$0" HKLM "${REG_CONFIG_KEY}" "InstallFolder"
  IfErrors NoExisitingInstall

  DetailPrint "Existing Media Server detected at: $0"
  StrCpy "$INSTDIR" "$0" ; set the location fro registry as new default

  StrCpy $_EXISTINGINSTALLATION_ "Yes" ; Set our flag to be used later
  SectionSetText ${InstallMediaServer} "Upgrade Media Server (required)" ; Change install text to "Upgrade"

  SectionSetText ${CreateWinShortcuts} ""

  ; Let the user know that we'll upgrade and provide an option to quit
  MessageBox MB_OKCANCEL|MB_ICONINFORMATION "Existing installation of Media Server was detected, it'll be upgraded, settings will be retained. $\r$\nClick OK to proceed, Cancel to exit installer." /SD IDOK IDOK ProceedWithUpgrade
  Quit ; Quit if the user is not sure about upgrade

  ProceedWithUpgrade:

  NoExisitingInstall: ; by this time, the variables have been correctly set to reflect previous install details

FunctionEnd

Function HideInstallDirectoryPage
  ${If} $_EXISTINGINSTALLATION_ == "Yes" ; Existing installation detected, so don't ask for InstallFolder
    Abort
  ${EndIf}
FunctionEnd

Function .onInstSuccess
  ; TODO - Eventually add an option to launch tray app or service instead, and remind/offer to start browser
FunctionEnd
