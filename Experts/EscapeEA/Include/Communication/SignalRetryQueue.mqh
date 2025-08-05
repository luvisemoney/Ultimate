//+------------------------------------------------------------------+
//| SignalRetryQueue.mqh - Robust signal delivery system for EscapeEA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Common\Constants.mqh"

// Retry queue constants
#define MAX_RETRY_ATTEMPTS 5
#define RETRY_DELAY_SECONDS 30
#define MAX_QUEUE_SIZE 1000
#define QUEUE_CLEANUP_INTERVAL 300 // 5 minutes

//+------------------------------------------------------------------+
//| Queued signal structure                                          |
//+------------------------------------------------------------------+
struct SQueuedSignal
  {
   string            signalId;          // Unique signal identifier
   STradeSignal      signal;            // The actual signal
   datetime          firstAttempt;      // First attempt timestamp
   datetime          lastAttempt;       // Last attempt timestamp
   int               attemptCount;      // Number of attempts made
   int               priority;          // Signal priority (1-10)
   string            targetEA;          // Target EA identifier
   bool              acknowledged;      // Acknowledgment received
   string            lastError;         // Last error message
   
   // Constructor
   SQueuedSignal() : firstAttempt(0), lastAttempt(0), attemptCount(0), 
                    priority(5), acknowledged(false) {}
  };

//+------------------------------------------------------------------+
//| Signal Retry Queue Class                                         |
//+------------------------------------------------------------------+
class CSignalRetryQueue
  {
private:
   SQueuedSignal     m_queue[];            // Signal queue
   string            m_queueFile;          // Persistent queue file
   datetime          m_lastCleanup;        // Last cleanup time
   int               m_successfulDeliveries; // Success counter
   int               m_failedDeliveries;   // Failure counter
   
   // Private methods
   string            GenerateSignalId();
   bool              SaveQueueToFile();
   bool              LoadQueueFromFile();
   void              CleanupExpiredSignals();
   bool              IsSignalExpired(const SQueuedSignal &queuedSignal);
   int               FindSignalIndex(const string signalId);
   void              SortQueueByPriority();
   
public:
   // Constructor/destructor
                     CSignalRetryQueue(const string queueFile = "signal_retry_queue.dat");
                    ~CSignalRetryQueue();
   
   // Queue management
   bool              EnqueueSignal(const STradeSignal &signal, const string targetEA = "", int priority = 5);
   bool              ProcessQueue();
   bool              AcknowledgeSignal(const string signalId);
   bool              RemoveSignal(const string signalId);
   
   // Queue status
   int               GetQueueSize() const { return ArraySize(m_queue); }
   int               GetPendingCount();
   int               GetSuccessRate();
   void              GetQueueStats(int &pending, int &successful, int &failed);
   
   // Maintenance
   bool              ClearQueue();
   bool              PerformMaintenance();
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSignalRetryQueue::CSignalRetryQueue(const string queueFile = "signal_retry_queue.dat") :
   m_queueFile(queueFile),
   m_lastCleanup(0),
   m_successfulDeliveries(0),
   m_failedDeliveries(0)
  {
   // Initialize queue
   ArrayResize(m_queue, 0);
   
   // Load existing queue from file
   if(!LoadQueueFromFile())
      Print("Starting with empty retry queue");
   
   Print("SignalRetryQueue initialized with ", ArraySize(m_queue), " pending signals");
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSignalRetryQueue::~CSignalRetryQueue()
  {
   // Save queue to file before destruction
   SaveQueueToFile();
   Print("SignalRetryQueue destroyed, queue saved to file");
  }

//+------------------------------------------------------------------+
//| Generate unique signal ID                                        |
//+------------------------------------------------------------------+
string CSignalRetryQueue::GenerateSignalId()
  {
   return StringFormat("SIG_%d_%d", (int)TimeCurrent(), GetTickCount());
  }

//+------------------------------------------------------------------+
//| Save queue to persistent file                                    |
//+------------------------------------------------------------------+
bool CSignalRetryQueue::SaveQueueToFile()
  {
   int handle = FileOpen(m_queueFile, FILE_WRITE|FILE_BIN|FILE_COMMON);
   if(handle == INVALID_HANDLE)
     {
      Print("Failed to open queue file for writing: ", m_queueFile);
      return false;
     }
   
   // Write queue size
   int queueSize = ArraySize(m_queue);
   FileWriteInteger(handle, queueSize);
   
   // Write each queued signal
   for(int i = 0; i < queueSize; i++)
     {
      // Write signal ID
      FileWriteString(handle, m_queue[i].signalId);
      
      // Write signal data
      FileWriteInteger(handle, (int)m_queue[i].signal.signal);
      FileWriteDouble(handle, m_queue[i].signal.confidence);
      FileWriteString(handle, m_queue[i].signal.symbol);
      FileWriteLong(handle, (long)m_queue[i].signal.timestamp);
      FileWriteDouble(handle, m_queue[i].signal.entry);
      FileWriteDouble(handle, m_queue[i].signal.stopLoss);
      FileWriteDouble(handle, m_queue[i].signal.takeProfit);
      FileWriteString(handle, m_queue[i].signal.comment);
      
      // Write queue metadata
      FileWriteLong(handle, (long)m_queue[i].firstAttempt);
      FileWriteLong(handle, (long)m_queue[i].lastAttempt);
      FileWriteInteger(handle, m_queue[i].attemptCount);
      FileWriteInteger(handle, m_queue[i].priority);
      FileWriteString(handle, m_queue[i].targetEA);
      FileWriteInteger(handle, m_queue[i].acknowledged ? 1 : 0);
      FileWriteString(handle, m_queue[i].lastError);
     }
   
   FileClose(handle);
   return true;
  }

//+------------------------------------------------------------------+
//| Load queue from persistent file                                  |
//+------------------------------------------------------------------+
bool CSignalRetryQueue::LoadQueueFromFile()
  {
   if(!FileIsExist(m_queueFile, FILE_COMMON))
      return false;
   
   int handle = FileOpen(m_queueFile, FILE_READ|FILE_BIN|FILE_COMMON);
   if(handle == INVALID_HANDLE)
     {
      Print("Failed to open queue file for reading: ", m_queueFile);
      return false;
     }
   
   // Read queue size
   int queueSize = FileReadInteger(handle);
   if(queueSize < 0 || queueSize > MAX_QUEUE_SIZE)
     {
      Print("Invalid queue size in file: ", queueSize);
      FileClose(handle);
      return false;
     }
   
   ArrayResize(m_queue, queueSize);
   
   // Read each queued signal
   for(int i = 0; i < queueSize; i++)
     {
      // Read signal ID
      m_queue[i].signalId = FileReadString(handle);
      
      // Read signal data
      m_queue[i].signal.signal = (ENUM_TRADE_SIGNAL)FileReadInteger(handle);
      m_queue[i].signal.confidence = FileReadDouble(handle);
      m_queue[i].signal.symbol = FileReadString(handle);
      m_queue[i].signal.timestamp = (datetime)FileReadLong(handle);
      m_queue[i].signal.entry = FileReadDouble(handle);
      m_queue[i].signal.stopLoss = FileReadDouble(handle);
      m_queue[i].signal.takeProfit = FileReadDouble(handle);
      m_queue[i].signal.comment = FileReadString(handle);
      
      // Read queue metadata
      m_queue[i].firstAttempt = (datetime)FileReadLong(handle);
      m_queue[i].lastAttempt = (datetime)FileReadLong(handle);
      m_queue[i].attemptCount = FileReadInteger(handle);
      m_queue[i].priority = FileReadInteger(handle);
      m_queue[i].targetEA = FileReadString(handle);
      m_queue[i].acknowledged = (FileReadInteger(handle) == 1);
      m_queue[i].lastError = FileReadString(handle);
     }
   
   FileClose(handle);
   Print("Loaded ", queueSize, " signals from retry queue file");
   return true;
  }

//+------------------------------------------------------------------+
//| Check if signal has expired                                      |
//+------------------------------------------------------------------+
bool CSignalRetryQueue::IsSignalExpired(const SQueuedSignal &queuedSignal)
  {
   datetime currentTime = TimeCurrent();
   
   // Signal expires after 1 hour or max retry attempts
   return (currentTime - queuedSignal.firstAttempt > 3600) || 
          (queuedSignal.attemptCount >= MAX_RETRY_ATTEMPTS);
  }

//+------------------------------------------------------------------+
//| Clean up expired signals                                         |
//+------------------------------------------------------------------+
void CSignalRetryQueue::CleanupExpiredSignals()
  {
   datetime currentTime = TimeCurrent();
   
   // Only cleanup every 5 minutes
   if(currentTime - m_lastCleanup < QUEUE_CLEANUP_INTERVAL)
      return;
   
   m_lastCleanup = currentTime;
   
   int originalSize = ArraySize(m_queue);
   int writeIndex = 0;
   
   // Remove expired signals
   for(int readIndex = 0; readIndex < originalSize; readIndex++)
     {
      if(!IsSignalExpired(m_queue[readIndex]))
        {
         if(writeIndex != readIndex)
            m_queue[writeIndex] = m_queue[readIndex];
         writeIndex++;
        }
      else
        {
         m_failedDeliveries++;
         Print("Removed expired signal: ", m_queue[readIndex].signalId);
        }
     }
   
   // Resize array to new size
   ArrayResize(m_queue, writeIndex);
   
   if(writeIndex < originalSize)
      Print("Cleaned up ", (originalSize - writeIndex), " expired signals");
  }

//+------------------------------------------------------------------+
//| Find signal index by ID                                          |
//+------------------------------------------------------------------+
int CSignalRetryQueue::FindSignalIndex(const string signalId)
  {
   for(int i = 0; i < ArraySize(m_queue); i++)
     {
      if(m_queue[i].signalId == signalId)
         return i;
     }
   return -1;
  }

//+------------------------------------------------------------------+
//| Sort queue by priority (highest first)                           |
//+------------------------------------------------------------------+
void CSignalRetryQueue::SortQueueByPriority()
  {
   int size = ArraySize(m_queue);
   if(size <= 1) return;
   
   // Simple bubble sort by priority
   for(int i = 0; i < size - 1; i++)
     {
      for(int j = 0; j < size - i - 1; j++)
        {
         if(m_queue[j].priority < m_queue[j + 1].priority)
           {
            SQueuedSignal temp = m_queue[j];
            m_queue[j] = m_queue[j + 1];
            m_queue[j + 1] = temp;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Enqueue a signal for delivery                                    |
//+------------------------------------------------------------------+
bool CSignalRetryQueue::EnqueueSignal(const STradeSignal &signal, const string targetEA = "", int priority = 5)
  {
   // Check queue size limit
   if(ArraySize(m_queue) >= MAX_QUEUE_SIZE)
     {
      Print("Queue is full, cannot enqueue signal");
      return false;
     }
   
   // Validate signal
   if(signal.signal == SIGNAL_HOLD || signal.confidence <= 0)
     {
      Print("Invalid signal, cannot enqueue");
      return false;
     }
   
   // Create queued signal
   SQueuedSignal queuedSignal;
   queuedSignal.signalId = GenerateSignalId();
   queuedSignal.signal = signal;
   queuedSignal.firstAttempt = TimeCurrent();
   queuedSignal.lastAttempt = 0;
   queuedSignal.attemptCount = 0;
   queuedSignal.priority = MathMax(1, MathMin(10, priority));
   queuedSignal.targetEA = targetEA;
   queuedSignal.acknowledged = false;
   
   // Add to queue
   int size = ArraySize(m_queue);
   ArrayResize(m_queue, size + 1);
   m_queue[size] = queuedSignal;
   
   // Sort by priority
   SortQueueByPriority();
   
   Print("Signal enqueued: ", queuedSignal.signalId, " (Priority: ", priority, ")");
   return true;
  }

//+------------------------------------------------------------------+
//| Process the retry queue                                          |
//+------------------------------------------------------------------+
bool CSignalRetryQueue::ProcessQueue()
  {
   // Clean up expired signals first
   CleanupExpiredSignals();
   
   datetime currentTime = TimeCurrent();
   bool processedAny = false;
   
   // Process each signal in the queue
   for(int i = 0; i < ArraySize(m_queue); i++)
     {
      SQueuedSignal &queuedSignal = m_queue[i];
      
      // Skip if already acknowledged
      if(queuedSignal.acknowledged)
         continue;
      
      // Check if enough time has passed since last attempt
      if(queuedSignal.lastAttempt > 0 && 
         (currentTime - queuedSignal.lastAttempt) < RETRY_DELAY_SECONDS)
         continue;
      
      // Skip if max attempts reached
      if(queuedSignal.attemptCount >= MAX_RETRY_ATTEMPTS)
         continue;
      
      // Attempt to send signal
      queuedSignal.lastAttempt = currentTime;
      queuedSignal.attemptCount++;
      
      // Here you would implement the actual signal sending logic
      // For now, we'll simulate it
      bool sendSuccess = true; // Replace with actual sending logic
      
      if(sendSuccess)
        {
         Print("Signal sent successfully: ", queuedSignal.signalId, 
               " (Attempt ", queuedSignal.attemptCount, ")");
         processedAny = true;
        }
      else
        {
         queuedSignal.lastError = "Send failed";
         Print("Signal send failed: ", queuedSignal.signalId, 
               " (Attempt ", queuedSignal.attemptCount, "/", MAX_RETRY_ATTEMPTS, ")");
        }
     }
   
   // Save queue state if any processing occurred
   if(processedAny)
      SaveQueueToFile();
   
   return processedAny;
  }

//+------------------------------------------------------------------+
//| Acknowledge signal delivery                                      |
//+------------------------------------------------------------------+
bool CSignalRetryQueue::AcknowledgeSignal(const string signalId)
  {
   int index = FindSignalIndex(signalId);
   if(index < 0)
     {
      Print("Signal not found for acknowledgment: ", signalId);
      return false;
     }
   
   m_queue[index].acknowledged = true;
   m_successfulDeliveries++;
   
   Print("Signal acknowledged: ", signalId);
   
   // Save updated state
   SaveQueueToFile();
   
   return true;
  }

//+------------------------------------------------------------------+
//| Remove signal from queue                                         |
//+------------------------------------------------------------------+
bool CSignalRetryQueue::RemoveSignal(const string signalId)
  {
   int index = FindSignalIndex(signalId);
   if(index < 0)
      return false;
   
   // Shift remaining elements
   int size = ArraySize(m_queue);
   for(int i = index; i < size - 1; i++)
      m_queue[i] = m_queue[i + 1];
   
   ArrayResize(m_queue, size - 1);
   
   Print("Signal removed from queue: ", signalId);
   SaveQueueToFile();
   
   return true;
  }

//+------------------------------------------------------------------+
//| Get count of pending signals                                     |
//+------------------------------------------------------------------+
int CSignalRetryQueue::GetPendingCount()
  {
   int pending = 0;
   for(int i = 0; i < ArraySize(m_queue); i++)
     {
      if(!m_queue[i].acknowledged && !IsSignalExpired(m_queue[i]))
         pending++;
     }
   return pending;
  }

//+------------------------------------------------------------------+
//| Get success rate percentage                                      |
//+------------------------------------------------------------------+
int CSignalRetryQueue::GetSuccessRate()
  {
   int total = m_successfulDeliveries + m_failedDeliveries;
   if(total == 0) return 100;
   
   return (m_successfulDeliveries * 100) / total;
  }

//+------------------------------------------------------------------+
//| Get queue statistics                                             |
//+------------------------------------------------------------------+
void CSignalRetryQueue::GetQueueStats(int &pending, int &successful, int &failed)
  {
   pending = GetPendingCount();
   successful = m_successfulDeliveries;
   failed = m_failedDeliveries;
  }

//+------------------------------------------------------------------+
//| Clear entire queue                                               |
//+------------------------------------------------------------------+
bool CSignalRetryQueue::ClearQueue()
  {
   ArrayResize(m_queue, 0);
   m_successfulDeliveries = 0;
   m_failedDeliveries = 0;
   
   SaveQueueToFile();
   Print("Signal retry queue cleared");
   
   return true;
  }

//+------------------------------------------------------------------+
//| Perform maintenance tasks                                        |
//+------------------------------------------------------------------+
bool CSignalRetryQueue::PerformMaintenance()
  {
   Print("Performing retry queue maintenance...");
   
   // Clean up expired signals
   CleanupExpiredSignals();
   
   // Sort by priority
   SortQueueByPriority();
   
   // Save current state
   SaveQueueToFile();
   
   // Log statistics
   int pending, successful, failed;
   GetQueueStats(pending, successful, failed);
   
   Print("Queue maintenance complete - Pending: ", pending, 
         ", Success rate: ", GetSuccessRate(), "%");
   
   return true;
  }