@echo off
setlocal
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars32.bat" >nul
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
endlocal