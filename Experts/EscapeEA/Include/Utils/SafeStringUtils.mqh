//+------------------------------------------------------------------+
//| SafeStringUtils.mqh - INSTITUTIONAL GRADE STRING HANDLING       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA - JAILBREAK HARDENED"
#property link      "https://www.escapeea.com"
#property version   "3.00"

//+------------------------------------------------------------------+
//| SAFE STRING CONVERSION UTILITIES                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Safe string to double conversion with bounds checking           |
//+------------------------------------------------------------------+
double SafeStringToDouble(const string str, double minValue = -DBL_MAX, double maxValue = DBL_MAX, double defaultValue = 0.0)
{
   // Validate input string
   if(StringLen(str) == 0)
   {
      Print("SAFE_CONVERT: Empty string, returning default: ", defaultValue);
      return defaultValue;
   }
   
   // Check string length (prevent extremely long strings)
   if(StringLen(str) > 50)
   {
      Print("SAFE_CONVERT: String too long (", StringLen(str), " chars), returning default");
      return defaultValue;
   }
   
   // Validate string format
   if(!IsValidNumberString(str))
   {
      Print("SAFE_CONVERT: Invalid number format: '", str, "', returning default");
      return defaultValue;
   }
   
   // Perform conversion
   double value = StringToDouble(str);
   
   // Check for conversion errors (NaN, infinity)
   if(!MathIsValidNumber(value))
   {
      Print("SAFE_CONVERT: Invalid number result from '", str, "', returning default");
      return defaultValue;
   }
   
   // Apply bounds checking
   if(value < minValue)
   {
      Print("SAFE_CONVERT: Value ", value, " below minimum ", minValue, ", clamping");
      return minValue;
   }
   
   if(value > maxValue)
   {
      Print("SAFE_CONVERT: Value ", value, " above maximum ", maxValue, ", clamping");
      return maxValue;
   }
   
   return value;
}

//+------------------------------------------------------------------+
//| Safe string to integer conversion with bounds checking          |
//+------------------------------------------------------------------+
int SafeStringToInteger(const string str, int minValue = INT_MIN, int maxValue = INT_MAX, int defaultValue = 0)
{
   // Validate input string
   if(StringLen(str) == 0)
   {
      Print("SAFE_CONVERT: Empty string, returning default: ", defaultValue);
      return defaultValue;
   }
   
   // Check string length
   if(StringLen(str) > 20)
   {
      Print("SAFE_CONVERT: String too long for integer conversion");
      return defaultValue;
   }
   
   // Validate string format (integers only)
   if(!IsValidIntegerString(str))
   {
      Print("SAFE_CONVERT: Invalid integer format: '", str, "'");
      return defaultValue;
   }
   
   // Perform conversion
   long longValue = StringToInteger(str);
   
   // Check for overflow
   if(longValue > INT_MAX || longValue < INT_MIN)
   {
      Print("SAFE_CONVERT: Integer overflow from '", str, "'");
      return defaultValue;
   }
   
   int value = (int)longValue;
   
   // Apply bounds checking
   if(value < minValue)
   {
      Print("SAFE_CONVERT: Value ", value, " below minimum ", minValue, ", clamping");
      return minValue;
   }
   
   if(value > maxValue)
   {
      Print("SAFE_CONVERT: Value ", value, " above maximum ", maxValue, ", clamping");
      return maxValue;
   }
   
   return value;
}

//+------------------------------------------------------------------+
//| Validate if string represents a valid number                    |
//+------------------------------------------------------------------+
bool IsValidNumberString(const string str)
{
   if(StringLen(str) == 0)
      return false;
      
   bool hasDecimal = false;
   bool hasSign = false;
   bool hasDigit = false;
   
   for(int i = 0; i < StringLen(str); i++)
   {
      ushort ch = StringGetCharacter(str, i);
      
      if(ch >= '0' && ch <= '9')
      {
         hasDigit = true;
      }
      else if(ch == '.')
      {
         if(hasDecimal) // Multiple decimal points
            return false;
         hasDecimal = true;
      }
      else if(ch == '-' || ch == '+')
      {
         if(i != 0 || hasSign) // Sign not at start or multiple signs
            return false;
         hasSign = true;
      }
      else
      {
         return false; // Invalid character
      }
   }
   
   return hasDigit; // Must have at least one digit
}

//+------------------------------------------------------------------+
//| Validate if string represents a valid integer                   |
//+------------------------------------------------------------------+
bool IsValidIntegerString(const string str)
{
   if(StringLen(str) == 0)
      return false;
      
   bool hasSign = false;
   bool hasDigit = false;
   
   for(int i = 0; i < StringLen(str); i++)
   {
      ushort ch = StringGetCharacter(str, i);
      
      if(ch >= '0' && ch <= '9')
      {
         hasDigit = true;
      }
      else if(ch == '-' || ch == '+')
      {
         if(i != 0 || hasSign) // Sign not at start or multiple signs
            return false;
         hasSign = true;
      }
      else
      {
         return false; // Invalid character (including decimal point)
      }
   }
   
   return hasDigit; // Must have at least one digit
}

//+------------------------------------------------------------------+
//| Safe string sanitization for file operations                    |
//+------------------------------------------------------------------+
string SanitizeFilename(const string filename)
{
   if(StringLen(filename) == 0)
      return "default.log";
      
   string sanitized = filename;
   
   // Remove dangerous characters
   StringReplace(sanitized, "..", "");     // Directory traversal
   StringReplace(sanitized, "/", "");      // Path separators
   StringReplace(sanitized, "\\", "");     // Path separators
   StringReplace(sanitized, ":", "");      // Drive separators
   StringReplace(sanitized, "*", "");      // Wildcards
   StringReplace(sanitized, "?", "");      // Wildcards
   StringReplace(sanitized, "<", "");      // Redirection
   StringReplace(sanitized, ">", "");      // Redirection
   StringReplace(sanitized, "|", "");      // Pipes
   StringReplace(sanitized, "\"", "");     // Quotes
   
   // Limit length
   if(StringLen(sanitized) > 100)
      sanitized = StringSubstr(sanitized, 0, 100);
      
   // Ensure not empty after sanitization
   if(StringLen(sanitized) == 0)
      sanitized = "sanitized.log";
      
   return sanitized;
}

//+------------------------------------------------------------------+
//| Safe string truncation with ellipsis                            |
//+------------------------------------------------------------------+
string SafeTruncateString(const string str, int maxLength = 100)
{
   if(StringLen(str) <= maxLength)
      return str;
      
   if(maxLength <= 3)
      return StringSubstr(str, 0, maxLength);
      
   return StringSubstr(str, 0, maxLength - 3) + "...";
}

//+------------------------------------------------------------------+
//| Validate string against whitelist pattern                       |
//+------------------------------------------------------------------+
bool IsValidStringPattern(const string str, const string pattern)
{
   // Simple pattern matching for common cases
   if(pattern == "SYMBOL")
   {
      // Valid trading symbol: 3-10 uppercase letters/numbers
      if(StringLen(str) < 3 || StringLen(str) > 10)
         return false;
         
      for(int i = 0; i < StringLen(str); i++)
      {
         ushort ch = StringGetCharacter(str, i);
         if(!((ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9')))
            return false;
      }
      return true;
   }
   else if(pattern == "FILENAME")
   {
      // Valid filename: alphanumeric, dots, underscores, hyphens
      if(StringLen(str) == 0 || StringLen(str) > 100)
         return false;
         
      for(int i = 0; i < StringLen(str); i++)
      {
         ushort ch = StringGetCharacter(str, i);
         if(!((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || 
              (ch >= '0' && ch <= '9') || ch == '.' || ch == '_' || ch == '-'))
            return false;
      }
      return true;
   }
   
   return false; // Unknown pattern
}

//+------------------------------------------------------------------+
//| Safe JSON value extraction                                      |
//+------------------------------------------------------------------+
string SafeExtractJSONValue(const string json, const string key, const string defaultValue = "")
{
   if(StringLen(json) == 0 || StringLen(key) == 0)
      return defaultValue;
      
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey);
   
   if(keyPos < 0)
      return defaultValue;
      
   int valueStart = keyPos + StringLen(searchKey);
   
   // Skip whitespace
   while(valueStart < StringLen(json) && 
         (StringGetCharacter(json, valueStart) == ' ' || 
          StringGetCharacter(json, valueStart) == '\t'))
   {
      valueStart++;
   }
   
   if(valueStart >= StringLen(json))
      return defaultValue;
      
   // Determine value type and extract
   ushort firstChar = StringGetCharacter(json, valueStart);
   
   if(firstChar == '"') // String value
   {
      valueStart++; // Skip opening quote
      int valueEnd = StringFind(json, "\"", valueStart);
      if(valueEnd < 0)
         return defaultValue;
         
      string value = StringSubstr(json, valueStart, valueEnd - valueStart);
      return SafeTruncateString(value, 200); // Limit extracted string length
   }
   else // Numeric value
   {
      int valueEnd = valueStart;
      while(valueEnd < StringLen(json))
      {
         ushort ch = StringGetCharacter(json, valueEnd);
         if(ch == ',' || ch == '}' || ch == ']' || ch == ' ' || ch == '\t' || ch == '\n')
            break;
         valueEnd++;
      }
      
      if(valueEnd <= valueStart)
         return defaultValue;
         
      string value = StringSubstr(json, valueStart, valueEnd - valueStart);
      return SafeTruncateString(value, 50); // Limit numeric string length
   }
}

//+------------------------------------------------------------------+
//| Safe double to string conversion with precision control         |
//+------------------------------------------------------------------+
string SafeDoubleToString(double value, int precision = 5)
{
   // Validate input
   if(!MathIsValidNumber(value))
      return "0.00000";
      
   // Clamp precision
   precision = MathMax(0, MathMin(precision, 8));
   
   // Handle special cases
   if(value == 0.0)
      return "0." + StringSubstr("00000000", 0, precision);
      
   // Convert with specified precision
   return DoubleToString(value, precision);
}

//+------------------------------------------------------------------+
//| Safe integer to string conversion                               |
//+------------------------------------------------------------------+
string SafeIntegerToString(int value)
{
   return IntegerToString(value);
}

//+------------------------------------------------------------------+
//| Validate and sanitize comment strings                           |
//+------------------------------------------------------------------+
string SanitizeComment(const string comment)
{
   if(StringLen(comment) == 0)
      return "EscapeEA_Trade";
      
   string sanitized = comment;
   
   // Remove potentially dangerous characters
   StringReplace(sanitized, "|", "_");     // Pipe characters
   StringReplace(sanitized, ";", "_");     // Semicolons
   StringReplace(sanitized, "\n", " ");    // Newlines
   StringReplace(sanitized, "\r", " ");    // Carriage returns
   StringReplace(sanitized, "\t", " ");    // Tabs
   
   // Limit length
   sanitized = SafeTruncateString(sanitized, 50);
   
   // Ensure not empty after sanitization
   if(StringLen(sanitized) == 0)
      sanitized = "EscapeEA_Trade";
      
   return sanitized;
}

//+------------------------------------------------------------------+
//| INSTITUTIONAL GRADE STRING VALIDATION                           |
//+------------------------------------------------------------------+
class CSafeStringValidator
{
private:
   int               m_maxStringLength;       // Maximum allowed string length
   bool              m_strictMode;            // Strict validation mode
   
public:
                     CSafeStringValidator(int maxLength = 1000, bool strict = true);
   
   // VALIDATION METHODS
   bool              ValidateSymbol(const string symbol);
   bool              ValidateFilename(const string filename);
   bool              ValidateComment(const string comment);
   bool              ValidateJSON(const string json);
   bool              ValidateNumericString(const string str);
   
   // SANITIZATION METHODS
   string            SanitizeForFilename(const string str);
   string            SanitizeForComment(const string str);
   string            SanitizeForJSON(const string str);
   
   // CONFIGURATION
   void              SetMaxLength(int length);
   void              SetStrictMode(bool strict);
   
   // STATISTICS
   int               GetValidationCount() const;
   int               GetRejectionCount() const;
   double            GetValidationRate() const;
};

//+------------------------------------------------------------------+
//| SAFE STRING VALIDATOR IMPLEMENTATION                            |
//+------------------------------------------------------------------+
CSafeStringValidator::CSafeStringValidator(int maxLength = 1000, bool strict = true) :
   m_maxStringLength(MathMax(10, MathMin(maxLength, 10000))),
   m_strictMode(strict)
{
   Print("SAFE_STRING: Validator initialized - Max Length: ", m_maxStringLength, 
         " Strict Mode: ", m_strictMode ? "ON" : "OFF");
}

bool CSafeStringValidator::ValidateSymbol(const string symbol)
{
   // Symbol validation: 3-10 uppercase alphanumeric characters
   if(StringLen(symbol) < 3 || StringLen(symbol) > 10)
   {
      Print("SAFE_STRING: Invalid symbol length: ", StringLen(symbol));
      return false;
   }
   
   for(int i = 0; i < StringLen(symbol); i++)
   {
      ushort ch = StringGetCharacter(symbol, i);
      if(!((ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9')))
      {
         Print("SAFE_STRING: Invalid character in symbol: ", symbol);
         return false;
      }
   }
   
   return true;
}

bool CSafeStringValidator::ValidateFilename(const string filename)
{
   // Filename validation: safe characters only
   if(StringLen(filename) == 0 || StringLen(filename) > 100)
   {
      Print("SAFE_STRING: Invalid filename length: ", StringLen(filename));
      return false;
   }
   
   // Check for dangerous patterns
   if(StringFind(filename, "..") >= 0 ||
      StringFind(filename, "/") >= 0 ||
      StringFind(filename, "\\") >= 0 ||
      StringFind(filename, ":") >= 0)
   {
      Print("SAFE_STRING: Dangerous pattern in filename: ", filename);
      return false;
   }
   
   // Validate characters
   for(int i = 0; i < StringLen(filename); i++)
   {
      ushort ch = StringGetCharacter(filename, i);
      if(!((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || 
           (ch >= '0' && ch <= '9') || ch == '.' || ch == '_' || ch == '-'))
      {
         if(m_strictMode)
         {
            Print("SAFE_STRING: Invalid character in filename: ", filename);
            return false;
         }
      }
   }
   
   return true;
}

bool CSafeStringValidator::ValidateComment(const string comment)
{
   // Comment validation: reasonable length, safe characters
   if(StringLen(comment) > 100)
   {
      Print("SAFE_STRING: Comment too long: ", StringLen(comment));
      return false;
   }
   
   // Check for control characters
   for(int i = 0; i < StringLen(comment); i++)
   {
      ushort ch = StringGetCharacter(comment, i);
      if(ch < 32 && ch != 9) // Control characters except tab
      {
         Print("SAFE_STRING: Control character in comment");
         return false;
      }
   }
   
   return true;
}

string CSafeStringValidator::SanitizeForFilename(const string str)
{
   string sanitized = str;
   
   // Replace dangerous characters
   StringReplace(sanitized, "..", "_");
   StringReplace(sanitized, "/", "_");
   StringReplace(sanitized, "\\", "_");
   StringReplace(sanitized, ":", "_");
   StringReplace(sanitized, "*", "_");
   StringReplace(sanitized, "?", "_");
   StringReplace(sanitized, "<", "_");
   StringReplace(sanitized, ">", "_");
   StringReplace(sanitized, "|", "_");
   StringReplace(sanitized, "\"", "_");
   
   // Limit length
   if(StringLen(sanitized) > 100)
      sanitized = StringSubstr(sanitized, 0, 100);
      
   // Ensure not empty
   if(StringLen(sanitized) == 0)
      sanitized = "default";
      
   return sanitized;
}

string CSafeStringValidator::SanitizeForComment(const string str)
{
   string sanitized = str;
   
   // Replace control characters
   StringReplace(sanitized, "\n", " ");
   StringReplace(sanitized, "\r", " ");
   StringReplace(sanitized, "\t", " ");
   StringReplace(sanitized, "|", "_");
   StringReplace(sanitized, ";", "_");
   
   // Limit length
   if(StringLen(sanitized) > 50)
      sanitized = StringSubstr(sanitized, 0, 47) + "...";
      
   // Ensure not empty
   if(StringLen(sanitized) == 0)
      sanitized = "EscapeEA";
      
   return sanitized;
}

//+------------------------------------------------------------------+
//| GLOBAL SAFE STRING UTILITIES                                    |
//+------------------------------------------------------------------+

// Global validator instance
CSafeStringValidator* g_stringValidator = NULL;

// Initialize global validator
void InitializeSafeStringUtils()
{
   if(g_stringValidator == NULL)
   {
      g_stringValidator = new CSafeStringValidator(1000, true);
      Print("SAFE_STRING: Global validator initialized");
   }
}

// Cleanup global validator
void CleanupSafeStringUtils()
{
   if(g_stringValidator != NULL)
   {
      delete g_stringValidator;
      g_stringValidator = NULL;
      Print("SAFE_STRING: Global validator cleaned up");
   }
}

//+------------------------------------------------------------------+
//| CONVENIENCE MACROS FOR SAFE CONVERSIONS                         |
//+------------------------------------------------------------------+

#define SAFE_STR_TO_DOUBLE(str, min, max, def) SafeStringToDouble(str, min, max, def)
#define SAFE_STR_TO_INT(str, min, max, def) SafeStringToInteger(str, min, max, def)
#define SAFE_DOUBLE_TO_STR(val, prec) SafeDoubleToString(val, prec)
#define SAFE_SANITIZE_FILENAME(str) SanitizeFilename(str)
#define SAFE_SANITIZE_COMMENT(str) SanitizeComment(str)

//+------------------------------------------------------------------+