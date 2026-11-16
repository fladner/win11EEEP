# Executa o Teste-Aluno.ps1 com a identidade do usuario Aluno (tarefa agendada S4U) e devolve o relatorio.
$ErrorActionPreference = 'Continue'
Copy-Item D:\guest\Teste-Aluno.ps1 C:\Users\Public\Teste-Aluno.ps1 -Force
Remove-Item C:\Users\Public\teste-aluno.txt -Force -ErrorAction SilentlyContinue
$a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\Users\Public\Teste-Aluno.ps1'
$pr = New-ScheduledTaskPrincipal -UserId "$env:COMPUTERNAME\Aluno" -LogonType S4U -RunLevel Limited
try { Register-ScheduledTask -TaskName 'EEEP-TesteAluno' -Action $a -Principal $pr -Force -ErrorAction Stop | Out-Null } catch { "registro da tarefa falhou: $($_.Exception.Message)" }
Start-ScheduledTask -TaskName 'EEEP-TesteAluno'
for ($i = 0; $i -lt 90; $i++) { Start-Sleep 4; if ((Test-Path C:\Users\Public\teste-aluno.txt) -and (Select-String -Path C:\Users\Public\teste-aluno.txt -Pattern '^FIM$' -Quiet)) { break } }
$info = Get-ScheduledTaskInfo -TaskName 'EEEP-TesteAluno'
"tarefa: ultimo resultado=0x$('{0:X}' -f $info.LastTaskResult)"
Get-Content C:\Users\Public\teste-aluno.txt -ErrorAction SilentlyContinue | ForEach-Object { if ($_.Length -gt 230) { $_.Substring(0, 230) } else { $_ } }
Unregister-ScheduledTask -TaskName 'EEEP-TesteAluno' -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item C:\Users\Public\Teste-Aluno.ps1, C:\Users\Public\teste-aluno.txt -Force -ErrorAction SilentlyContinue
# o teste nao deve deixar o direito de logon em lote nem perfil alterado: nada alem disso e criado
