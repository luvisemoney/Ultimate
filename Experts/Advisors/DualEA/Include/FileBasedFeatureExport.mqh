// FileBasedFeatureExport.mqh
// Alternative to DLL-based feature export for strategy tester compatibility

#ifndef FILE_BASED_FEATURE_EXPORT_MQH
#define FILE_BASED_FEATURE_EXPORT_MQH

#include <Files\FileBin.mqh>

class CFileBasedFeatureExport
{
private:
   string m_base_dir;
   int    m_file_counter;
   
public:
   CFileBasedFeatureExport()
   {
      m_base_dir = "";
      m_file_counter = 0;
      // Using FILE_COMMON for all writes; no directory creation needed
   }
   
   ~CFileBasedFeatureExport()
   {
   }
   
   // Export feature batch to file (replaces DLL function)
   int ExportFeatureBatch(const uchar &pb_bytes[], int pb_len, uchar &out_path[], int out_path_len)
   {
      // Validate input parameters
      if (pb_len <= 0)
      {
         return -1; // Invalid input
      }
      
      // Generate timestamped filename
      string filename = GenerateTimestampedFilename();
      string full_path = filename;
      
      // Write binary data to file
      CFileBin file;
      if (!file.Open(full_path, FILE_BIN | FILE_WRITE | FILE_COMMON))
      {
         Print("Failed to open file for writing: ", full_path);
         return -3; // Failed to open file
      }
      
      // Write the binary data using proper MQL5 method
      for(int i = 0; i < pb_len; i++)
      {
         file.WriteChar((char)pb_bytes[i]);
      }
      file.Close();
      
      // Copy the output path to the provided buffer
      int path_len = StringLen(full_path);
      if (ArraySize(out_path) > path_len)
      {
         StringToCharArray(full_path, out_path);
         out_path[path_len] = 0; // Null terminator
      }
      
      Print("Feature batch exported to: ", full_path);
      return 0; // Success
   }
   
   // Alternative method for string-based features (more common in MQL5)
   int ExportStringFeatures(const string &features[], int feature_count, string &out_path)
   {
      if (feature_count <= 0)
      {
         return -1; // Invalid input
      }
      
      // Generate timestamped filename
      string filename = GenerateTimestampedFilename();
      string full_path = filename;
      
      // Write features as text file
      int file_handle = FileOpen(full_path, FILE_WRITE | FILE_TXT | FILE_COMMON);
      if (file_handle == INVALID_HANDLE)
      {
         Print("Failed to open file for writing: ", full_path);
         return -3; // Failed to open file
      }
      
      // Write each feature on a new line
      for (int i = 0; i < feature_count; i++)
      {
         FileWriteString(file_handle, features[i]);
         FileWriteString(file_handle, "\n");
      }
      
      FileClose(file_handle);
      
      out_path = full_path;
      Print("String features exported to: ", full_path);
      return 0; // Success
   }
   
   // Get version info (replaces DLL function)
   int GetFeatureExportVersion(string &version)
   {
      version = "1.0.0 (File-Based)";
      return 0; // Success
   }
   
private:
   
   void CreateDirectoryStructure()
   {
      // No-op when using FILE_COMMON storage
   }
   
   string GenerateTimestampedFilename()
   {
      datetime now = TimeCurrent();
      MqlDateTime dt; 
      TimeToStruct(now, dt);
      m_file_counter++;
      return StringFormat("feature_batch_%04d%02d%02d_%02d%02d%02d_%03d.txt",
                          dt.year, dt.mon, dt.day,
                          dt.hour, dt.min, dt.sec,
                          m_file_counter % 1000);
   }
   
   
};

// Global instance for easy access
CFileBasedFeatureExport g_file_exporter;

#endif // FILE_BASED_FEATURE_EXPORT_MQH
