#!/bin/bash

# Script to download all SocaLabs plugin zips, merge them per platform, and upload
# Usage: ./build_all_zips.sh <APIKEY>

set -e

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}[STEP]${NC} $1"
    echo -e "${GREEN}========================================${NC}"
}

# Check for API key
if [ -z "$1" ]; then
    log_error "Usage: $0 <APIKEY>"
    exit 1
fi

APIKEY="$1"
BASE_URL="https://socalabs.com/files"
LIST_URL="${BASE_URL}/list.php"
UPLOAD_URL="${BASE_URL}/set.php?key=${APIKEY}"

# Get script directory and use local work directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SCRIPT_DIR}/build_all_work"

log_info "Using working directory: ${WORK_DIR}"

# Create working directory if it doesn't exist
mkdir -p "${WORK_DIR}"

# Change to working directory
cd "${WORK_DIR}"

log_step "Fetching file list from ${LIST_URL}"

# Get the list of files (HTML page with links)
FILE_LIST=$(curl -s "${LIST_URL}")
log_info "Raw file list received"

# Parse the zip filenames from the HTML (extract from get.php?id=FILENAME.zip)
# Exclude files starting with All_, All_Loser_, or VirtualAnalog_
ZIPS=$(echo "${FILE_LIST}" | grep -oE 'get\.php\?id=[^"]+\.zip' | sed 's/get\.php?id=//' | grep -vE '^(All_|All_Loser_|VirtualAnalog_)' || true)

if [ -z "${ZIPS}" ]; then
    log_error "No zip files found to download"
    exit 1
fi

ZIP_COUNT=$(echo "${ZIPS}" | wc -l | tr -d ' ')
log_info "Found ${ZIP_COUNT} zip files to process (excluding All*, All_Loser*, VirtualAnalog*)"

# Create platform directories for extraction
mkdir -p linux_files mac_files win_files downloads
log_info "Created platform extraction directories"

log_step "Downloading and extracting zip files"

DOWNLOAD_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

for ZIP in ${ZIPS}; do
    DOWNLOAD_COUNT=$((DOWNLOAD_COUNT + 1))

    # Check if already downloaded
    if [ -f "downloads/${ZIP}" ]; then
        log_info "[${DOWNLOAD_COUNT}/${ZIP_COUNT}] Already exists: ${ZIP}"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    else
        log_info "[${DOWNLOAD_COUNT}/${ZIP_COUNT}] Downloading: ${ZIP}"
        DOWNLOAD_URL="${BASE_URL}/get.php?id=${ZIP}"

        if curl -f -s -o "downloads/${ZIP}" "${DOWNLOAD_URL}"; then
            log_success "Downloaded: ${ZIP}"
        else
            log_error "Failed to download: ${ZIP}"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            continue
        fi
    fi

    # Determine platform and extract to appropriate directory
    if [[ "${ZIP}" == *"_Linux.zip" ]]; then
        PLATFORM_DIR="linux_files"
    elif [[ "${ZIP}" == *"_Mac.zip" ]]; then
        PLATFORM_DIR="mac_files"
    elif [[ "${ZIP}" == *"_Win.zip" ]]; then
        PLATFORM_DIR="win_files"
    else
        log_warn "Unknown platform for ${ZIP}, skipping extraction"
        continue
    fi

    log_info "Extracting ${ZIP} to ${PLATFORM_DIR}/"
    if unzip -q -o "downloads/${ZIP}" -d "${PLATFORM_DIR}/"; then
        log_success "Extracted: ${ZIP}"
    else
        log_error "Failed to extract: ${ZIP}"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
done

log_info "Download complete. New: $((DOWNLOAD_COUNT - SKIPPED_COUNT - FAILED_COUNT)), Cached: ${SKIPPED_COUNT}, Failed: ${FAILED_COUNT}"

log_step "Creating merged platform zip files"

# Create All_Linux.zip
if [ -d "linux_files" ] && [ "$(ls -A linux_files 2>/dev/null)" ]; then
    log_info "Creating All_Linux.zip..."
    cd linux_files
    zip -r -q "../All_Linux.zip" .
    cd ..
    LINUX_SIZE=$(du -h "All_Linux.zip" | cut -f1)
    log_success "Created All_Linux.zip (${LINUX_SIZE})"
else
    log_warn "No Linux files to package"
fi

# Create All_Mac.zip
if [ -d "mac_files" ] && [ "$(ls -A mac_files 2>/dev/null)" ]; then
    log_info "Creating All_Mac.zip..."
    cd mac_files
    zip -r -q "../All_Mac.zip" .
    cd ..
    MAC_SIZE=$(du -h "All_Mac.zip" | cut -f1)
    log_success "Created All_Mac.zip (${MAC_SIZE})"
else
    log_warn "No Mac files to package"
fi

# Create All_Win.zip
if [ -d "win_files" ] && [ "$(ls -A win_files 2>/dev/null)" ]; then
    log_info "Creating All_Win.zip..."
    cd win_files
    zip -r -q "../All_Win.zip" .
    cd ..
    WIN_SIZE=$(du -h "All_Win.zip" | cut -f1)
    log_success "Created All_Win.zip (${WIN_SIZE})"
else
    log_warn "No Windows files to package"
fi

log_step "Uploading merged zip files"

# Track upload success
UPLOAD_SUCCESS=0
UPLOAD_FAIL=0

# Upload each platform zip
for PLATFORM_ZIP in All_Linux.zip All_Mac.zip All_Win.zip; do
    if [ -f "${PLATFORM_ZIP}" ]; then
        log_info "Uploading ${PLATFORM_ZIP}..."

        FILE_SIZE=$(du -h "${PLATFORM_ZIP}" | cut -f1)
        log_info "File size: ${FILE_SIZE}"

        RESPONSE=$(curl -s --max-time 300 -F "files=@${PLATFORM_ZIP}" "${UPLOAD_URL}" 2>&1)
        CURL_EXIT=$?

        if [ ${CURL_EXIT} -ne 0 ]; then
            log_error "curl failed with exit code ${CURL_EXIT}"
            log_error "curl output: ${RESPONSE}"
            UPLOAD_FAIL=$((UPLOAD_FAIL + 1))
        elif [[ "${RESPONSE}" == OK:* ]]; then
            log_success "Uploaded ${PLATFORM_ZIP} successfully"
            log_info "Server response: ${RESPONSE}"
            UPLOAD_SUCCESS=$((UPLOAD_SUCCESS + 1))
        else
            log_error "Failed to upload ${PLATFORM_ZIP}"
            log_error "Server response: ${RESPONSE}"
            UPLOAD_FAIL=$((UPLOAD_FAIL + 1))
        fi
    else
        log_warn "${PLATFORM_ZIP} not found, skipping upload"
        UPLOAD_FAIL=$((UPLOAD_FAIL + 1))
    fi
done

log_step "Summary"
log_info "Total files processed: ${DOWNLOAD_COUNT}"
log_info "Cached (already downloaded): ${SKIPPED_COUNT}"
log_info "Failed downloads/extractions: ${FAILED_COUNT}"
log_info "Uploads successful: ${UPLOAD_SUCCESS}"
log_info "Uploads failed: ${UPLOAD_FAIL}"

if [ -f "All_Linux.zip" ]; then
    log_info "All_Linux.zip: $(du -h All_Linux.zip | cut -f1)"
fi
if [ -f "All_Mac.zip" ]; then
    log_info "All_Mac.zip: $(du -h All_Mac.zip | cut -f1)"
fi
if [ -f "All_Win.zip" ]; then
    log_info "All_Win.zip: $(du -h All_Win.zip | cut -f1)"
fi

# Only clean up if all uploads succeeded
if [ ${UPLOAD_FAIL} -eq 0 ] && [ ${UPLOAD_SUCCESS} -eq 3 ]; then
    log_success "All uploads successful! Cleaning up downloaded zips..."
    rm -rf "${WORK_DIR}"
    log_success "Cleanup complete"
else
    log_warn "Not all uploads succeeded. Keeping downloaded files in ${WORK_DIR} for retry."
    log_warn "Re-run the script to retry uploads without re-downloading."
fi

log_success "Script completed!"
