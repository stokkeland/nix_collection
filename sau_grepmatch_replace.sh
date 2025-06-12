#!/bin/bash

# Enhanced grep and replace function
# Searches for text in a file and replaces it if found
#
# Based on a script I have been using for years in my install/sysadmin items.
# I had claude AI clean up add add veirifcations and comments etc, it also
# changed my SED setup to "the sed pipes" below, safer than my original
#
# Usage:
#   sau_grepmatch_replace <filename> <search_text> <replace_text> [--verbose]
#   
# Examples:
#   sau_grepmatch_replace config.txt "old_value" "new_value"
#   sau_grepmatch_replace app.conf "debug=false" "debug=true" --verbose
#   ./script.sh config.txt "old_value" "new_value"
#   ./script.sh config.txt "old_value" "new_value" --verbose

function sau_grepmatch_replace() {
    local filename="$1"
    local search_text="$2" 
    local replace_text="$3"
    local verbose=false
    
    # Check for verbose flag in any position
    for arg in "$@"; do
        if [[ "$arg" == "--verbose" ]]; then
            verbose=true
            break
        fi
    done
    
    # Check that all 3 required arguments are supplied
    if [[ $# -lt 3 ]] || [[ -z "$filename" ]] || [[ -z "$search_text" ]] || [[ -z "$replace_text" ]]; then
        echo "ERROR: All 3 arguments are required." >&2
        echo "Usage: sau_grepmatch_replace <filename> <search_text> <replace_text> [--verbose]" >&2
        return 1
    fi
    
    # Check if file exists
    if [[ ! -f "$filename" ]]; then
        echo "ERROR: File '$filename' does not exist." >&2
        return 1
    fi
    
    # Check if file is readable and writable
    if [[ ! -r "$filename" ]]; then
        echo "ERROR: File '$filename' is not readable." >&2
        return 1
    fi
    
    if [[ ! -w "$filename" ]]; then
        echo "ERROR: File '$filename' is not writable." >&2
        return 1
    fi
    
    # Search for the text in the file
    if grep --quiet --fixed-strings "$search_text" "$filename"; then
        # Perform the replacement using sed with proper escaping
        # Use different delimiter to avoid conflicts with forward slashes
        if sed -i "s|$(printf '%s\n' "$search_text" | sed 's/[[\.*\^$()+?{|]/\\&/g')|$(printf '%s\n' "$replace_text" | sed 's/[[\.*\^$(){}+?|/]/\\&/g')|g" "$filename"; then
            # Only show output in verbose mode
            if [[ "$verbose" == true ]]; then
                echo "Successfully replaced '$search_text' with '$replace_text' in '$filename'"
            fi
            return 0
        else
            echo "ERROR: Failed to perform replacement in '$filename'." >&2
            return 1
        fi
    else
        echo "WARNING: Search text '$search_text' not found in '$filename'." >&2
        return 2
    fi
}

# Allow script to be run directly from command line
# Check if script is being executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    sau_grepmatch_replace "$@"
    exit $?
fi

# If sourced, the function is now available in the current shell
