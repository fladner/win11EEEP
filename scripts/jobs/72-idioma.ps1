$ErrorActionPreference = 'SilentlyContinue'
'--- idiomas instalados:'; (Get-InstalledLanguage | Select-Object LanguageId, LanguageFeatures | Out-String).Trim()
"UI do sistema (instalacao): $((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\Language').InstallLanguage)  padrao: $((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\Language').Default)"
'--- pacotes de idioma do sistema (CBS):'
dism /online /get-intl /english | Select-String 'Default system UI language|Installed language|System locale|UI language'
'--- pacotes provisionados de idioma:'
Get-AppxProvisionedPackage -Online | Where-Object DisplayName -match 'LanguageExperience' | Select-Object DisplayName, Version
