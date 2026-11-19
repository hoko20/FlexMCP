@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"
title Dylix GitHub 一键构建

echo ================================================
echo   Dylix GitHub Actions 一键构建
echo   源码目录：%CD%
echo ================================================
echo.

where git >nul 2>nul
if errorlevel 1 goto :no_git
where gh >nul 2>nul
if errorlevel 1 goto :no_gh

gh auth status >nul 2>nul
if errorlevel 1 (
  echo [*] 需要先登录 GitHub CLI。
  gh auth login
  if errorlevel 1 goto :fail
)

if not exist ".git" (
  echo [*] 初始化本地 Git 仓库...
  git init -b main
  if errorlevel 1 goto :fail
)

for /f "delims=" %%i in ('gh api user --jq .login 2^>nul') do set "GH_USER=%%i"
if not defined GH_USER goto :fail
git config user.name >nul 2>nul
if errorlevel 1 git config user.name "%GH_USER%"
git config user.email >nul 2>nul
if errorlevel 1 git config user.email "%GH_USER%@users.noreply.github.com"

git remote get-url origin >nul 2>nul
if errorlevel 1 goto :new_repo
goto :push

:new_repo
echo [*] 还没有 GitHub 远程仓库。
set "REPO_NAME=dylix"
set /p "REPO_NAME=    仓库名 [dylix]: "
if "!REPO_NAME!"=="" set "REPO_NAME=dylix"
set "VISIBILITY=public"
set /p "VISIBILITY=    可见性 public/private [public]: "
if /i "!VISIBILITY!"=="private" (set "VIS_FLAG=--private") else (set "VIS_FLAG=--public")
echo.
echo [*] 首次提交源码（约 650 MB、3.8 万个文件，可能需要几分钟）...
git add -A
git commit -m "chore: import Dylix source with FLEX MCP bridge" >nul 2>nul
gh repo view "%GH_USER%/!REPO_NAME!" >nul 2>nul
if errorlevel 1 (
  echo [*] 创建仓库 %GH_USER%/!REPO_NAME! 并推送...
  gh repo create "!REPO_NAME!" !VIS_FLAG! --source . --remote origin --push
) else (
  echo [*] 仓库已存在，添加远程并推送...
  git remote add origin "https://github.com/%GH_USER%/!REPO_NAME!.git"
  git push -u origin HEAD
)
if errorlevel 1 goto :fail
goto :after_push

:push
echo [*] 提交本地改动...
git add -A
git commit -m "build: trigger GitHub Actions" >nul 2>nul
for /f "delims=" %%i in ('git rev-parse --abbrev-ref HEAD') do set "BRANCH=%%i"
echo [*] 推送分支 %BRANCH%...
git push -u origin "%BRANCH%"
if errorlevel 1 goto :fail

:after_push
for /f "delims=" %%i in ('git rev-parse --abbrev-ref HEAD') do set "BRANCH=%%i"

set "OLD_RUN="
gh run list --workflow build-ipa.yml --limit 1 --json databaseId --jq ".[0].databaseId" > "%TEMP%\dylix_old_run.txt" 2>nul
set /p OLD_RUN=<"%TEMP%\dylix_old_run.txt" 2>nul

echo [*] 等待 GitHub 接收工作流...
set /a WAIT=0
:poll_push
gh run list --workflow build-ipa.yml --limit 1 --json databaseId --jq ".[0].databaseId" > "%TEMP%\dylix_run.txt" 2>nul
set "CURRENT="
set /p CURRENT=<"%TEMP%\dylix_run.txt" 2>nul
if defined CURRENT if not "!CURRENT!"=="!OLD_RUN!" set "RUN_ID=!CURRENT!"
if defined RUN_ID goto :watch
set /a WAIT+=1
if %WAIT% GEQ 15 goto :dispatch
timeout /t 3 >nul
goto :poll_push

:dispatch
echo [*] 推送没有触发新运行，改为手动触发...
gh workflow run build-ipa.yml --ref "%BRANCH%"
if errorlevel 1 (
  echo     工作流还未同步到 GitHub，等待 10 秒后重试...
  timeout /t 10 >nul
  gh workflow run build-ipa.yml --ref "%BRANCH%"
)
if errorlevel 1 goto :fail
set /a WAIT=0
:poll_dispatch
gh run list --workflow build-ipa.yml --limit 1 --json databaseId --jq ".[0].databaseId" > "%TEMP%\dylix_run.txt" 2>nul
set "CURRENT="
set /p CURRENT=<"%TEMP%\dylix_run.txt" 2>nul
if defined CURRENT if not "!CURRENT!"=="!OLD_RUN!" set "RUN_ID=!CURRENT!"
if defined RUN_ID goto :watch
set /a WAIT+=1
if %WAIT% GEQ 20 goto :fail
timeout /t 3 >nul
goto :poll_dispatch

:watch
echo.
echo [*] 构建运行 ID：%RUN_ID%
echo     首次构建需下载 82 MB 工具链并编译 iSH/libgit2，约 20-60 分钟。
echo     可以按 Ctrl+C 退出，构建会在 GitHub 上继续。
echo.
gh run watch %RUN_ID% --interval 10 --exit-status
if errorlevel 1 goto :build_failed

echo.
echo [*] 下载构建产物...
if exist "dist" rmdir /s /q "dist"
gh run download %RUN_ID% -D "dist"
if errorlevel 1 goto :fail
if not exist "output" mkdir "output"
del /q "output\*.ipa" >nul 2>nul
for /r "dist" %%f in (*.ipa) do copy /y "%%f" "output\" >nul
set "IPA="
for /r "output" %%f in (*.ipa) do set "IPA=%%f"
if not defined IPA (
  echo [错误] 产物中没有找到 .ipa 文件。
  goto :fail
)
echo.
echo [完成] 未签名 IPA：%IPA%
echo [提示] 可导入 TrollStore / 自签工具后安装。
start "" explorer "output"
echo.
pause
exit /b 0

:build_failed
echo.
echo [错误] 构建失败，输出失败步骤日志：
gh run view %RUN_ID% --log-failed
echo.
echo 完整日志：gh run view %RUN_ID% --log
echo 网页查看：gh run view %RUN_ID% --web
pause
exit /b 1

:no_git
echo [错误] 未找到 git。请安装 Git for Windows：https://git-scm.com/download/win
pause
exit /b 1

:no_gh
echo [错误] 未找到 GitHub CLI。
echo 安装命令：winget install --id GitHub.cli -e
pause
exit /b 1

:fail
echo.
echo [错误] 操作未完成，请根据上方提示处理后重试。
pause
exit /b 1
