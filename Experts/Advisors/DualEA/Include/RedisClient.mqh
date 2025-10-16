//+------------------------------------------------------------------+
//| RedisClient.mqh - Socket-based Redis Protocol for MQL5          |
//| DualEA Nuclear System - No DLL Required                         |
//+------------------------------------------------------------------+
#property copyright "DualEA Nuclear"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| Redis RESP Protocol Implementation                              |
//| Implements Redis Serialization Protocol (RESP) over TCP sockets |
//+------------------------------------------------------------------+

class CRedisClient
{
private:
    int      m_socket;
    string   m_host;
    int      m_port;
    bool     m_connected;
    int      m_timeout_ms;
    
    // Response buffer
    char     m_buffer[];
    int      m_buffer_size;
    
public:
    CRedisClient(string host = "127.0.0.1", int port = 6379, int timeout_ms = 5000)
    {
        m_host = host;
        m_port = port;
        m_socket = INVALID_HANDLE;
        m_connected = false;
        m_timeout_ms = timeout_ms;
        m_buffer_size = 65536; // 64KB buffer
        ArrayResize(m_buffer, m_buffer_size);
    }
    
    ~CRedisClient()
    {
        Disconnect();
        ArrayFree(m_buffer);
    }
    
    //+------------------------------------------------------------------+
    //| Connect to Redis server                                         |
    //+------------------------------------------------------------------+
    bool Connect()
    {
        if(m_connected)
            return true;
        
        // Create TCP socket
        m_socket = SocketCreate();
        if(m_socket == INVALID_HANDLE)
        {
            Print("❌ Redis: Failed to create socket. Error: ", GetLastError());
            return false;
        }
        
        // Connect to Redis server
        if(!SocketConnect(m_socket, m_host, m_port, m_timeout_ms))
        {
            Print("❌ Redis: Connection failed to ", m_host, ":", m_port, ". Error: ", GetLastError());
            SocketClose(m_socket);
            m_socket = INVALID_HANDLE;
            return false;
        }
        
        m_connected = true;
        Print("✅ Redis: Connected to ", m_host, ":", m_port);
        
        // Test connection with PING
        string pong = Command("PING");
        if(pong != "PONG")
        {
            Print("⚠️ Redis: PING test failed. Response: ", pong);
            Disconnect();
            return false;
        }
        
        Print("✅ Redis: PING test successful");
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Disconnect from Redis                                           |
    //+------------------------------------------------------------------+
    void Disconnect()
    {
        if(m_socket != INVALID_HANDLE)
        {
            SocketClose(m_socket);
            m_socket = INVALID_HANDLE;
        }
        m_connected = false;
    }
    
    //+------------------------------------------------------------------+
    //| Check if connected                                              |
    //+------------------------------------------------------------------+
    bool IsConnected() const { return m_connected; }
    
    //+------------------------------------------------------------------+
    //| Execute Redis command (generic)                                 |
    //+------------------------------------------------------------------+
    string Command(string cmd, string arg1 = "", string arg2 = "", string arg3 = "", string arg4 = "")
    {
        if(!m_connected && !Connect())
            return "";
        
        // Build RESP array command
        string resp_cmd = BuildRESPCommand(cmd, arg1, arg2, arg3, arg4);
        
        // Send command
        if(!SendData(resp_cmd))
        {
            Print("❌ Redis: Failed to send command: ", cmd);
            Disconnect();
            return "";
        }
        
        // Receive response
        string response = ReceiveResponse();
        return response;
    }
    
    //+------------------------------------------------------------------+
    //| SET key value                                                   |
    //+------------------------------------------------------------------+
    bool Set(string key, string value)
    {
        string result = Command("SET", key, value);
        return (result == "OK");
    }
    
    //+------------------------------------------------------------------+
    //| GET key                                                         |
    //+------------------------------------------------------------------+
    string Get(string key)
    {
        return Command("GET", key);
    }
    
    //+------------------------------------------------------------------+
    //| HSET hash field value                                           |
    //+------------------------------------------------------------------+
    bool HSet(string hash, string field, string value)
    {
        string result = Command("HSET", hash, field, value);
        return (result == "1" || result == "0"); // 1=new, 0=updated
    }
    
    //+------------------------------------------------------------------+
    //| HGET hash field                                                 |
    //+------------------------------------------------------------------+
    string HGet(string hash, string field)
    {
        return Command("HGET", hash, field);
    }
    
    //+------------------------------------------------------------------+
    //| PUBLISH channel message                                         |
    //+------------------------------------------------------------------+
    int Publish(string channel, string message)
    {
        string result = Command("PUBLISH", channel, message);
        return (int)StringToInteger(result); // Returns number of subscribers
    }
    
    //+------------------------------------------------------------------+
    //| LPUSH key value (list push left)                                |
    //+------------------------------------------------------------------+
    int LPush(string key, string value)
    {
        string result = Command("LPUSH", key, value);
        return (int)StringToInteger(result);
    }
    
    //+------------------------------------------------------------------+
    //| RPUSH key value (list push right)                               |
    //+------------------------------------------------------------------+
    int RPush(string key, string value)
    {
        string result = Command("RPUSH", key, value);
        return (int)StringToInteger(result);
    }
    
    //+------------------------------------------------------------------+
    //| LPOP key (list pop left)                                        |
    //+------------------------------------------------------------------+
    string LPop(string key)
    {
        return Command("LPOP", key);
    }
    
    //+------------------------------------------------------------------+
    //| SADD key member (set add)                                       |
    //+------------------------------------------------------------------+
    int SAdd(string key, string member)
    {
        string result = Command("SADD", key, member);
        return (int)StringToInteger(result);
    }
    
    //+------------------------------------------------------------------+
    //| ZADD key score member (sorted set add)                          |
    //+------------------------------------------------------------------+
    int ZAdd(string key, double score, string member)
    {
        string result = Command("ZADD", key, DoubleToString(score, 8), member);
        return (int)StringToInteger(result);
    }
    
    //+------------------------------------------------------------------+
    //| DEL key                                                         |
    //+------------------------------------------------------------------+
    int Del(string key)
    {
        string result = Command("DEL", key);
        return (int)StringToInteger(result);
    }
    
    //+------------------------------------------------------------------+
    //| EXISTS key                                                      |
    //+------------------------------------------------------------------+
    bool Exists(string key)
    {
        string result = Command("EXISTS", key);
        return (result == "1");
    }
    
    //+------------------------------------------------------------------+
    //| EXPIRE key seconds                                              |
    //+------------------------------------------------------------------+
    bool Expire(string key, int seconds)
    {
        string result = Command("EXPIRE", key, IntegerToString(seconds));
        return (result == "1");
    }
    
private:
    //+------------------------------------------------------------------+
    //| Build RESP protocol command                                     |
    //+------------------------------------------------------------------+
    string BuildRESPCommand(string cmd, string arg1, string arg2, string arg3, string arg4)
    {
        string args[];
        int count = 1; // cmd itself
        ArrayResize(args, 5);
        args[0] = cmd;
        
        if(arg1 != "") { args[count++] = arg1; }
        if(arg2 != "") { args[count++] = arg2; }
        if(arg3 != "") { args[count++] = arg3; }
        if(arg4 != "") { args[count++] = arg4; }
        
        // Build RESP array: *<count>\r\n$<len>\r\n<data>\r\n...
        string resp = "*" + IntegerToString(count) + "\r\n";
        
        for(int i = 0; i < count; i++)
        {
            resp += "$" + IntegerToString(StringLen(args[i])) + "\r\n";
            resp += args[i] + "\r\n";
        }
        
        return resp;
    }
    
    //+------------------------------------------------------------------+
    //| Send data to socket                                             |
    //+------------------------------------------------------------------+
    bool SendData(string data)
    {
        char send_buffer[];
        int len = StringToCharArray(data, send_buffer, 0, WHOLE_ARRAY, CP_UTF8) - 1;
        
        int sent = SocketSend(m_socket, send_buffer, len);
        return (sent == len);
    }
    
    //+------------------------------------------------------------------+
    //| Receive response from socket                                    |
    //+------------------------------------------------------------------+
    string ReceiveResponse()
    {
        ArrayInitialize(m_buffer, 0);
        
        uint timeout = GetTickCount() + m_timeout_ms;
        int total_received = 0;
        
        while(GetTickCount() < timeout)
        {
            int received = SocketReceive(m_socket, m_buffer, m_buffer_size, m_timeout_ms);
            
            if(received > 0)
            {
                total_received += received;
                
                // Parse RESP response
                string response = CharArrayToString(m_buffer, 0, total_received, CP_UTF8);
                return ParseRESPResponse(response);
            }
            else if(received == 0)
            {
                // Connection closed
                Disconnect();
                return "";
            }
            
            Sleep(1);
        }
        
        Print("⚠️ Redis: Receive timeout");
        return "";
    }
    
    //+------------------------------------------------------------------+
    //| Parse RESP response                                             |
    //+------------------------------------------------------------------+
    string ParseRESPResponse(string response)
    {
        if(StringLen(response) == 0)
            return "";
        
        char first = StringGetCharacter(response, 0);
        
        // Simple String: +OK\r\n
        if(first == '+')
        {
            int end = StringFind(response, "\r\n");
            return StringSubstr(response, 1, end - 1);
        }
        
        // Error: -ERR message\r\n
        if(first == '-')
        {
            int end = StringFind(response, "\r\n");
            string error = StringSubstr(response, 1, end - 1);
            Print("❌ Redis Error: ", error);
            return "";
        }
        
        // Integer: :1000\r\n
        if(first == ':')
        {
            int end = StringFind(response, "\r\n");
            return StringSubstr(response, 1, end - 1);
        }
        
        // Bulk String: $6\r\nfoobar\r\n
        if(first == '$')
        {
            int len_end = StringFind(response, "\r\n");
            string len_str = StringSubstr(response, 1, len_end - 1);
            int len = (int)StringToInteger(len_str);
            
            if(len == -1) // Null bulk string
                return "";
            
            int data_start = len_end + 2;
            return StringSubstr(response, data_start, len);
        }
        
        // Array: *2\r\n$3\r\nfoo\r\n$3\r\nbar\r\n
        if(first == '*')
        {
            // For simplicity, return raw response for arrays
            // TODO: Implement full array parsing if needed
            return response;
        }
        
        return response;
    }
};

//+------------------------------------------------------------------+
