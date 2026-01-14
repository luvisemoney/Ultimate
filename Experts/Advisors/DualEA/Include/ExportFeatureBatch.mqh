// MQL5 integration: Export features per trade using file-based system
// This version works in strategy tester where DLL loading is disabled
#include "FileBasedFeatureExport.mqh"

// Helper: Serialize features to protobuf-compatible binary format
// Implements proper binary serialization with field tags and wire types
void SerializeFeatureBatch(const string symbol, const string strategy, const long timestamp, const string &features[], uchar &out_bytes[], int &out_len)
  {
   // Initialize output buffer
   ArrayResize(out_bytes, 0);
   out_len = 0;
   
   // Protobuf wire format implementation
   // Field 1: symbol (string, tag=1, wire_type=2)
   WriteProtobufString(out_bytes, out_len, 1, symbol);
   
   // Field 2: strategy (string, tag=2, wire_type=2)
   WriteProtobufString(out_bytes, out_len, 2, strategy);
   
   // Field 3: timestamp (int64, tag=3, wire_type=0)
   WriteProtobufVarint(out_bytes, out_len, 3, timestamp);
   
   // Field 4: feature_count (int32, tag=4, wire_type=0)
   WriteProtobufVarint(out_bytes, out_len, 4, ArraySize(features));
   
   // Field 5: features (repeated message, tag=5, wire_type=2)
   for(int i = 0; i < ArraySize(features); i++)
     {
      // Parse feature string "name:value"
      int colon_pos = StringFind(features[i], ":");
      string feature_name = (colon_pos >= 0) ? StringSubstr(features[i], 0, colon_pos) : features[i];
      string feature_value = (colon_pos >= 0) ? StringSubstr(features[i], colon_pos + 1) : "";
      
      // Serialize feature as embedded message
      uchar feature_bytes[];
      int feature_len = 0;
      
      // Feature name (tag=1, wire_type=2)
      WriteProtobufString(feature_bytes, feature_len, 1, feature_name);
      
      // Feature value (tag=2, wire_type=2)
      WriteProtobufString(feature_bytes, feature_len, 2, feature_value);
      
      // Feature type detection and encoding
      double numeric_value = StringToDouble(feature_value);
      if(MathIsValidNumber(numeric_value) && StringFind(feature_value, ".") >= 0)
        {
         // Double value (tag=3, wire_type=1)
         WriteProtobufDouble(feature_bytes, feature_len, 3, numeric_value);
        }
      else if(StringIsDigit(feature_value))
        {
         // Integer value (tag=4, wire_type=0)
         WriteProtobufVarint(feature_bytes, feature_len, 4, (long)StringToInteger(feature_value));
        }
      
      // Write feature as length-delimited field
      WriteProtobufBytes(out_bytes, out_len, 5, feature_bytes, feature_len);
     }
   
   // Add checksum for data integrity (tag=6, wire_type=0)
   uint checksum = CalculateChecksum(out_bytes, out_len);
   WriteProtobufVarint(out_bytes, out_len, 6, checksum);
  }

// Protobuf helper functions
void WriteProtobufVarint(uchar &buffer[], int &len, int tag, long value)
  {
   // Write field tag and wire type
   WriteVarint(buffer, len, (tag << 3) | 0); // wire_type=0 for varint
   // Write value
   WriteVarint(buffer, len, value);
  }

void WriteProtobufString(uchar &buffer[], int &len, int tag, const string value)
  {
   // Write field tag and wire type
   WriteVarint(buffer, len, (tag << 3) | 2); // wire_type=2 for length-delimited
   
   // Convert string to UTF-8 bytes
   uchar str_bytes[];
   int str_len = StringToCharArray(value, str_bytes, 0, StringLen(value), CP_UTF8);
   
   // Write length
   WriteVarint(buffer, len, str_len);
   
   // Write string bytes
   for(int i = 0; i < str_len; i++)
     {
      ArrayResize(buffer, len + 1);
      buffer[len] = str_bytes[i];
      len++;
     }
  }

void WriteProtobufDouble(uchar &buffer[], int &len, int tag, double value)
  {
   // Write field tag and wire type
   WriteVarint(buffer, len, (tag << 3) | 1); // wire_type=1 for fixed64
   
   // Convert double to 8 bytes (little-endian)
   union DoubleBytes { double d; uchar bytes[8]; } converter;
   converter.d = value;
   
   for(int i = 0; i < 8; i++)
     {
      ArrayResize(buffer, len + 1);
      buffer[len] = converter.bytes[i];
      len++;
     }
  }

void WriteProtobufBytes(uchar &buffer[], int &len, int tag, const uchar &data[], int data_len)
  {
   // Write field tag and wire type
   WriteVarint(buffer, len, (tag << 3) | 2); // wire_type=2 for length-delimited
   
   // Write length
   WriteVarint(buffer, len, data_len);
   
   // Write data bytes
   for(int i = 0; i < data_len; i++)
     {
      ArrayResize(buffer, len + 1);
      buffer[len] = data[i];
      len++;
     }
  }

void WriteVarint(uchar &buffer[], int &len, long value)
  {
   while(value >= 0x80)
     {
      ArrayResize(buffer, len + 1);
      buffer[len] = (uchar)((value & 0x7F) | 0x80);
      len++;
      value >>= 7;
     }
   ArrayResize(buffer, len + 1);
   buffer[len] = (uchar)(value & 0x7F);
   len++;
  }

uint CalculateChecksum(const uchar &data[], int data_len)
  {
   uint checksum = 0;
   for(int i = 0; i < data_len; i++)
     {
      checksum = ((checksum << 1) | (checksum >> 31)) ^ data[i];
     }
   return checksum;
  }

bool StringIsDigit(const string str)
  {
   if(StringLen(str) == 0) return false;
   for(int i = 0; i < StringLen(str); i++)
     {
      ushort ch = StringGetCharacter(str, i);
      if(ch < '0' || ch > '9') return false;
     }
   return true;
  }

void ExportTradeFeatures(const string symbol, const string strategy, const long timestamp, const string &features[])
  {
   // Use file-based export instead of DLL for strategy tester compatibility
   string out_path;
   int result = g_file_exporter.ExportStringFeatures(features, ArraySize(features), out_path);
   if(result != 0)
     Print("ExportStringFeatures failed: ", result);
   else
     Print("Feature batch exported to: ", out_path);
  }

// Usage (inside trade logic):
// string features[] = {"feature1:42", "feature2:hello"};
// ExportTradeFeatures(_Symbol, "MyStrategy", TimeCurrent(), features);
