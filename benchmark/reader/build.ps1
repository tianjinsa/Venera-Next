param(
    [Parameter(Mandatory=$true)][string]$Source,
    [ValidateSet('release','profile')][string]$Mode='release',
    [string]$Flutter='D:\.tool\flutter-3.41.4',
    [string]$Android='E:\Android\Sdk',
    [string]$Java='E:\Program Files\Java\jdk-21',
    [string]$Support='D:\.tool\venera-android-history-20261010',
    [string]$Rust='D:\.tool\rust-venera',
    [switch]$AnalyzeOnly
)
$ErrorActionPreference='Stop'
$sourcePath=(Resolve-Path -LiteralPath $Source).Path
if(!(Test-Path -LiteralPath (Join-Path $sourcePath 'reader-benchmark-source.json'))){throw 'Not a prepared benchmark source'}
$keyRoot=Join-Path $PSScriptRoot 'artifacts/signing'
New-Item -ItemType Directory -Path $keyRoot -Force | Out-Null
$keystore=Join-Path $keyRoot 'reader-benchmark.jks'
$properties=Join-Path $keyRoot 'key.properties'
if(!(Test-Path -LiteralPath $keystore)){
    & (Join-Path $Java 'bin/keytool.exe') -genkeypair -keystore $keystore -storepass reader-benchmark-local -keypass reader-benchmark-local -alias benchmark -keyalg RSA -keysize 2048 -validity 3650 -dname 'CN=Reader Benchmark, O=Local Test'
    if($LASTEXITCODE -ne 0){throw 'Benchmark key generation failed'}
}
@(
    ('storeFile='+$keystore.Replace('\','/'))
    'storePassword=reader-benchmark-local'
    'keyAlias=benchmark'
    'keyPassword=reader-benchmark-local'
) | Set-Content -LiteralPath $properties -Encoding utf8
$profileRoot=Join-Path $Support 'profile'
$gradleRoot=Join-Path $PSScriptRoot 'artifacts/gradle-home'
New-Item -ItemType Directory -Path $gradleRoot -Force | Out-Null
foreach($cacheName in @('caches','wrapper','native')){
    $cacheLink=Join-Path $gradleRoot $cacheName
    if(!(Test-Path -LiteralPath $cacheLink)){
        New-Item -ItemType Junction -Path $cacheLink -Target (Join-Path $Support "gradle-cache/$cacheName") | Out-Null
    }
}
# Reuse downloaded caches, but not historical user properties/init scripts that
# can silently replace application IDs. Pin the already installed NDK/CMake.
$initRoot=Join-Path $gradleRoot 'init.d'
New-Item -ItemType Directory -Path $initRoot -Force | Out-Null
@'
gradle.beforeProject { project ->
    ['com.android.application', 'com.android.library'].each { pluginId ->
        project.pluginManager.withPlugin(pluginId) {
            project.extensions.getByName('androidComponents').finalizeDsl { androidDsl ->
                androidDsl.ndkVersion = '28.0.13004108'
                androidDsl.externalNativeBuild.cmake.version = '3.22.1'
            }
        }
    }
}
'@ | Set-Content -LiteralPath (Join-Path $initRoot 'benchmark-toolchain.gradle') -Encoding utf8
$changes=@{
    JAVA_HOME=$Java
    ANDROID_HOME=$Android
    ANDROID_SDK_ROOT=$Android
    ANDROID_USER_HOME=(Join-Path $profileRoot '.android')
    GRADLE_USER_HOME=$gradleRoot
    PUB_CACHE='D:\.tool\pub-cache'
    CARGO_HOME=(Join-Path $Support 'cargo-cache')
    RUSTUP_HOME=(Join-Path $profileRoot '.rustup')
    ANDROID_BUILD_ABIS='arm64-v8a'
    ANDROID_KEY_PROPERTIES_FILE=$properties
    ANDROID_KEYSTORE_FILE=$keystore
    FLUTTER_WINDOWS='false'
    FLUTTER_SUPPRESS_ANALYTICS='true'
    DART_SUPPRESS_ANALYTICS='true'
    CI='true'
    TEMP=(Join-Path $Support 'temp')
    TMP=(Join-Path $Support 'temp')
    USERPROFILE=$profileRoot
    APPDATA=(Join-Path $profileRoot 'AppData/Roaming')
    LOCALAPPDATA=(Join-Path $profileRoot 'AppData/Local')
    PATH="$Java\bin;$Flutter\bin;$Flutter\bin\cache\dart-sdk\bin;$Rust\bin;$Android\platform-tools;$env:PATH"
}
$saved=@{}
foreach($name in $changes.Keys){$saved[$name]=[Environment]::GetEnvironmentVariable($name,'Process'); [Environment]::SetEnvironmentVariable($name,$changes[$name],'Process')}
Push-Location -LiteralPath $sourcePath
try {
    & (Join-Path $Flutter 'bin/flutter.bat') --no-version-check pub get --enforce-lockfile
    if($LASTEXITCODE -ne 0){throw 'Locked dependency resolution failed'}
    if($AnalyzeOnly){
        & (Join-Path $Flutter 'bin/cache/dart-sdk/bin/dart.exe') analyze lib/reader_benchmark.dart lib/foundation/reader_perf_probe.dart
    } else {
        $manifest=Get-Content -LiteralPath reader-benchmark-source.json -Raw | ConvertFrom-Json
        # Keep Flutter's mode-specific plugin registration. --no-pub leaves the
        # integration_test dev registrant in Release with this Flutter version.
        $buildArgs=@('--no-version-check','build','apk',"--$Mode",'--target-platform','android-arm64','--target','lib/reader_benchmark.dart','--split-per-abi')
        if($manifest.variant -eq 'next'){$buildArgs+=@('--flavor','mobile')}
        & (Join-Path $Flutter 'bin/flutter.bat') @buildArgs
    }
    $result=$LASTEXITCODE
} finally {
    Pop-Location
    foreach($name in $saved.Keys){[Environment]::SetEnvironmentVariable($name,$saved[$name],'Process')}
}
exit $result
