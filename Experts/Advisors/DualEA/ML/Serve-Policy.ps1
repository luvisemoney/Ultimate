param(
 [string]$PolicyFile=(Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\DualEA\policy.json'),
 [ValidateRange(1024,65535)][int]$Port=8000,
 [ValidateRange(0,1440)][int]$DurationMinutes=0
)
$ErrorActionPreference='Stop'
$listener=New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback,$Port)
$listener.Start()
$started=[DateTime]::UtcNow
Write-Output ('POLICY HTTP LISTEN http://127.0.0.1:'+$Port+'; source='+$PolicyFile)
try{
 while($DurationMinutes -eq 0 -or ([DateTime]::UtcNow-$started).TotalMinutes -lt $DurationMinutes){
  if(!$listener.Pending()){Start-Sleep -Milliseconds 50;continue}
  $client=$listener.AcceptTcpClient()
  try{
   $stream=$client.GetStream();$stream.ReadTimeout=2000;$stream.WriteTimeout=2000
   $request=New-Object Text.StringBuilder
   while($request.Length -lt 8192){$byte=$stream.ReadByte();if($byte -lt 0){break};[void]$request.Append([char]$byte);if($request.ToString().EndsWith("`r`n`r`n")){break}}
   $first=$request.ToString().Split("`r`n")[0]
   $status='200 OK';$body='';$route=''
   if($request.Length -ge 8192){$status='431 Request Header Fields Too Large';$body='{"error":"headers_too_large"}'}
   elseif($first -notmatch '^GET (/[^ ]*) HTTP/1\.[01]$'){$status='405 Method Not Allowed';$body='{"error":"get_only"}'}
   else{
    $route=$Matches[1]
    if($route -notin @('/','/health','/policy.json')){$status='404 Not Found';$body='{"error":"not_found"}'}
    else{
     try{
      $info=Get-Item -LiteralPath $PolicyFile
      if($info.Length -le 1 -or $info.Length -gt 2097152){throw 'Invalid policy size'}
      $policy=[IO.File]::ReadAllText($info.FullName)
      $parsed=$policy|ConvertFrom-Json
      if(!$policy.TrimStart().StartsWith('{') -or !$parsed){throw 'Policy must be a JSON object'}
      if($route -eq '/policy.json'){$body=$policy}
      else{$body=([ordered]@{status='ready';service='DualEA.Policy';policy_bytes=$info.Length;policy_modified_utc=$info.LastWriteTimeUtc.ToString('o');uptime_seconds=[int]([DateTime]::UtcNow-$started).TotalSeconds}|ConvertTo-Json -Compress)}
     }catch{$status='503 Service Unavailable';$body='{"error":"policy_unavailable_or_invalid"}'}
    }
   }
   $bytes=[Text.Encoding]::UTF8.GetBytes($body)
   $headers=[Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $status`r`nContent-Type: application/json; charset=utf-8`r`nContent-Length: $($bytes.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n")
   $stream.Write($headers,0,$headers.Length);$stream.Write($bytes,0,$bytes.Length);$stream.Flush()
   Write-Output ([DateTime]::UtcNow.ToString('o')+' GET '+$route+' '+$status+' bytes='+$bytes.Length)
  }catch{Write-Warning ('Request failed: '+$_.Exception.Message)}
  finally{$client.Close()}
 }
}finally{$listener.Stop();Write-Output 'POLICY HTTP STOPPED'}
