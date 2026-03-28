#!/bin/bash

# anonymize.sh - Text anonymization/de-anonymization script
# Usage: ./anonymize.sh [OPTIONS] FILE1 [FILE2 ...]
# Options:
#   -a, --anonymize     Anonymize text (default)
#   -d, --deanonymize   De-anonymize text
#   -c, --config FILE   Specify config file (default: anonymize.conf)
#   -g, --generate      Generate config file from text patterns
#   -h, --help          Show help

set -euo pipefail
# set -x
# Default values
MODE="anonymize"
CONFIG_FILE="anonymize.conf"
GENERATE_CONFIG=false
DRY_RUN=false
WORK_FILES=()

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Help function
show_help() {
    cat << EOF
Text Anonymization Script

USAGE:
    $0 [OPTIONS] FILE1 [FILE2 ...]

OPTIONS:
    -a, --anonymize     Anonymize text (default mode)
    -d, --deanonymize   De-anonymize text back to original
    -c, --config FILE   Specify config file (default: anonymize.conf)
    -g, --generate      Generate config file from detected patterns
    --dry-run           Show what would be done without making changes
    -h, --help          Show this help message

CONFIG FILE FORMAT:
    PLACEHOLDER_NAME=Original Value
    COMPANY_A=Acme Corporation
    PERSON_B=John Smith
    EMAIL_C=john.smith@example.com

EXAMPLES:
    # Generate config from patterns in text files
    $0 -g document1.txt document2.txt

    # Anonymize files using default config
    $0 -a document1.txt document2.txt

    # Preview anonymization without making changes
    $0 --dry-run -a document1.txt

    # De-anonymize files
    $0 -d document1.txt.anon document2.txt.anon

    # Use custom config file
    $0 -c custom.conf -a document.txt

The script creates .anon files for anonymized versions and .orig backups.
EOF
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Parse command line arguments
parse_args() {

    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--anonymize)
                MODE="anonymize"
                shift
                ;;
            -d|--deanonymize)
                MODE="deanonymize"
                shift
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -g|--generate)
                GENERATE_CONFIG=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                WORK_FILES+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#files[@]} -eq 0 ]]; then
        log_error "No input files specified"
        show_help
        exit 1
    fi
}

# Generate anonymization patterns
generate_config() {
    local files=("$@")
    local temp_text="/tmp/combined_text_$$"

    log_info "Analyzing files for anonymization patterns..."

    # Combine all text files
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            cat "$file" >> "$temp_text"
        else
            log_warning "File not found: $file"
        fi
    done

    if [[ ! -f "$temp_text" ]]; then
        log_error "No valid files to analyze"
        exit 1
    fi

    # Create config file
    {
        echo "# Generated anonymization config - $(date)"
        echo "# Edit this file to customize anonymization mappings"
        echo ""

        # Email addresses
        local email_counter=1
        grep -oE '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b' "$temp_text" | sort -u | while read -r email; do
            echo "EMAIL_${email_counter}=${email}"
            ((email_counter++))
        done

        # Phone numbers (various formats)
        local phone_counter=1
        grep -oE '\b(\+?1[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}\b|\b[0-9]{2,3}[-.\s][0-9]{2}[-.\s][0-9]{2}[-.\s][0-9]{2}\b' "$temp_text" | sort -u | while read -r phone; do
            echo "PHONE_${phone_counter}=${phone}"
            ((phone_counter++))
        done

        # Potential names (capitalized words)
        local name_counter=1
        grep -oE '\b[A-Z][a-z]+ [A-Z][a-z]+\b' "$temp_text" | sort -u | head -20 | while read -r name; do
            echo "PERSON_${name_counter}=${name}"
            ((name_counter++))
        done

        # URLs
        local url_counter=1
        grep -oE 'https?://[^\s]+' "$temp_text" | sort -u | while read -r url; do
            echo "URL_${url_counter}=${url}"
            ((url_counter++))
        done

        # IP addresses
        local ip_counter=1
        grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$temp_text" | sort -u | while read -r ip; do
            echo "IP_${ip_counter}=${ip}"
            ((ip_counter++))
        done

        # Companies (words ending with common suffixes)
        local company_counter=1
        grep -oE '\b[A-Z][A-Za-z\s]+(Inc\.|LLC|Corp\.|Corporation|Ltd\.|Limited|A/S|ApS)\b' "$temp_text" | sort -u | head -10 | while read -r company; do
            echo "COMPANY_${company_counter}=${company}"
            ((company_counter++))
        done

    } > "$CONFIG_FILE"

    rm -f "$temp_text"
    log_success "Generated config file: $CONFIG_FILE"
    log_info "Please review and edit the config file before anonymizing"
}

# Load config file
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file not found: $CONFIG_FILE"
        log_info "Run with -g option to generate a config file first"
        exit 1
    fi

    # Read config into associative arrays
    declare -gA ANONYMIZE_MAP
    declare -gA DEANONYMIZE_MAP

    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue

        # Remove leading/trailing whitespace
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if [[ -n "$key" && -n "$value" ]]; then
            ANONYMIZE_MAP["$value"]="$key"
            DEANONYMIZE_MAP["$key"]="$value"
        fi
    done < "$CONFIG_FILE"

    log_info "Loaded ${#ANONYMIZE_MAP[@]} mappings from $CONFIG_FILE"
}

# Anonymize text
anonymize_text() {
    local input_file="$1"
    local output_file="${input_file}.anon"

    if [[ ! -f "$input_file" ]]; then
        log_error "Input file not found: $input_file"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would anonymize: $input_file -> $output_file"
        log_info "[DRY RUN] Would create backup: ${input_file}.orig"

        # Show what replacements would be made
        local temp_file="/tmp/anon_preview_$"
        cp "$input_file" "$temp_file"

        local changes_made=false
        for original in "${!ANONYMIZE_MAP[@]}"; do
            local placeholder="${ANONYMIZE_MAP[$original]}"
            # Check if pattern exists in file
            if grep -q "$(printf '%s\n' "$original" | sed 's/[[\.*^$()+?{|]/\\&/g')" "$temp_file"; then
                log_info "[DRY RUN] Would replace: '$original' -> '$placeholder'"
                changes_made=true
            fi
        done

        if [[ "$changes_made" == false ]]; then
            log_info "[DRY RUN] No patterns found to anonymize in $input_file"
        fi

        rm -f "$temp_file"
        return 0
    fi

    # Create backup
    cp "$input_file" "${input_file}.orig"

    # Apply anonymization - handle multi-line patterns
    local temp_file="/tmp/anon_$"
    cp "$input_file" "$temp_file"

    for original in "${!ANONYMIZE_MAP[@]}"; do
        local placeholder="${ANONYMIZE_MAP[$original]}"
        # Use perl for better multi-line handling and proper escaping
        perl -i -pe "s/\Q$original\E/$placeholder/g" "$temp_file"
    done

    mv "$temp_file" "$output_file"
    log_success "Anonymized: $input_file -> $output_file"
}

# De-anonymize text
deanonymize_text() {
    local input_file="$1"
    local output_file

    # Determine output filename
    if [[ "$input_file" == *.anon ]]; then
        output_file="${input_file%.anon}.deanon"
    else
        output_file="${input_file}.deanon"
    fi

    if [[ ! -f "$input_file" ]]; then
        log_error "Input file not found: $input_file"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would de-anonymize: $input_file -> $output_file"

        # Show what replacements would be made
        local temp_file="/tmp/deanon_preview_$"
        cp "$input_file" "$temp_file"

        local changes_made=false
        for placeholder in "${!DEANONYMIZE_MAP[@]}"; do
            local original="${DEANONYMIZE_MAP[$placeholder]}"
            # Check if pattern exists in file
            if grep -q "$(printf '%s\n' "$placeholder" | sed 's/[[\.*^$()+?{|]/\\&/g')" "$temp_file"; then
                log_info "[DRY RUN] Would replace: '$placeholder' -> '$original'"
                changes_made=true
            fi
        done

        if [[ "$changes_made" == false ]]; then
            log_info "[DRY RUN] No patterns found to de-anonymize in $input_file"
        fi

        rm -f "$temp_file"
        return 0
    fi

    # Apply de-anonymization - handle multi-line patterns
    local temp_file="/tmp/deanon_$"
    cp "$input_file" "$temp_file"

    for placeholder in "${!DEANONYMIZE_MAP[@]}"; do
        local original="${DEANONYMIZE_MAP[$placeholder]}"
        # Use perl for better multi-line handling and proper escaping
        perl -i -pe "s/\Q$placeholder\E/$original/g" "$temp_file"
    done

    mv "$temp_file" "$output_file"
    log_success "De-anonymized: $input_file -> $output_file"
}

# Main function
main() {

    parse_args "$@"

    if [[ "$GENERATE_CONFIG" == true ]]; then
        generate_config "${WORK_FILES[@]}"
        exit 0
    fi

    load_config

    case "$MODE" in
        anonymize)
            if [[ "$DRY_RUN" == true ]]; then
                log_info "[DRY RUN] Would anonymize ${#WORK_FILES[@]} file(s)..."
            else
                log_info "Anonymizing ${#WORK_FILES[@]} file(s)..."
            fi
            for file in "${WORK_FILES[@]}"; do
                anonymize_text "$file"
            done
            ;;
        deanonymize)
            if [[ "$DRY_RUN" == true ]]; then
                log_info "[DRY RUN] Would de-anonymize ${#WORK_FILES[@]} file(s)..."
            else
                log_info "De-anonymizing ${#WORK_FILES[@]} file(s)..."
            fi
            for file in "${WORK_FILES[@]}"; do
                deanonymize_text "$file"
            done
            ;;
    esac

    log_success "Processing complete!"
}

# Run main function with all arguments
# Check if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
