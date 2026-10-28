#ifndef DUALEA_RUNTIME_STORAGE_MQH
#define DUALEA_RUNTIME_STORAGE_MQH
// Historical simulations must not read or overwrite live Common Files state.
// Outside the tester the existing shared-file behavior is preserved.
#define DUALEA_FILE_COMMON (MQLInfoInteger(MQL_TESTER) ? 0 : FILE_COMMON)
#define DUALEA_DATABASE_COMMON (MQLInfoInteger(MQL_TESTER) ? 0 : DATABASE_OPEN_COMMON)
#endif
