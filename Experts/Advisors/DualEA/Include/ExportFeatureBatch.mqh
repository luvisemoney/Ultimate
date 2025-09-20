// MQL5 integration: Export features per trade as protobuf, call DLL
#import "C:\DualEA_FeatureBatches\feature_export.dll"
int ExportFeatureBatch(const uchar &pb_bytes[], int pb_len, uchar &out_path[], int out_path_len);
#import

// Helper: Serialize features to protobuf (simplified JSON-like format for demo)
// In production, use proper protobuf serialization
void SerializeFeatureBatch(const string symbol, const string strategy, const long timestamp, const string &features[], uchar &out_bytes[], int &out_len)
  {
   // Create a simplified protobuf-like structure
   // This is a placeholder - in production you'd use proper protobuf encoding
   string json_like = StringFormat("{\"batches\":[{\"symbol\":\"%s\",\"strategy\":\"%s\",\"timestamp\":%d,\"features\":[", 
                                   symbol, strategy, timestamp);
   
   for(int i = 0; i < ArraySize(features); i++)
     {
      if(i > 0) json_like += ",";
      json_like += StringFormat("{\"feature_name\":\"%s\",\"value\":{\"text\":\"%s\"}}", 
                                StringSubstr(features[i], 0, StringFind(features[i], ":")), 
                                StringSubstr(features[i], StringFind(features[i], ":") + 1));
     }
   
   json_like += "]}]}";
   
   // Convert string to byte array
   out_len = StringToCharArray(json_like, out_bytes, 0, StringLen(json_like));
  }

void ExportTradeFeatures(const string symbol, const string strategy, const long timestamp, const string &features[])
  {
   uchar pb_bytes[4096];
   int pb_len;
   SerializeFeatureBatch(symbol, strategy, timestamp, features, pb_bytes, pb_len);
   uchar out_path[512];
   int result = ExportFeatureBatch(pb_bytes, pb_len, out_path, 512);
   if(result != 0)
     Print("ExportFeatureBatch failed: ", result);
   else
     Print("Feature batch exported to: ", CharArrayToString(out_path));
  }

// Usage (inside trade logic):
// string features[] = {"feature1:42", "feature2:hello"};
// ExportTradeFeatures(_Symbol, "MyStrategy", TimeCurrent(), features);
