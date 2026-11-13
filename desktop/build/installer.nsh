; CCA installer hooks, included by electron-builder (package.json build.nsis.include).
;
; An update must keep the existing install scope. electron-updater runs the
; downloaded installer with --updated: "--updated --force-run" when the user
; picks "Restart now" (not silent), "--updated /S" when the app quits after the
; download. The assisted installer skips its license and directory pages when
; updated, but still shows "Choose Installation Options" (only for me / anyone
; who uses this computer), so a non-silent update could move a per-user copy
; to Program Files behind a UAC prompt. When exactly one existing install is
; found, keep its scope and skip that page; otherwise (fresh install, or both
; scopes installed) the page behaves as before. The uninstaller is unchanged.
!macro customInstallMode
  !ifndef BUILD_UNINSTALLER
    ${if} ${isUpdated}
      ${if} $hasPerUserInstallation == "1"
      ${andIf} $hasPerMachineInstallation == "0"
        StrCpy $isForceCurrentInstall "1"
      ${elseIf} $hasPerMachineInstallation == "1"
      ${andIf} $hasPerUserInstallation == "0"
        StrCpy $isForceMachineInstall "1"
      ${endIf}
    ${endIf}
  !endif
!macroend

; electron-builder 26 guards the hook with "!ifmacrodef customInstallmode"
; (lowercase m) before "!insertmacro customInstallMode"; v27 fixed the guard
; (electron-builder #10161). If macro names are matched case-sensitively, that
; guard misses the macro above and the hook is skipped without an error, so
; also define the lowercase name, empty, only when it is not already visible.
!ifmacrondef customInstallmode
  !macro customInstallmode
  !macroend
!endif
