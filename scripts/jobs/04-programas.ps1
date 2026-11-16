$ErrorActionPreference = 'SilentlyContinue'
"== whoami: $(whoami)"
"== Programas (registro):"
foreach ($root in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall') {
    foreach ($k in Get-ChildItem $root) {
        $n = $k.GetValue('DisplayName'); if (-not $n) { continue }
        if ($k.GetValue('SystemComponent') -eq 1 -or $k.GetValue('ParentKeyName')) { continue }
        '{0} | {1} | {2}' -f $n, $k.GetValue('DisplayVersion'), $k.GetValue('Publisher')
    }
}
"== winget upgrade:"
winget --version
winget source update --disable-interactivity 2>&1 | Select-Object -Last 3
winget upgrade --include-unknown --accept-source-agreements --disable-interactivity 2>&1 | Where-Object { $_ -notmatch '^\s*[-\\|/]\s*$' -and $_.Trim() } | Out-String -Width 220
"== Flutter do Aluno:"; Get-Content C:\Users\Aluno\flutter\version, C:\Users\Aluno\flutter\bin\cache\flutter.version.json
"== Fusion:"; Get-ChildItem 'C:\Users\*\AppData\Local\Autodesk\webdeploy' | Select-Object FullName
"== Python:"; & 'C:\Program Files\Python311\python.exe' --version; & 'C:\ProgramData\anaconda3\python.exe' --version
"== PATH maquina:"; [Environment]::GetEnvironmentVariable('Path', 'Machine')
