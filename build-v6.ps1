param(
  [string]$Clang = "C:\Users\lin\Documents\Codex\2026-07-25\sm-s938b-s938bxxs9cze1-adb\work\ndk-extract\android-ndk-r29\toolchains\llvm\prebuilt\windows-x86_64\bin\clang.exe"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$original = Join-Path $root "src\original"
$device = Join-Path $root "src\device"
$target = Join-Path $root "target\pa3q-S9380ZHU1AYA1"
$include = Join-Path $root "include"
$targetInclude = Join-Path $include "targets\pa3q-S9380ZHU1AYA1"
$objects = Join-Path $root "objects-rebuilt"
$artifact = Join-Path $root "artifact-rebuilt"

New-Item -ItemType Directory -Force -Path $objects, $artifact, $targetInclude | Out-Null
Copy-Item -LiteralPath (Join-Path $target "target.h") `
  -Destination (Join-Path $targetInclude "target.h") -Force

$originalFlags = @(
  "-target", "aarch64-linux-android35",
  "-fPIC", "-O2", "-g0", "-Wall", "-Wextra",
  "-Wno-unused-parameter",
  "-I$original", "-I$include", "-I$target",
  "-DTARGET_CONFIG_H=<target.h>"
)

foreach ($name in @("main", "util", "fops", "pipe", "preload_minimal", "root_compat_globals")) {
  & $Clang @originalFlags `
    -c (Join-Path $original "$name.c") `
    -o (Join-Path $objects "$name.o")
  if ($LASTEXITCODE -ne 0) {
    throw "compile failed: $name.c"
  }
}

$deviceFlags = @(
  "-target", "aarch64-linux-android35",
  "-fPIC", "-O2", "-g0", "-Wall", "-Wextra",
  "-Wno-unused-parameter",
  "-I$device", "-I$include", "-I$target",
  "-DTARGET_CONFIG_H=<target.h>"
)

& $Clang @deviceFlags -c (Join-Path $device "slide.c") `
  -o (Join-Path $objects "slide-tracefs.o")
if ($LASTEXITCODE -ne 0) {
  throw "compile failed: slide.c"
}

& $Clang @deviceFlags -c (Join-Path $device "root.c") `
  -o (Join-Path $objects "root-umh.o")
if ($LASTEXITCODE -ne 0) {
  throw "compile failed: root.c"
}

$linkArgs = @(
  "-target", "aarch64-linux-android35",
  "-shared", "-fuse-ld=lld",
  "-Wl,--no-undefined",
  "-Wl,-z,relro", "-Wl,-z,now",
  (Join-Path $objects "main.o"),
  (Join-Path $objects "util.o"),
  (Join-Path $objects "fops.o"),
  (Join-Path $objects "pipe.o"),
  (Join-Path $objects "preload_minimal.o"),
  (Join-Path $objects "root_compat_globals.o"),
  (Join-Path $objects "root-umh.o"),
  (Join-Path $objects "slide-tracefs.o"),
  "-pthread", "-ldl",
  "-o", (Join-Path $artifact "cve-2026-43499-root-original-zhu-tracefs-v6.so")
)

& $Clang @linkArgs
if ($LASTEXITCODE -ne 0) {
  throw "link failed: V6 payload"
}

& $Clang -target aarch64-linux-android35 -fPIE -pie -O2 -g0 `
  -Wall -Wextra (Join-Path $root "helper\su_daemon.c") `
  -ldl -o (Join-Path $artifact "cve-2026-43499-root")
if ($LASTEXITCODE -ne 0) {
  throw "compile failed: helper"
}

Get-ChildItem -LiteralPath $artifact -File | ForEach-Object {
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
  "$hash  $($_.Name)"
}
