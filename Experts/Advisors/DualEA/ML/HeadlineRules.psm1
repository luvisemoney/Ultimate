function ConvertTo-PlainHeadline([string]$Text){
 $plain=[Net.WebUtility]::HtmlDecode(($Text -replace '<[^>]+>',' '))
 return ($plain -replace '[\r\n\t]+',' ' -replace '\s+',' ').Trim()
}
function Get-HeadlinePolicyScore([string]$Title){
 if($Title -match '(?i)\b(not|never|less|no longer)\b'){return 0.0}
 $up=$Title -match '(?i)\b(hawkish|raises? (?:the )?(?:policy |interest )?rates?|rate hikes?|tightens? monetary policy)\b'
 $down=$Title -match '(?i)\b(dovish|cuts? (?:the )?(?:policy |interest )?rates?|rate cuts?|eases? monetary policy)\b'
 if($up -and !$down){return 1.0};if($down -and !$up){return -1.0};return 0.0
}
Export-ModuleMember -Function ConvertTo-PlainHeadline,Get-HeadlinePolicyScore
