#!/bin/bash
# sau_verify_symlink_target - Verify that a symlink points to the expected target
# I used this in some installation and systems maintenance scripts
#
# A lot of this created with Claude AI
#
# This script verifies that a symlink points to a specific target file.
# Parameter order matches `ln -s` convention: source file first, then symlink location.
#
# Usage:
#   sau_verify_symlink_target [--verbose] <target_file> <symlink_path>
#   ./sau_verify_symlink_target [--verbose] file syml
#
# Options:
#   --verbose  Output success message to stdout (silent success by default)
#
# Examples:
#   # Verify that 'mylink' points to '/path/to/original/file' (silent if OK)
#   sau_verify_symlink_target /path/to/original/file mylink
#   
#   # Same verification but with verbose output
#   sau_verify_symlink_target --verbose /path/to/original/file mylink
#   
#   # Check if a config symlink points to the right config file
#   sau_verify_symlink_target ~/.config/app/config.yml ~/.local/share/app/config.yml
#
# Exit codes:
#   0 - Symlink target matches expected target
#   1 - Error (wrong arguments, symlink doesn't exist, or target mismatch)

sau_verify_symlink_target() {
    local verbose=false
    local expected_target
    local symlink_path

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose)
                verbose=true
                shift
                ;;
            *)
                if [ -z "$expected_target" ]; then
                    expected_target="$1"
                elif [ -z "$symlink_path" ]; then
                    symlink_path="$1"
                else
                    echo "Error: Too many arguments" >&2
                    echo "Usage: sau_verify_symlink_target [--verbose] <target_file> <symlink_path>" >&2
                    return 1
                fi
                shift
                ;;
        esac
    done

    # Check if correct number of arguments provided
    if [ -z "$expected_target" ] || [ -z "$symlink_path" ]; then
        echo "Usage: sau_verify_symlink_target [--verbose] <target_file> <symlink_path>" >&2
        return 1
    fi

    # Check if the symlink exists
    if [ ! -L "$symlink_path" ]; then
        echo "Error: '$symlink_path' is not a symlink or doesn't exist" >&2
        return 1
    fi

    # Get the actual target of the symlink
    actual_target=$(readlink "$symlink_path")

    # Compare the targets
    if [ "$actual_target" = "$expected_target" ]; then
        if [ "$verbose" = true ]; then
            echo "OK: Symlink target matches: '$symlink_path' -> '$actual_target'"
        fi
        return 0
    else
        echo "Fail: Symlink target mismatch:" >&2
        echo "  Symlink: '$symlink_path'" >&2
        echo "  Expected: '$expected_target'" >&2
        echo "  Actual: '$actual_target'" >&2
        return 1
    fi
}

# If script is executed directly (not sourced), run the function with all arguments
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    sau_verify_symlink_target "$@"
fi
