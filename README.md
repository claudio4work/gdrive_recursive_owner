# Google Drive Recursive Ownership Transfer

A bash script to recursively transfer ownership of Google Drive folders and all their contents (files and subfolders) using the `gdrive` CLI tool.

## Prerequisites

- [gdrive](https://github.com/glotlabs/gdrive) CLI tool installed and configured
- Authenticated Google account with appropriate permissions
- Bash shell

## Installation

1. Ensure `gdrive` is installed and accessible in your PATH
2. Authenticate your Google account:
   ```bash
   gdrive account add
   ```
3. Make the script executable:
   ```bash
   chmod +x gdrive_recursive_owner.sh
   ```

## Usage

```bash
./gdrive_recursive_owner.sh <FOLDER_ID> <NEW_OWNER_EMAIL>
```

### Parameters

- `FOLDER_ID`: The Google Drive folder ID (can be found in the folder's URL)
- `NEW_OWNER_EMAIL`: Email address of the new owner

### Example

```bash
./gdrive_recursive_owner.sh 1ABC123xyz456def newowner@example.com
```

## Features

- **Recursive Processing**: Automatically processes all files and subfolders within the target folder
- **Visual Progress**: Shows hierarchical structure with indentation and emoji indicators
- **Error Handling**: Handles email notification failures (permissions are still granted)
- **Timeout Protection**: 60-second timeout per item to prevent hanging on network issues
- **Rate Limiting**: Built-in delay (1s) between API calls to avoid rate limits
- **Comprehensive Logging**: Creates detailed logs, error reports, and automatic retry script
- **Large Folder Support**: Processes up to 9,999 items per folder (no pagination limits)
- **Detailed Output**: Reports success/failure for each item processed

## How It Works

1. Changes ownership of the parent folder
2. Lists all contents (files and subfolders)
3. Recursively processes each subfolder
4. Changes ownership of each file
5. Reports completion status

## Output Example

```
=========================================
Recursive Ownership Transfer
Folder ID: 1ABC123xyz456def
New Owner: newowner@example.com
=========================================

Starting recursive ownership transfer...

Processing folder: 1ABC123xyz456def
  -> Changing folder ownership...
  -> ✓ Folder ownership changed
  -> Listing contents...
  📁 Subfolder: my_subfolder
  Processing folder: 1XYZ789abc
    -> Changing folder ownership...
    -> ✓ Folder ownership changed
    -> Listing contents...
    📄 File: document.pdf
       -> Changing file ownership...
       -> ✓ File ownership changed
  📄 File: spreadsheet.xlsx
     -> Changing file ownership...
     -> ✓ File ownership changed

=========================================
Process completed!
=========================================
```

## Logging and Error Handling

The script creates three files in the `./logs` directory:

1. **Log File**: `gdrive_{FOLDER_ID}_{TIMESTAMP}.log` - Complete log of all operations
2. **Error File**: `errors_{FOLDER_ID}_{TIMESTAMP}.log` - Details of failed operations
3. **Retry Script**: `retry_{FOLDER_ID}_{TIMESTAMP}.sh` - Executable script to retry failed operations

At the end of execution, the script displays statistics showing:
- Total folders/files processed
- Successful and failed operations
- Location of log files

## Known Issues

- Google Drive API may return an error about failed email notifications even when permissions are successfully granted. The script handles this gracefully.
- Large folders with many files may take time to process (approximately 1 file per second due to rate limiting)
- Some files may fail with "Sorry, you do not have permission to share" if they have special restrictions or were created by other users with limited sharing permissions
- Network timeouts may occur; the script will skip items that timeout after 60 seconds and continue processing

## Troubleshooting

### No account selected error
If you get an error saying "no account selected", it means the `gdrive` CLI doesn't know which Google account to use.

To fix this:
1. List available authenticated accounts:
   ```bash
   gdrive account list
   ```
2. Select the account you want to use:
   ```bash
   gdrive account switch
   ```
3. Choose the desired account from the interactive menu

### Permission denied
Ensure you are the current owner of the folder or have sufficient permissions to transfer ownership. If you lack permissions, the script will fail with permission errors that will be logged in the error file.

### Finding Folder ID
The folder ID is in the Google Drive URL:
```
https://drive.google.com/drive/folders/1ABC123xyz456def
                                          ^^^^^^^^^^^^^^^^^^^
                                          This is the folder ID
```
