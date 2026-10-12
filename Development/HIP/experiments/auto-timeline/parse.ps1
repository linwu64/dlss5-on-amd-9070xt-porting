$ErrorActionPreference='Stop'
$tokens=$null;$errors=$null
[Management.Automation.Language.Parser]::ParseFile('D:\DLSSNR-Lab\auto-host-timing-20261012\run_gold.ps1',[ref]$tokens,[ref]$errors)|Out-Null
if($errors.Count){$errors|Format-List;throw 'AST errors'}
'AST_OK_NO_DEVICE_OPERATION'
