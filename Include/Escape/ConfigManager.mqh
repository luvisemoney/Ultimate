//+------------------------------------------------------------------+
//|                                                ConfigManager.mqh  |
//|                                          Copyright 2025, EscapeEA |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property strict

#include "SecureMemory.mqh"
#include "InputValidation.mqh"

//+------------------------------------------------------------------+
//| Configuration manager for secure handling of EA settings        |
//+------------------------------------------------------------------+
class CConfigManager {
private:
   string            m_configPath;         // Path to configuration file
   bool              m_isEncrypted;        // Whether config is encrypted
   
   // Prevent copying
   CConfigManager(const CConfigManager&);
   void operator=(const CConfigManager&);
   
   // Simple XOR encryption/decryption (replace with stronger crypto in production)
   string SimpleXOR(const string data, const string key) {
      string result = "";
      int keyLen = StringLen(key);
      if(keyLen == 0) return data;
      
      for(int i = 0; i < StringLen(data); i++) {
         result += StringFormat("%c", data[i] ^ key[i % keyLen]);
      }
      return result;
   }
   
   // Get encryption key (in production, use a more secure key management solution)
   string GetEncryptionKey() {
      // In a real implementation, derive this from a secure source
      return "YourSecureKey123!"; // Replace with secure key management
   }
   
public:
   CConfigManager() : m_isEncrypted(false) {}
   
   // Initialize configuration manager
   bool Initialize(const string configPath = "", bool useEncryption = true) {
      m_configPath = configPath;
      m_isEncrypted = useEncryption;
      
      // Validate config path if provided
      if(m_configPath != "" && !ExtInputValidator.IsValidFilePath(m_configPath)) {
         Print("Error: Invalid configuration file path");
         return false;
      }
      
      return true;
   }
   
   // Load configuration from file
   string LoadConfig() {
      if(m_configPath == "") {
         Print("Error: No configuration file path specified");
         return "";
      }
      
      // Use RAII for file handling
      CFileRAII file(m_configPath, FILE_READ|FILE_BIN);
      if(!file.IsValid()) {
         Print("Error: Failed to open config file: ", GetLastError());
         return "";
      }
      
      // Read file contents
      string content = "";
      while(!FileIsEnding(file)) {
         content += FileReadString(file);
      }
      
      // Decrypt if needed
      if(m_isEncrypted) {
         content = SimpleXOR(content, GetEncryptionKey());
      }
      
      return content;
   }
   
   // Save configuration to file
   bool SaveConfig(const string &configData) {
      if(m_configPath == "") {
         Print("Error: No configuration file path specified");
         return false;
      }
      
      // Encrypt if needed
      string dataToSave = m_isEncrypted ? SimpleXOR(configData, GetEncryptionKey()) : configData;
      
      // Use RAII for file handling
      CFileRAII file(m_configPath, FILE_WRITE|FILE_BIN);
      if(!file.IsValid()) {
         Print("Error: Failed to create config file: ", GetLastError());
         return false;
      }
      
      // Write data
      FileWriteString(file, dataToSave);
      FileFlush(file);
      
      return true;
   }
   
   // Get configuration as key-value pairs
   bool GetConfigMap(string &configMap[][2], const string &configData) {
      // Parse config data and populate the map
      // Implementation depends on your config format (JSON, INI, etc.)
      // This is a simplified example
      return false; // Not implemented in this example
   }
   
   // Clean up sensitive data
   void Clear() {
      // Securely clear any sensitive data
      SecureStringClear(m_configPath);
      m_isEncrypted = false;
   }
   
   ~CConfigManager() {
      Clear();
   }
};

// Global instance
CConfigManager ExtConfig;
