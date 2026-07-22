@echo off
if not defined JIDECARDS_OHOS_CLANG (
  echo JIDECARDS_OHOS_CLANG is required. 1>&2
  exit /b 1
)
if not defined JIDECARDS_OHOS_SYSROOT (
  echo JIDECARDS_OHOS_SYSROOT is required. 1>&2
  exit /b 1
)
"%JIDECARDS_OHOS_CLANG%" --target=x86_64-linux-ohos --sysroot="%JIDECARDS_OHOS_SYSROOT%" %*
