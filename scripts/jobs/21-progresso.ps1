Get-Date -Format HH:mm:ss
Get-Content C:\ProgramData\EEEPBuild\programas.log -ErrorAction SilentlyContinue | Select-Object -Last 40
Get-Content C:\ProgramData\EEEPBuild\kit.log -ErrorAction SilentlyContinue | Select-Object -Last 25
"C: livre GB: $([math]::Round((Get-PSDrive C).Free/1GB,1))"
