//+------------------------------------------------------------------+
//| FileLockManager.mqh - File locking system for EscapeEA          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "..\Common\Constants.mqh"

// Lock constants
#define LOCK_TIMEOUT_SECONDS 30
#define LOCK_RETRY_DELAY_MS 100
#define MAX_LOCK_ATTEMPTS 300

//+------------------------------------------------------------------+
//| File Lock Manager Class                                          |
//+------------------------------------------------------------------+
class CFileLockManager
  {
private:
   string            m_lockDir;           // Lock directory
   string            m_instanceId;        // Unique instance identifier
   
   // Private methods
   string            GetLockFilePath(const string filename);
   bool              CreateLockFile(const string lockPath);
   bool              IsLockExpired(const string lockPath);
   void              CleanupExpiredLocks();
   
public:
   // Constructor
                     CFileLockManager(const string lockDir = "locks");
                    ~CFileLockManager();
   
   // Lock management
   bool              AcquireLock(const string filename, int timeoutSeconds = LOCK_TIMEOUT_SECONDS);
   bool              ReleaseLock(const string filename);
   bool              IsLocked(const string filename);
   
   // Maintenance
   void              CleanupAllLocks();
   int               GetActiveLockCount();
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFileLockManager::CFileLockManager(const string lockDir = "locks") :
   m_lockDir(lockDir)
  {
   // Generate unique instance ID
   m_instanceId = StringFormat("EA_%d_%d", (int)TimeCurrent(), GetTickCount());
   
   // Ensure lock directory exists
   if(!FolderCreate(m_lockDir, FILE_COMMON))
     {
      int error = GetLastError();
      if(error != ERR_FILE_IS_DIRECTORY)
         Print("Warning: Failed to create lock directory: ", error);
     }
   
   // Cleanup expired locks on startup
   CleanupExpiredLocks();
   
   Print("FileLockManager initialized with instance ID: ", m_instanceId);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CFileLockManager::~CFileLockManager()
  {
   // Release all locks held by this instance
   CleanupAllLocks();
   Print("FileLockManager destroyed, all locks released");
  }

//+------------------------------------------------------------------+
//| Get lock file path                                               |
//+------------------------------------------------------------------+
string CFileLockManager::GetLockFilePath(const string filename)
  {
   string safeName = filename;
   StringReplace(safeName, "\\", "_");
   StringReplace(safeName, "/", "_");
   StringReplace(safeName, ":", "_");
   
   return m_lockDir + "\\" + safeName + ".lock";
  }

//+------------------------------------------------------------------+
//| Create lock file with instance information                       |
//+------------------------------------------------------------------+
bool CFileLockManager::CreateLockFile(const string lockPath)
  {
   int handle = FileOpen(lockPath, FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(handle == INVALID_HANDLE)
      return false;
   
   // Write lock information
   FileWriteString(handle, m_instanceId + "\n");
   FileWriteString(handle, IntegerToString(TimeCurrent()) + "\n");
   FileWriteString(handle, IntegerToString(GetTickCount()) + "\n");
   
   FileClose(handle);
   return true;
  }

//+------------------------------------------------------------------+
//| Check if lock file is expired                                    |
//+------------------------------------------------------------------+
bool CFileLockManager::IsLockExpired(const string lockPath)
  {
   if(!FileIsExist(lockPath, FILE_COMMON))
      return true;
   
   int handle = FileOpen(lockPath, FILE_READ|FILE_TXT|FILE_COMMON);
   if(handle == INVALID_HANDLE)
      return true;
   
   // Read lock timestamp
   string instanceId = FileReadString(handle);
   string timestampStr = FileReadString(handle);
   FileClose(handle);
   
   if(StringLen(timestampStr) == 0)
      return true;
   
   datetime lockTime = (datetime)StringToInteger(timestampStr);
   datetime currentTime = TimeCurrent();
   
   // Lock expires after timeout period
   return (currentTime - lockTime) > LOCK_TIMEOUT_SECONDS;
  }

//+------------------------------------------------------------------+
//| Clean up expired lock files                                      |
//+------------------------------------------------------------------+
void CFileLockManager::CleanupExpiredLocks()
  {
   // This is a simplified implementation
   // In a full implementation, you would scan the lock directory
   // and remove expired lock files
   Print("Cleaning up expired locks...");
  }

//+------------------------------------------------------------------+
//| Acquire exclusive lock on file                                   |
//+------------------------------------------------------------------+
bool CFileLockManager::AcquireLock(const string filename, int timeoutSeconds = LOCK_TIMEOUT_SECONDS)
  {
   string lockPath = GetLockFilePath(filename);
   datetime startTime = TimeCurrent();
   int attempts = 0;
   
   while(attempts < MAX_LOCK_ATTEMPTS)
     {
      // Check if lock exists and is not expired
      if(!FileIsExist(lockPath, FILE_COMMON) || IsLockExpired(lockPath))
        {
         // Try to create lock
         if(CreateLockFile(lockPath))
           {
            Print("Lock acquired: ", filename);
            return true;
           }
        }
      
      // Check timeout
      if((TimeCurrent() - startTime) >= timeoutSeconds)
        {
         Print("Lock acquisition timeout: ", filename);
         return false;
        }
      
      // Wait before retry
      Sleep(LOCK_RETRY_DELAY_MS);
      attempts++;
     }
   
   Print("Lock acquisition failed after ", attempts, " attempts: ", filename);
   return false;
  }

//+------------------------------------------------------------------+
//| Release lock on file                                             |
//+------------------------------------------------------------------+
bool CFileLockManager::ReleaseLock(const string filename)
  {
   string lockPath = GetLockFilePath(filename);
   
   if(!FileIsExist(lockPath, FILE_COMMON))
     {
      Print("Lock file does not exist: ", filename);
      return true; // Already released
     }
   
   // Verify we own this lock
   int handle = FileOpen(lockPath, FILE_READ|FILE_TXT|FILE_COMMON);
   if(handle == INVALID_HANDLE)
     {
      Print("Cannot read lock file: ", filename);
      return false;
     }
   
   string lockInstanceId = FileReadString(handle);
   FileClose(handle);
   
   if(lockInstanceId != m_instanceId)
     {
      Print("Cannot release lock owned by another instance: ", filename);
      return false;
     }
   
   // Delete lock file
   if(FileDelete(lockPath, FILE_COMMON))
     {
      Print("Lock released: ", filename);
      return true;
     }
   else
     {
      Print("Failed to delete lock file: ", filename, " Error: ", GetLastError());
      return false;
     }
  }

//+------------------------------------------------------------------+
//| Check if file is currently locked                                |
//+------------------------------------------------------------------+
bool CFileLockManager::IsLocked(const string filename)
  {
   string lockPath = GetLockFilePath(filename);
   return FileIsExist(lockPath, FILE_COMMON) && !IsLockExpired(lockPath);
  }

//+------------------------------------------------------------------+
//| Clean up all locks held by this instance                         |
//+------------------------------------------------------------------+
void CFileLockManager::CleanupAllLocks()
  {
   // In a full implementation, you would scan for all lock files
   // owned by this instance and remove them
   Print("Cleaning up all locks for instance: ", m_instanceId);
  }

//+------------------------------------------------------------------+
//| Get count of active locks                                        |
//+------------------------------------------------------------------+
int CFileLockManager::GetActiveLockCount()
  {
   // In a full implementation, you would count all non-expired lock files
   return 0;
  }