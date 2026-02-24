//+------------------------------------------------------------------+
//| CResourceManager.mqh - Automated Resource Lifecycle Management     |
//| Handles: indicator handles, file handles, memory allocations     |
//+------------------------------------------------------------------+
#ifndef CRESOURCE_MANAGER_MQH
#define CRESOURCE_MANAGER_MQH

//+------------------------------------------------------------------+
//| Resource Types                                                   |
//+------------------------------------------------------------------+
enum ENUM_RESOURCE_TYPE
{
   RES_INDICATOR_HANDLE = 0,   // iMA, iRSI, etc. handles
   RES_FILE_HANDLE = 1,        // FileOpen handles
   RES_DYNAMIC_ARRAY = 2,      // Dynamically allocated arrays
   RES_OBJECT_PTR = 3,         // CObject pointers
   RES_NETWORK_HANDLE = 4      // Socket/HTTP handles
};

//+------------------------------------------------------------------+
//| Resource Entry Structure                                           |
//+------------------------------------------------------------------+
struct SResourceEntry
{
   long              resource_id;      // Handle or pointer value
   ENUM_RESOURCE_TYPE type;            // Resource type
   string            owner;            // Component that allocated it
   string            description;       // Human-readable description
   datetime          alloc_time;        // When it was allocated
   int               alloc_line;        // Line number in source
   string            alloc_file;        // Source file
   
   void Set(long id, ENUM_RESOURCE_TYPE t, const string own, 
            const string desc, const string file, int line)
   {
      resource_id = id;
      type = t;
      owner = own;
      description = desc;
      alloc_time = TimeCurrent();
      alloc_line = line;
      alloc_file = file;
   }
   
   bool IsValid() { return resource_id != 0; }
   
   void Clear()
   {
      resource_id = 0;
      type = RES_INDICATOR_HANDLE;
      owner = "";
      description = "";
      alloc_time = 0;
      alloc_line = 0;
      alloc_file = "";
   }
};

//+------------------------------------------------------------------+
//| Resource Manager Class                                           |
//+------------------------------------------------------------------+
class CResourceManager
{
private:
   SResourceEntry    m_resources[];
   int               m_capacity;
   int               m_count;
   
   // Statistics
   int               m_total_allocated[5];
   int               m_total_released[5];
   int               m_leak_detected[5];
   
public:
   CResourceManager()
   {
      m_capacity = 256;
      m_count = 0;
      ArrayResize(m_resources, m_capacity);
      
      for(int i = 0; i < 5; i++)
      {
         m_total_allocated[i] = 0;
         m_total_released[i] = 0;
         m_leak_detected[i] = 0;
      }
   }
   
   ~CResourceManager()
   {
      CleanupAllResources();
   }
   
   //+------------------------------------------------------------------+
   //| Track indicator handle                                           |
   //+------------------------------------------------------------------+
   void TrackIndicator(int handle, const string owner, const string description,
                       const string file, int line)
   {
      if(handle == INVALID_HANDLE) return;
      
      int idx = FindFreeSlot();
      if(idx >= 0)
      {
         m_resources[idx].Set(handle, RES_INDICATOR_HANDLE, owner, 
                               description, file, line);
         m_total_allocated[RES_INDICATOR_HANDLE]++;
         m_count++;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Track file handle                                                |
   //+------------------------------------------------------------------+
   void TrackFile(int handle, const string owner, const string description,
                  const string file, int line)
   {
      if(handle == INVALID_HANDLE) return;
      
      int idx = FindFreeSlot();
      if(idx >= 0)
      {
         m_resources[idx].Set(handle, RES_FILE_HANDLE, owner, 
                               description, file, line);
         m_total_allocated[RES_FILE_HANDLE]++;
         m_count++;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Release indicator handle                                         |
   //+------------------------------------------------------------------+
   bool ReleaseIndicator(int handle, const string owner)
   {
      if(handle == INVALID_HANDLE) return true;
      
      int idx = FindResource(handle, RES_INDICATOR_HANDLE, owner);
      if(idx >= 0)
      {
         // Actually release the indicator
         bool released = IndicatorRelease((int)m_resources[idx].resource_id);
         
         m_resources[idx].Clear();
         m_total_released[RES_INDICATOR_HANDLE]++;
         m_count--;
         return released;
      }
      
      // Not tracked - try to release anyway
      return IndicatorRelease(handle);
   }
   
   //+------------------------------------------------------------------+
   //| Release file handle                                              |
   //+------------------------------------------------------------------+
   bool ReleaseFile(int handle, const string owner)
   {
      if(handle == INVALID_HANDLE) return true;
      
      int idx = FindResource(handle, RES_FILE_HANDLE, owner);
      if(idx >= 0)
      {
         // Actually close the file
         FileClose((int)m_resources[idx].resource_id);
         
         m_resources[idx].Clear();
         m_total_released[RES_FILE_HANDLE]++;
         m_count--;
         return true;
      }
      
      // Not tracked - try to close anyway
      FileClose(handle);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Release all resources for an owner                               |
   //+------------------------------------------------------------------+
   int ReleaseAllForOwner(const string owner)
   {
      int released = 0;
      for(int i = 0; i < m_capacity; i++)
      {
         if(m_resources[i].IsValid() && m_resources[i].owner == owner)
         {
            switch(m_resources[i].type)
            {
               case RES_INDICATOR_HANDLE:
                  IndicatorRelease((int)m_resources[i].resource_id);
                  break;
               case RES_FILE_HANDLE:
                  FileClose((int)m_resources[i].resource_id);
                  break;
            }
            
            m_total_released[m_resources[i].type]++;
            m_resources[i].Clear();
            released++;
            m_count--;
         }
      }
      return released;
   }
   
   //+------------------------------------------------------------------+
   //| Cleanup all resources (emergency cleanup)                        |
   //+------------------------------------------------------------------+
   void CleanupAllResources()
   {
      for(int i = 0; i < m_capacity; i++)
      {
         if(m_resources[i].IsValid())
         {
            switch(m_resources[i].type)
            {
               case RES_INDICATOR_HANDLE:
                  IndicatorRelease((int)m_resources[i].resource_id);
                  m_total_released[RES_INDICATOR_HANDLE]++;
                  break;
               case RES_FILE_HANDLE:
                  FileClose((int)m_resources[i].resource_id);
                  m_total_released[RES_FILE_HANDLE]++;
                  break;
            }
            
            m_resources[i].Clear();
            m_count--;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get leak report                                                  |
   //+------------------------------------------------------------------+
   string GetLeakReport()
   {
      string report = "=== Resource Leak Report ===\n";
      
      // Calculate leaks per type
      for(int type = 0; type < 5; type++)
      {
         int leaked = m_total_allocated[type] - m_total_released[type];
         if(leaked > 0)
         {
            m_leak_detected[type] = leaked;
            report += StringFormat("  %s: %d leaks detected\n", 
               TypeToString(type), leaked);
         }
      }
      
      // Show active resources
      if(m_count > 0)
      {
         report += StringFormat("\nActive Resources (%d total):\n", m_count);
         for(int i = 0; i < m_capacity; i++)
         {
            if(m_resources[i].IsValid())
            {
               report += StringFormat("  [%s] %s: %s (owner: %s, file: %s:%d)\n",
                  TypeToString(m_resources[i].type),
                  m_resources[i].resource_id,
                  m_resources[i].description,
                  m_resources[i].owner,
                  m_resources[i].alloc_file,
                  m_resources[i].alloc_line);
            }
         }
      }
      
      return report;
   }
   
   //+------------------------------------------------------------------+
   //| Get statistics                                                   |
   //+------------------------------------------------------------------+
   string GetStatistics()
   {
      string stats = "=== Resource Statistics ===\n";
      
      for(int type = 0; type < 5; type++)
      {
         if(m_total_allocated[type] > 0)
         {
            int leaked = m_total_allocated[type] - m_total_released[type];
            stats += StringFormat("%s: Alloc=%d, Rel=%d, Leaked=%d\n",
               TypeToString(type),
               m_total_allocated[type],
               m_total_released[type],
               leaked);
         }
      }
      
      stats += StringFormat("\nCurrent Active: %d\n", m_count);
      return stats;
   }
   
private:
   int FindFreeSlot()
   {
      for(int i = 0; i < m_capacity; i++)
      {
         if(!m_resources[i].IsValid())
            return i;
      }
      
      // No free slots - expand array
      int old_capacity = m_capacity;
      m_capacity += 64;
      ArrayResize(m_resources, m_capacity);
      
      return old_capacity; // Return first new slot
   }
   
   int FindResource(long id, ENUM_RESOURCE_TYPE type, const string owner)
   {
      for(int i = 0; i < m_capacity; i++)
      {
         if(m_resources[i].IsValid() &&
            m_resources[i].resource_id == id &&
            m_resources[i].type == type &&
            (owner == "" || m_resources[i].owner == owner))
         {
            return i;
         }
      }
      return -1;
   }
   
   static string TypeToString(int type)
   {
      switch(type)
      {
         case RES_INDICATOR_HANDLE: return "INDICATOR";
         case RES_FILE_HANDLE: return "FILE";
         case RES_DYNAMIC_ARRAY: return "ARRAY";
         case RES_OBJECT_PTR: return "OBJECT";
         case RES_NETWORK_HANDLE: return "NETWORK";
      }
      return "UNKNOWN";
   }
};

// Global resource manager
CResourceManager* g_resource_manager = NULL;

//+------------------------------------------------------------------+
//| Initialize resource management                                   |
//+------------------------------------------------------------------+
bool InitializeResourceManager()
{
   if(g_resource_manager != NULL)
      delete g_resource_manager;
   
   g_resource_manager = new CResourceManager();
   Print("[ResourceManager] Initialized");
   return true;
}

//+------------------------------------------------------------------+
//| Shutdown resource management                                     |
//+------------------------------------------------------------------+
void ShutdownResourceManager()
{
   if(g_resource_manager != NULL)
   {
      Print(g_resource_manager.GetStatistics());
      Print(g_resource_manager.GetLeakReport());
      
      // Cleanup any remaining resources
      g_resource_manager.CleanupAllResources();
      
      delete g_resource_manager;
      g_resource_manager = NULL;
   }
}

//+------------------------------------------------------------------+
//| Convenience macros for resource tracking                         |
//+------------------------------------------------------------------+
#define TRACK_INDICATOR(handle, desc) \
   do { if(g_resource_manager != NULL && handle != INVALID_HANDLE) \
        g_resource_manager.TrackIndicator(handle, __FILE__, desc, __FILE__, __LINE__); } while(0)

#define RELEASE_INDICATOR(handle) \
   do { if(g_resource_manager != NULL) \
        g_resource_manager.ReleaseIndicator(handle, __FILE__); \
      else if(handle != INVALID_HANDLE) IndicatorRelease(handle); } while(0)

#define TRACK_FILE(handle, desc) \
   do { if(g_resource_manager != NULL && handle != INVALID_HANDLE) \
        g_resource_manager.TrackFile(handle, __FILE__, desc, __FILE__, __LINE__); } while(0)

#define RELEASE_FILE(handle) \
   do { if(g_resource_manager != NULL) \
        g_resource_manager.ReleaseFile(handle, __FILE__); \
      else if(handle != INVALID_HANDLE) FileClose(handle); } while(0)

#define RELEASE_ALL_FOR_OWNER(owner) \
   do { if(g_resource_manager != NULL) \
        g_resource_manager.ReleaseAllForOwner(owner); } while(0)

#endif // CRESOURCE_MANAGER_MQH
