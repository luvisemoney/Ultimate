$script:socket=$null
$script:sequence=0
function Connect-Cdp([string]$Endpoint){
 $script:socket=New-Object Net.WebSockets.ClientWebSocket
 $cancel=New-Object Threading.CancellationTokenSource(15000)
 try{[void]$script:socket.ConnectAsync([uri]$Endpoint,$cancel.Token).GetAwaiter().GetResult()}finally{$cancel.Dispose()}
}
function Invoke-Cdp([string]$Method,[hashtable]$Parameters=@{}){
 $script:sequence++
 $request=@{id=$script:sequence;method=$Method;params=$Parameters}|ConvertTo-Json -Depth 20 -Compress
 $bytes=[Text.Encoding]::UTF8.GetBytes($request)
 $segment=New-Object 'ArraySegment[byte]' -ArgumentList @(,$bytes)
 $cancel=New-Object Threading.CancellationTokenSource(20000)
 try{
  [void]$script:socket.SendAsync($segment,[Net.WebSockets.WebSocketMessageType]::Text,$true,$cancel.Token).GetAwaiter().GetResult()
  do{
   $message=New-Object IO.MemoryStream
   try{
    do{
     $buffer=New-Object byte[] 65536
     $part=New-Object 'ArraySegment[byte]' -ArgumentList @(,$buffer)
     $response=$script:socket.ReceiveAsync($part,$cancel.Token).GetAwaiter().GetResult()
     if($response.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close){throw 'Browser connection closed'}
     $message.Write($buffer,0,$response.Count)
    }while(!$response.EndOfMessage)
    $result=[Text.Encoding]::UTF8.GetString($message.ToArray())|ConvertFrom-Json
   }finally{$message.Dispose()}
  }while($result.id -ne $script:sequence)
  if($result.error){throw ($result.error|ConvertTo-Json -Compress)}
  return $result.result
 }finally{$cancel.Dispose()}
}
function Disconnect-Cdp(){if($script:socket){$script:socket.Dispose();$script:socket=$null}}
Export-ModuleMember -Function Connect-Cdp,Invoke-Cdp,Disconnect-Cdp
