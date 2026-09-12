@echo off
setlocal

rem ===== Найти vcvars32.bat автоматически (VS 18 / vswhere) =====
set "VCVARS="
if exist "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars32.bat" (
  set "VCVARS=C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars32.bat"
)
if not defined VCVARS (
  for /f "delims=" %%i in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2^>nul') do (
    if exist "%%i\VC\Auxiliary\Build\vcvars32.bat" set "VCVARS=%%i\VC\Auxiliary\Build\vcvars32.bat"
  )
)
if not defined VCVARS (
  echo [ERROR] vcvars32.bat not found. Install Visual Studio with MSVC x86 tools.
  exit /b 1
)

call "%VCVARS%" >nul
if errorlevel 1 (
  echo [ERROR] vcvars32.bat failed
  exit /b 1
)

cl /nologo /O2 /MT /EHsc /std:c++17 /TP /DNDEBUG /DHAVE_STDINT_H /D_CRT_SECURE_NO_WARNINGS ^
   /I sdk /I src ^
   src\main.cpp sdk\amxplugin.cpp sdk\amxplugin2.cpp ^
   src\lua\lapi.c src\lua\lcode.c src\lua\lctype.c src\lua\ldebug.c ^
   src\lua\ldo.c src\lua\ldump.c src\lua\lfunc.c src\lua\lgc.c ^
   src\lua\llex.c src\lua\lmem.c src\lua\lobject.c src\lua\lopcodes.c ^
   src\lua\lparser.c src\lua\lstate.c src\lua\lstring.c src\lua\ltable.c ^
   src\lua\ltm.c src\lua\lundump.c src\lua\lvm.c src\lua\lzio.c ^
   src\lua\lauxlib.c src\lua\lbaselib.c src\lua\lcorolib.c src\lua\ldblib.c ^
   src\lua\liolib.c src\lua\lmathlib.c src\lua\loadlib.c src\lua\loslib.c ^
   src\lua\lstrlib.c src\lua\ltablib.c src\lua\lutf8lib.c src\lua\linit.c ^
   /link /DLL /MACHINE:X86 /DEF:salua_lua.def /OUT:salua_lua.dll
if errorlevel 1 (
  echo [ERROR] build failed
  exit /b 1
)
echo [OK] salua_lua.dll built
endlocal