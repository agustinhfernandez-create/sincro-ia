@echo off
rem Lanzador de Sincro IA: abre el entorno en VSCode (o una consola si no esta VSCode)
cd /d "%~dp0"
where code >nul 2>nul
if %errorlevel%==0 (
    start "" code "%~dp0"
) else (
    echo VSCode no esta instalado. Abriendo una consola en la carpeta del entorno...
    start "" cmd /k "cd /d %~dp0 && echo Escribi:  claude   para iniciar Sincro IA."
)
