# Google Drive Setup for EscapeEA Multi-Laptop Logging

## Overview
This guide explains how to configure LiveEA and PaperEA running on two different laptops to read and write to a shared Google Drive folder.

## Prerequisites
- Google Drive for Desktop installed on both laptops
- Access to the shared Google Drive folder: `https://drive.google.com/drive/folders/1k1uSlo9HcxUbWYxpfkIdlPQygGvpLBcS?usp=drive_link`

## Step 1: Install Google Drive Desktop

### Laptop 1 (LiveEA)
1. Download Google Drive for Desktop from: https://drive.google.com/drive/download/
2. Install and sign in with your Google account
3. During setup, choose "Stream files" or "Mirror files" (recommended: Mirror for offline access)
4. Note the local path (usually `C:\Users\[Username]\Google Drive\`)

### Laptop 2 (PaperEA)
1. Repeat the same installation process
2. Ensure both laptops use the same Google account or have shared access to the folder

## Step 2: Configure Shared Folder Access

1. Open the Google Drive folder link in a browser
2. Right-click the folder → "Share"
3. Add the Google account used on both laptops
4. Set permission to "Editor" for both accounts
5. Click "Send" to share access

## Step 3: Find Local Google Drive Path

### On Each Laptop:
1. Open File Explorer
2. Navigate to Google Drive (usually under "This PC" or "Quick Access")
3. Right-click the shared folder → "Properties"
4. Note the full local path (example: `C:\Users\JohnDoe\Google Drive\EscapeEA_SharedKB`)

## Step 4: Update EA Parameters

### LiveEA Configuration:
1. Open MetaTrader 5
2. Attach LiveEA to a chart
3. In the EA inputs, set:
   - `InpSharedKBDir`: `C:\Users\[YourUsername]\[Your Drive Path]\Shared Knowledge Base`
   - Example: `C:\Users\itoha\My Drive (emmanch13@gmail.com)\Shared Knowledge Base`

### PaperEA Configuration:
1. On the second laptop, open MetaTrader 5
2. Attach PaperEA to a chart
3. In the EA inputs, set:
   - `InpSharedKBDir`: `C:\Users\[YourUsername]\[Your Drive Path]\Shared Knowledge Base`
   - Example: `C:\Users\echuk\Mon Drive\Shared Knowledge Base`

## Step 5: Verify Sync Status

### On Both Laptops:
1. Check Google Drive system tray icon (should show green checkmark)
2. Navigate to the shared folder in File Explorer
3. Create a test file in the folder and verify it appears on both laptops

## Step 6: Test EA Logging

### Initial Test:
1. Start LiveEA on Laptop 1
2. Start PaperEA on Laptop 2
3. Check the Google Drive folder for new files:
   - `trades_EscapeEA_Live_[symbol].csv`
   - `trades_EscapeEA_Paper_[symbol].csv`
   - `signals_*.json`
   - `interval_logs/` subdirectories

## Troubleshooting

### Common Issues:
1. **Sync delays**: Allow 1-2 minutes for files to sync between laptops
2. **Permission errors**: Ensure both Google accounts have "Editor" access
3. **Path differences**: Use the exact local path shown in File Explorer properties
4. **Drive not syncing**: Restart Google Drive Desktop or check internet connection

### Alternative Path Formats:
If the standard path doesn't work, try:
- `G:\My Drive\EscapeEA_SharedKB` (if using Google Drive File Stream)
- `C:\Users\[Username]\OneDrive\Google Drive\EscapeEA_SharedKB` (if using OneDrive sync)

## Monitoring

### Check Sync Status:
1. Right-click Google Drive system tray icon
2. Select "Settings" → "Preferences"
3. Verify the shared folder is listed and syncing

### File Verification:
Files created by the EAs should appear in:
```
[Google Drive]\EscapeEA_SharedKB\
├── trades_EscapeEA_Live_XAUUSD.csv
├── trades_EscapeEA_Paper_XAUUSD.csv
├── signals_EscapeEA_Live_XAUUSD.json
├── signals_EscapeEA_Paper_XAUUSD.json
├── regimes_EscapeEA_Live_XAUUSD.json
├── regimes_EscapeEA_Paper_XAUUSD.json
└── interval_logs/
    ├── LiveEA/
    │   └── XAUUSD_20241220_1500.log
    └── PaperEA/
        └── XAUUSD_20241220_1500.log
```

## Security Notes
- Ensure both laptops have antivirus software
- Use strong Google account passwords
- Enable 2-factor authentication on Google accounts
- Regularly backup critical trading data
