#!/bin/bash

# Script to recursively change ownership of Google Drive folder
# Usage: ./gdrive_recursive_owner.sh <FOLDER_ID> <NEW_OWNER_EMAIL>

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <FOLDER_ID> <NEW_OWNER_EMAIL>"
    echo "Example: $0 1ABC123xyz owner@example.com"
    exit 1
fi

FOLDER_ID="$1"
NEW_OWNER_EMAIL="$2"

# Setup logging
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/gdrive_${FOLDER_ID}_${TIMESTAMP}.log"
ERROR_FILE="${LOG_DIR}/errors_${FOLDER_ID}_${TIMESTAMP}.log"
RETRY_SCRIPT="${LOG_DIR}/retry_${FOLDER_ID}_${TIMESTAMP}.sh"

# Counters
TOTAL_FOLDERS=0
TOTAL_FILES=0
SUCCESS_FOLDERS=0
SUCCESS_FILES=0
FAILED_FOLDERS=0
FAILED_FILES=0

# Initialize retry script
echo "#!/bin/bash" > "$RETRY_SCRIPT"
echo "# Retry script for failed items" >> "$RETRY_SCRIPT"
echo "# Generated: $(date)" >> "$RETRY_SCRIPT"
echo "" >> "$RETRY_SCRIPT"
chmod +x "$RETRY_SCRIPT"

# Function to log
log_message() {
    local message="$1"
    echo "$message" | tee -a "$LOG_FILE"
}

log_message "========================================="
log_message "Recursive Ownership Transfer"
log_message "Folder ID: $FOLDER_ID"
log_message "New Owner: $NEW_OWNER_EMAIL"
log_message "Log file: $LOG_FILE"
log_message "Error file: $ERROR_FILE"
log_message "Retry script: $RETRY_SCRIPT"
log_message "========================================="
log_message ""

# Function to process a folder recursively
process_folder() {
    local folder_id="$1"
    local depth="$2"
    local indent=""
    
    for ((i=0; i<depth; i++)); do
        indent="  $indent"
    done
    
    log_message "${indent}Processing folder: $folder_id"
    TOTAL_FOLDERS=$((TOTAL_FOLDERS + 1))
    
    # Change ownership of the folder itself
    log_message "${indent}  -> Changing folder ownership..."
    output=$(timeout 60 gdrive permissions share --role owner --type user --email "$NEW_OWNER_EMAIL" "$folder_id" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 124 ]; then
        log_message "${indent}  -> WARNING: Timeout after 60s"
        echo "[FOLDER] TIMEOUT|$folder_id|Timeout" >> "$ERROR_FILE"
        echo "gdrive permissions share --role owner --type user --email \"$NEW_OWNER_EMAIL\" \"$folder_id\"" >> "$RETRY_SCRIPT"
        FAILED_FOLDERS=$((FAILED_FOLDERS + 1))
    elif echo "$output" | grep -q "emails could not be sent"; then
        log_message "${indent}  -> ✓ Folder ownership changed (email notification failed but permission granted)"
        SUCCESS_FOLDERS=$((SUCCESS_FOLDERS + 1))
    elif echo "$output" | grep -q "Error" && ! echo "$output" | grep -q "successfully shared"; then
        log_message "${indent}  -> ERROR: Failed to change folder ownership"
        log_message "${indent}     Error: $output"
        echo "[FOLDER] ERROR|$folder_id|$output" >> "$ERROR_FILE"
        echo "gdrive permissions share --role owner --type user --email \"$NEW_OWNER_EMAIL\" \"$folder_id\"" >> "$RETRY_SCRIPT"
        FAILED_FOLDERS=$((FAILED_FOLDERS + 1))
    else
        log_message "${indent}  -> ✓ Folder ownership changed"
        SUCCESS_FOLDERS=$((SUCCESS_FOLDERS + 1))
    fi
    
    # List all items in this folder (both files and folders)
    log_message "${indent}  -> Listing contents..."
    local items=$(gdrive files list --query "'$folder_id' in parents" --skip-header --max 9999 2>/dev/null)
    
    if [ -z "$items" ]; then
        log_message "${indent}  -> (empty folder)"
        return
    fi
    
    # Process each item
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        
        # Extract ID (first field)
        local item_id=$(echo "$line" | awk '{print $1}')
        
        # Check if it's a folder by looking for "folder" in the line
        # The type field is variable position due to names with spaces
        if echo "$line" | grep -q "folder"; then
            # Extract name (everything between ID and "folder")
            local item_name=$(echo "$line" | sed "s/^$item_id[[:space:]]*//" | sed 's/[[:space:]]*folder.*//')
            log_message "${indent}  📁 Subfolder: $item_name"
            # Recursively process subfolder
            process_folder "$item_id" $((depth + 1))
        else
            # Extract name (everything between ID and file type)
            local item_name=$(echo "$line" | sed "s/^$item_id[[:space:]]*//" | sed 's/[[:space:]]*\(regular\|document\|spreadsheet\|presentation\).*//')
            TOTAL_FILES=$((TOTAL_FILES + 1))
            log_message "${indent}  📄 File: $item_name"
            log_message "${indent}     -> Changing file ownership..."
            output=$(timeout 60 gdrive permissions share --role owner --type user --email "$NEW_OWNER_EMAIL" "$item_id" 2>&1)
            local exit_code=$?
            
            if [ $exit_code -eq 124 ]; then
                log_message "${indent}     -> WARNING: Timeout after 60s"
                echo "[FILE] TIMEOUT|$item_id|$item_name" >> "$ERROR_FILE"
                echo "gdrive permissions share --role owner --type user --email \"$NEW_OWNER_EMAIL\" \"$item_id\" # $item_name" >> "$RETRY_SCRIPT"
                FAILED_FILES=$((FAILED_FILES + 1))
            elif echo "$output" | grep -q "emails could not be sent"; then
                log_message "${indent}     -> ✓ File ownership changed (email notification failed but permission granted)"
                SUCCESS_FILES=$((SUCCESS_FILES + 1))
            elif echo "$output" | grep -q "Error" && ! echo "$output" | grep -q "successfully shared"; then
                log_message "${indent}     -> ERROR: Failed to change file ownership"
                log_message "${indent}        Error: $output"
                echo "[FILE] ERROR|$item_id|$item_name|$output" >> "$ERROR_FILE"
                echo "gdrive permissions share --role owner --type user --email \"$NEW_OWNER_EMAIL\" \"$item_id\" # $item_name" >> "$RETRY_SCRIPT"
                FAILED_FILES=$((FAILED_FILES + 1))
            else
                log_message "${indent}     -> ✓ File ownership changed"
                SUCCESS_FILES=$((SUCCESS_FILES + 1))
            fi
            
            # Delay to avoid API rate limiting (increased)
            sleep 1
        fi
    done <<< "$items"
}

# Start the recursive process
log_message "Starting recursive ownership transfer..."
log_message ""
process_folder "$FOLDER_ID" 0

log_message ""
log_message "========================================="
log_message "Process completed!"
log_message "========================================="
log_message ""
log_message "Statistics:"
log_message "  Total Folders: $TOTAL_FOLDERS (Success: $SUCCESS_FOLDERS, Failed: $FAILED_FOLDERS)"
log_message "  Total Files: $TOTAL_FILES (Success: $SUCCESS_FILES, Failed: $FAILED_FILES)"
log_message ""
log_message "Logs saved to: $LOG_FILE"
log_message "Errors saved to: $ERROR_FILE"

if [ $FAILED_FILES -gt 0 ] || [ $FAILED_FOLDERS -gt 0 ]; then
    log_message "Retry script created: $RETRY_SCRIPT"
    log_message "Run it to retry failed items: ./$RETRY_SCRIPT"
else
    rm -f "$RETRY_SCRIPT"
    log_message "No failures - retry script not needed"
fi
