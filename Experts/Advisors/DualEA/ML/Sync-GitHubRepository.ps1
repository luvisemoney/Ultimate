param(
 [switch]$Push,
 [switch]$RemoveTrackedState,
 [string]$Message='Update DualEA source, dashboard and policy snapshot',
 [string]$Checkout,
 [string]$GitExecutable
)
$ErrorActionPreference='Stop'
$experts=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$mql5=Split-Path $experts
if(!$Checkout){$Checkout=Join-Path $experts '.publish\Ultimate'}
if(!$GitExecutable){
 $candidate=Get-Command git -ErrorAction SilentlyContinue
 if($candidate){$GitExecutable=$candidate.Source}else{$GitExecutable='C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\Git\cmd\git.exe'}
}
function Git([string[]]$Arguments){& $GitExecutable -C $Checkout @Arguments;if($LASTEXITCODE -ne 0){throw ('Git failed: '+($Arguments -join ' '))}}
if(!(Test-Path (Join-Path $Checkout '.git'))){throw 'Clone https://github.com/luvisemoney/Ultimate.git into the checkout first.'}
$remote=(& $GitExecutable -C $Checkout remote get-url origin)
if($remote -ne 'https://github.com/luvisemoney/Ultimate.git'){throw 'Unexpected publication remote'}
Git @('config','core.longpaths','true')
Git @('config','core.autocrlf','false')
if($Push){Git @('pull','--ff-only','origin','main')}
# Traverse only source directories. Never enter terminal state or browser profiles.
$skip=@('.git','.publish','.tools','.venv','venv','node_modules','__pycache__','runtime','browser-profile','onnxruntime','artifacts','dist','model-evidence','live-evidence','screenshots')
$code=@('.mq5','.mqh','.mq4','.mqh4')
$projectExtensions=$code+@('.ps1','.psm1','.cs','.py','.js','.mjs','.css','.html','.md','.json','.yml','.yaml','.svg','.set')
$copied=New-Object 'Collections.Generic.List[string]'
function Publish-File([string]$Source,[string]$Relative){
 $item=Get-Item -LiteralPath $Source
 if($item.Length -gt 10MB){throw ('Oversized publication file: '+$Relative)}
 if($item.Extension -notin @('.onnx','.png')){
  $content=[IO.File]::ReadAllText($Source)
  if($content -match 'gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'){throw ('Credential signature in '+$Relative)}
 }
 $destination=Join-Path $Checkout $Relative
 New-Item -ItemType Directory -Force -Path (Split-Path $destination)|Out-Null
 Copy-Item -LiteralPath $Source -Destination $destination -Force
 $copied.Add($Relative)
}
function Walk-Source([string]$Directory,[string]$Prefix){
 foreach($entry in (Get-ChildItem -LiteralPath $Directory -Force)){
  if($entry.Attributes -band [IO.FileAttributes]::ReparsePoint){continue}
  $relative=$Prefix+'/'+$entry.Name
  if($entry.PSIsContainer){if($entry.Name -notin $skip){Walk-Source $entry.FullName $relative};continue}
  $isProject=$relative -like 'Experts/Advisors/DualEA/*'
  if(($isProject -and $entry.Extension -in $projectExtensions) -or $entry.Extension -in $code){Publish-File $entry.FullName $relative}
 }
}
foreach($root in @('Experts','Include','Indicators','Scripts','Libraries','Services','Shared Projects')){
 $source=Join-Path $mql5 $root
 if(Test-Path -LiteralPath $source){Walk-Source $source $root}
}
foreach($name in @('signal_model.onnx','onnx_config.ini','onnx_config.json','model_data.json','metrics.json','verification.json')){
 $relative='Experts/Advisors/DualEA/ML/artifacts/universal/'+$name
 Publish-File (Join-Path $PSScriptRoot ('artifacts\universal\'+$name)) $relative
}
foreach($name in @('signal_model.onnx','onnx_config.ini','parity_samples.csv','forexfactory-news.tsv')){
 Publish-File (Join-Path $PSScriptRoot ('..\Tests\ModelResources\'+$name)) ('Experts/Advisors/DualEA/Tests/ModelResources/'+$name)
}
foreach($name in @('.gitignore','.gitattributes','.github/workflows/dashboard.yml')){Publish-File (Join-Path $experts $name) $name}
Publish-File (Join-Path $PSScriptRoot '..\docs\GitHubRepositoryREADME.md') 'README.md'
# Remove previously committed environments/state from the current index, without rewriting history.
$tracked=@(& $GitExecutable -C $Checkout ls-files)
$remove=@()
if($RemoveTrackedState){$remove=@($tracked|Where-Object {$_ -match '(^|/)(\.venv|venv|node_modules|runtime|browser-profile|__pycache__)/|^(Files|Profiles)/|\.(ex[45]|dll|pyd|pyc|dat|log)$'})}
for($offset=0;$offset -lt $remove.Count;$offset+=40){
 $last=[Math]::Min($offset+39,$remove.Count-1)
 & $GitExecutable -C $Checkout rm --cached --sparse --ignore-unmatch -- $remove[$offset..$last] | Out-Null
 if($LASTEXITCODE -ne 0){throw 'Index cleanup failed'}
}
for($offset=0;$offset -lt $copied.Count;$offset+=40){
 $last=[Math]::Min($offset+39,$copied.Count-1)
 Git (@('add','--')+@($copied[$offset..$last]))
}
Write-Output ('Prepared '+$copied.Count+' source files; removed '+$remove.Count+' generated/private paths from current index.')
if(!$Push){Write-Output 'Staged only. Review with git diff --cached --stat.';return}
& $GitExecutable -C $Checkout diff --cached --quiet
if($LASTEXITCODE -eq 0){Write-Output 'No changes to publish';return}
if($LASTEXITCODE -ne 1){throw 'Unable to inspect staged changes'}
if(!(& $GitExecutable -C $Checkout config user.name)){Git @('config','user.name','luvisemoney')}
if(!(& $GitExecutable -C $Checkout config user.email)){Git @('config','user.email','luvisemoney@users.noreply.github.com')}
Git @('commit','-m',$Message)
Git @('push','origin','HEAD:main')
