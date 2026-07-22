@echo off
if not defined JIDECARDS_ZIG (
  echo JIDECARDS_ZIG must point to the workspace-local zig.exe. 1>&2
  exit /b 1
)
"%JIDECARDS_ZIG%" cc -target x86_64-windows-gnu -lc %*
