param(
    [Parameter(Mandatory=$true)][string]$InputDirectory,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference='Stop'
$culture=[Globalization.CultureInfo]::InvariantCulture
$inputRoot=(Resolve-Path -LiteralPath $InputDirectory).Path
$modelPath=Join-Path $inputRoot 'model_data.json'
$model=Get-Content -LiteralPath $modelPath -Raw | ConvertFrom-Json
if($model.schema -ne 'market_universal_v1') {throw 'Unsupported feature contract; expected market_universal_v1'}
$featureCount=@($model.feature_names).Count
$symbolCount=@($model.supported_symbols).Count
if($symbolCount -lt 2 -or $featureCount -ne (12+4*$symbolCount)) {throw 'Universal feature/symbol dimensions are inconsistent'}
foreach($field in @('weights','scaler_mean','scaler_scale')) {
    if(@($model.$field).Count -ne $featureCount) {throw "$field dimension mismatch"}
    foreach($number in $model.$field) {
        if([double]::IsNaN([double]$number) -or [double]::IsInfinity([double]$number)) {throw "Nonfinite value in $field"}
    }
}
if([double]::IsNaN([double]$model.intercept) -or [double]::IsInfinity([double]$model.intercept)) {throw 'Nonfinite intercept'}
foreach($scale in $model.scaler_scale) {if([double]$scale -le 0) {throw 'Nonpositive scaler scale'}}
if([int]$model.timeframe -ne 16385 -or [int]$model.horizon_bars -ne 4) {throw 'Unexpected timeframe or target horizon'}
$names=@{}
foreach($name in $model.feature_names) {if(!$name -or $names.ContainsKey([string]$name)) {throw 'Empty or duplicate feature name'}; $names[[string]$name]=$true}

# Minimal ONNX protobuf encoding uses only stable standard operators. No Python,
# pickle, converter, custom operator, ZipMap, or fabricated model is involved.
function Encode-Varint([UInt64]$Value) {
    $bytes=New-Object 'Collections.Generic.List[byte]'
    while($Value -ge 128) {$bytes.Add([byte](($Value -band 127) -bor 128));$Value=$Value -shr 7}
    $bytes.Add([byte]$Value)
    return ,$bytes.ToArray()
}
function Join-Bytes([object[]]$Parts) {
    $bytes=New-Object 'Collections.Generic.List[byte]'
    foreach($part in $Parts) {$bytes.AddRange([byte[]]$part)}
    return ,$bytes.ToArray()
}
function Proto-VarintField([int]$Field,[UInt64]$Value) {
    return ,(Join-Bytes @((Encode-Varint ([UInt64]($Field -shl 3))),(Encode-Varint $Value)))
}
function Proto-BytesField([int]$Field,[byte[]]$Bytes) {
    return ,(Join-Bytes @((Encode-Varint ([UInt64](($Field -shl 3) -bor 2))),(Encode-Varint ([UInt64]$Bytes.Length)),$Bytes))
}
function Proto-StringField([int]$Field,[string]$Value) {
    return ,(Proto-BytesField $Field ([Text.Encoding]::UTF8.GetBytes($Value)))
}
function Float-Bytes([object[]]$Values) {
    $bytes=New-Object 'Collections.Generic.List[byte]'
    foreach($value in $Values) {
        $single=[single][double]$value
        if([single]::IsNaN($single) -or [single]::IsInfinity($single)) {throw 'Trained coefficient overflows float32'}
        $raw=[BitConverter]::GetBytes($single)
        if(![BitConverter]::IsLittleEndian) {[Array]::Reverse($raw)}
        $bytes.AddRange($raw)
    }
    return ,$bytes.ToArray()
}
function New-Tensor([string]$Name,[long[]]$Dimensions,[object[]]$Values) {
    $parts=New-Object 'Collections.Generic.List[object]'
    foreach($dimension in $Dimensions) {$parts.Add((Proto-VarintField 1 ([UInt64]$dimension)))}
    $parts.Add((Proto-VarintField 2 1)) # TensorProto.FLOAT
    $parts.Add((Proto-StringField 8 $Name))
    $parts.Add((Proto-BytesField 9 (Float-Bytes $Values)))
    return ,(Join-Bytes $parts.ToArray())
}
function New-ValueInfo([string]$Name,[long[]]$Dimensions) {
    $dims=New-Object 'Collections.Generic.List[object]'
    foreach($dimension in $Dimensions) {$dims.Add((Proto-BytesField 1 (Proto-VarintField 1 ([UInt64]$dimension))))}
    $shape=Join-Bytes $dims.ToArray()
    $tensor=Join-Bytes @((Proto-VarintField 1 1),(Proto-BytesField 2 $shape))
    $type=Proto-BytesField 1 $tensor
    return ,(Join-Bytes @((Proto-StringField 1 $Name),(Proto-BytesField 2 $type)))
}
function New-Node([string]$Operation,[string[]]$Inputs,[string]$Output) {
    $parts=New-Object 'Collections.Generic.List[object]'
    foreach($name in $Inputs) {$parts.Add((Proto-StringField 1 $name))}
    $parts.Add((Proto-StringField 2 $Output))
    $parts.Add((Proto-StringField 4 $Operation))
    return ,(Join-Bytes $parts.ToArray())
}
$graph=Join-Bytes @(
    (Proto-BytesField 1 (New-Node 'MatMul' @('model_input','weights') 'linear')),
    (Proto-BytesField 1 (New-Node 'Add' @('linear','bias') 'logit')),
    (Proto-BytesField 1 (New-Node 'Sigmoid' @('logit') 'probability')),
    (Proto-StringField 2 'DualEA_universal_H1_logistic'),
    (Proto-BytesField 5 (New-Tensor 'weights' @($featureCount,1) @($model.weights))),
    (Proto-BytesField 5 (New-Tensor 'bias' @(1) @($model.intercept))),
    (Proto-BytesField 11 (New-ValueInfo 'model_input' @(1,$featureCount))),
    (Proto-BytesField 12 (New-ValueInfo 'probability' @(1,1)))
)
$onnx=Join-Bytes @(
    (Proto-VarintField 1 8), # IR_VERSION 8
    (Proto-StringField 2 'DualEA deterministic real-history logistic trainer'),
    (Proto-StringField 3 '1'),
    (Proto-BytesField 7 $graph),
    (Proto-BytesField 8 (Proto-VarintField 2 13)) # default domain, opset 13
)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$outputRoot=(Resolve-Path -LiteralPath $OutputDirectory).Path
$destination=Join-Path $outputRoot 'signal_model.onnx'
[IO.File]::WriteAllBytes($destination,$onnx)
function Format-Numbers([object[]]$Values) {
    return (($Values | ForEach-Object {([double]$_).ToString('G17',$culture)}) -join '|')
}
$ini=@(
    'version=1',
    'feature_contract=market_universal_v1',
    'trained_symbol=*',
    ('supported_symbols='+($model.supported_symbols -join '|')),
    ('trained_timeframe='+$model.timeframe),
    ('prediction_horizon_bars='+$model.horizon_bars),
    ('training_start='+$model.training_start),
    ('training_end='+$model.training_end),
    ('validation_end='+$model.validation_end),
    ('test_end='+$model.test_end),
    ('feature_count='+$featureCount),
    ('feature_names='+($model.feature_names -join '|')),
    ('scaler_mean='+(Format-Numbers @($model.scaler_mean))),
    ('scaler_scale='+(Format-Numbers @($model.scaler_scale))),
    'input_name=model_input',
    'output_name=probability',
    'label_mode=future_side_aware_return'
) -join "`n"
[IO.File]::WriteAllText((Join-Path $outputRoot 'onnx_config.ini'),$ini,(New-Object Text.UTF8Encoding($false)))
$hash=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
$metadata=[ordered]@{
    version=1;feature_contract=$model.schema;trained_symbol='*';supported_symbols=$model.supported_symbols
    rejected_symbols=$model.rejected_symbols;trained_timeframe=$model.timeframe;prediction_horizon_bars=$model.horizon_bars
    training_start=$model.training_start;training_end=$model.training_end;validation_end=$model.validation_end;test_end=$model.test_end
    target=$model.target;commission=$model.commission;slippage=$model.slippage
    features=$model.feature_names;scaler=@{mean=$model.scaler_mean;scale=$model.scaler_scale}
    onnx_model=@{file='signal_model.onnx';sha256=$hash;input_name='model_input';output_name='probability';ir_version=8;opset=13;feature_count=$featureCount}
    learner=@{type='L2 logistic regression';epochs=$model.epochs;learning_rate=$model.learning_rate;l2=$model.l2;decision_stride_bars=$model.decision_stride_bars}
}
[IO.File]::WriteAllText((Join-Path $outputRoot 'onnx_config.json'),($metadata | ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
foreach($file in @('model_data.json','metrics.json','parity_samples.csv')) {
    $source=Join-Path $inputRoot $file
    $target=Join-Path $outputRoot $file
    if(![string]::Equals($source,$target,[StringComparison]::OrdinalIgnoreCase)) {
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}
$manifest=New-Object 'Collections.Generic.List[object]'
foreach($file in @('signal_model.onnx','onnx_config.ini','onnx_config.json','model_data.json','metrics.json','parity_samples.csv')) {
    $path=Join-Path $outputRoot $file
    $manifest.Add([ordered]@{file=$file;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant();bytes=(Get-Item -LiteralPath $path).Length})
}
$datasetPath=Join-Path $inputRoot 'dataset.csv'
if(Test-Path -LiteralPath $datasetPath) {$manifest.Add([ordered]@{file='source/dataset.csv';sha256=(Get-FileHash -LiteralPath $datasetPath -Algorithm SHA256).Hash.ToLowerInvariant();bytes=(Get-Item -LiteralPath $datasetPath).Length;included_in_bundle=$false})}
[IO.File]::WriteAllText((Join-Path $outputRoot 'manifest.json'),($manifest.ToArray() | ConvertTo-Json -Depth 6),(New-Object Text.UTF8Encoding($false)))
Write-Output ('Exported supplied universal logistic coefficients: symbols='+$symbolCount+' features='+$featureCount+' bytes='+$onnx.Length+' SHA256='+$hash)
Write-Output 'Export is not a profitability certification; inspect held-out metrics and validate native MT5 parity before deployment.'
