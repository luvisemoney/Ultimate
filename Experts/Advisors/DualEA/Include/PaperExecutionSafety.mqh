#ifndef DUALEA_PAPER_EXECUTION_SAFETY_MQH
#define DUALEA_PAPER_EXECUTION_SAFETY_MQH

// Pure predicate shared by the entry-point and executable regression tests.
bool PaperAccountAllowed(const bool tester, const long account_mode)
{
   return tester || account_mode == ACCOUNT_TRADE_MODE_DEMO;
}

bool PaperExecutionAllowed(const bool tester, const long account_mode,
                           const bool enabled, const bool shadow)
{
   return PaperAccountAllowed(tester, account_mode) && enabled && !shadow;
}
#endif
