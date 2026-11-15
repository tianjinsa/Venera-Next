param(
    [string]$Java='E:\Program Files\Java\jdk-21',
    [string]$Android='E:\Android\Sdk'
)
$ErrorActionPreference='Stop'
$outputRoot=Join-Path $PSScriptRoot 'artifacts/touch-driver'
$classes=Join-Path $outputRoot 'classes'
$dex=Join-Path $outputRoot 'dex'
New-Item -ItemType Directory -Path $classes,$dex -Force | Out-Null
& (Join-Path $Java 'bin/javac.exe') --release 8 -classpath (Join-Path $Android 'platforms/android-35/android.jar') -d $classes (Join-Path $PSScriptRoot 'ReaderBenchInput.java')
if($LASTEXITCODE -ne 0){throw 'Touch driver compilation failed'}
$previousJava=[Environment]::GetEnvironmentVariable('JAVA_HOME','Process')
try {
    $env:JAVA_HOME=$Java
    & (Join-Path $Android 'build-tools/36.0.0/d8.bat') --release --min-api 26 --lib (Join-Path $Android 'platforms/android-35/android.jar') --output $dex (Join-Path $classes 'ReaderBenchInput.class')
    if($LASTEXITCODE -ne 0){throw 'Touch driver dex compilation failed'}
} finally {
    [Environment]::SetEnvironmentVariable('JAVA_HOME',$previousJava,'Process')
}
Get-FileHash -LiteralPath (Join-Path $dex 'classes.dex') -Algorithm SHA256
