$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue'
$out='D:\給網友打包';$history="$out\history\0.44-before-f9-20261018";$expected=@{'Magpie-DLSS5-AMD'='57e6bd49d0becffe0929f5a5e5c7e1e64deacbec5fa20f9a7c3082715df23cf9';'OptiScaler-DLSS5-AMD'='452538281833634a71b530423ef440436e7644aca8f821ec91ecf9d09f8939e7';'OptiScaler-REFramework-DLSS5-AMD'='e501bbd3323b8fadea1819c301e1843a672a57d2a4f88548015e98eaef1316cd'}
if(Test-Path $history){throw 'history exists; inspect before retry'}
foreach($n in $expected.Keys){if((Get-FileHash "$out\$n-0.44.zip").Hash -ne $expected[$n]){throw "previous package changed $n"}}
New-Item -ItemType Directory -Force $history|Out-Null
foreach($n in $expected.Keys){foreach($tail in '', '.zip', '.zip.sha256'){$p="$out\$n-0.44$tail";if(Test-Path $p){Move-Item -LiteralPath $p -Destination $history}};if((Get-FileHash "$history\$n-0.44.zip").Hash -ne $expected[$n]){throw "archive readback $n"}}
'PREVIOUS_044_ARCHIVED_WITH_HASHES'
