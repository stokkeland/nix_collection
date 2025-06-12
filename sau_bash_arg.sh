#!/bin/bash
#
# sau_bash_arg.sh
#
# VERSION: 2025-02-01
# https://github.com/stokkeland/nix_collection/blob/main/sau_bash_arg.sh
# 
# Usable in your own scripts, just source this is and process arguments
# and validate without thinking too much about it, same way in every script.
#
# Some have asked "Why don't you use this in the other scripts",  it is
# Because this is a relatively new add (2025) and most of the other stuff
# was older..  but yes i got tired of copy/paste/edit the argument 
# management on the others and will be using this in my base bash sourced
# library going forward (that does add dendencies)
#
# Generated with Claude AI - some adjustments
#################################################################
##
##  Argument processing system 
##
##  A flexible, reusable bash argument parsing system with validation, 
##  error handling, and automatic usage generation.
##
##  QUICK START GUIDE:
##
##  1. Basic Setup:
##     #!/bin/bash
##     source sau_bash_arg.sh
##     
##     # Define your arguments
##     sau_define_arg "input" "i" "input" "Input file" "true" "true" "file"
##     sau_define_arg "verbose" "v" "verbose" "Verbose output" "false" "false"
##     
##     # Parse and validate
##     sau_parse_args "$@"
##     sau_validate_args || { sau_print_validation_errors; exit 1; }
##     
##     # Use the arguments
##     input_file=$(sau_get_arg "input")
##     if sau_has_arg "verbose"; then
##         echo "Processing $input_file..."
##     fi
##
##  2. Built-in Validators:
##     - file          - File must exist
##     - dir           - Directory must exist  
##     - int           - Positive integer
##     - email         - Valid email format
##     - url           - Valid HTTP/HTTPS URL
##     - range:min:max - Number within range
##     - enum:val1:val2:val3 - One of allowed values
##
##  3. Custom Validators:
##     sau_validate_my_format() {
##         local value="$1"
##         [[ "$value" =~ ^pattern$ ]] || echo "Error message"
##     }
##     sau_define_arg "custom" "c" "custom" "Custom field" "false" "true" "sau_validate_my_format"
##
##  4. Getting Values:
##     value=$(sau_get_arg "argument_name")      # Get value
##     sau_has_arg "flag_name" && echo "Set"     # Check if provided
##     positional=($(sau_get_positional))       # Get positional args
##
##  FEATURES:
##  - Flexible Configuration - Define arguments with full control over behavior  
##  - Built-in Validation - Common validators included, custom validators supported  
##  - Error Handling - Comprehensive error collection and reporting  
##  - Auto-Generated Help - Usage information generated from configuration  
##  - Short & Long Flags - Support for both -h and --help style arguments  
##  - Required Arguments - Mark arguments as required with validation  
##  - Default Values - Set defaults for optional arguments  
##  - Positional Arguments - Capture non-flag arguments  
##  - Unknown Argument Detection - Identify and report unrecognized flags  
##
##  API REFERENCE:
##  - sau_define_arg "name" "short" "long" "desc" "required" "has_value" "validator" "default"
##  - sau_parse_args "$@" - Parse command line arguments
##  - sau_validate_args - Validate all arguments, returns exit code
##  - sau_get_arg "name" - Get argument value
##  - sau_has_arg "name" - Check if argument was provided
##  - sau_get_positional - Get array of positional arguments
##  - sau_print_validation_errors - Display validation errors
##  - sau_generate_usage_info "script_name" - Generate help text
##
##  EXAMPLE USAGE:
##  
##  Simple Example:
##    #!/bin/bash
##    source sau_bash_arg.sh
##    
##    sau_define_arg "help" "h" "help" "Show help message" "false" "false"
##    sau_define_arg "source" "s" "source" "Source directory" "true" "true" "dir"
##    sau_define_arg "compress" "z" "compress" "Enable compression" "false" "false"
##    
##    sau_parse_args "$@"
##    sau_has_arg "help" && { sau_generate_usage_info "$(basename "$0")"; exit 0; }
##    sau_validate_args || { sau_print_validation_errors; exit 1; }
##    
##    echo "Source: $(sau_get_arg source)"
##    sau_has_arg "compress" && echo "Compression enabled"
##
##  Comprehensive Example:
##    #!/bin/bash
##    source sau_bash_arg.sh
##    
##    SCRIPT_NAME=$(basename "$0")
##    SCRIPT_VERSION="1.0.0"
##    
##    # Setup arguments
##    setup_arguments() {
##        sau_define_arg "help" "h" "help" "Show this help message" "false" "false" "" ""
##        sau_define_arg "version" "v" "version" "Show version information" "false" "false" "" ""
##        sau_define_arg "verbose" "V" "verbose" "Enable verbose output" "false" "false" "" ""
##        sau_define_arg "config" "c" "config" "Configuration file path" "true" "true" "file" ""
##        sau_define_arg "output" "o" "output" "Output directory" "false" "true" "dir" "/tmp"
##        sau_define_arg "port" "p" "port" "Port number" "false" "true" "range:1:65535" "8080"
##        sau_define_arg "email" "e" "email" "Email address for notifications" "false" "true" "email" ""
##        sau_define_arg "mode" "m" "mode" "Operation mode" "false" "true" "enum:dev:prod:test" "dev"
##        sau_define_arg "count" "n" "count" "Number of iterations" "false" "true" "int" "1"
##        sau_define_arg "url" "u" "url" "API endpoint URL" "false" "true" "url" ""
##    }
##    
##    # Custom validator example
##    sau_validate_custom_format() {
##        local value="$1"
##        if [[ ! "$value" =~ ^[A-Z]{2}-[0-9]{4}$ ]]; then
##            echo "Must be in format XX-YYYY (e.g., AB-1234)"
##        fi
##    }
##    
##    print_usage() {
##        cat << EOF
##    $SCRIPT_NAME - Example application with argument parsing
##    
##    $(sau_generate_usage_info "$SCRIPT_NAME")
##    
##    Examples:
##      $SCRIPT_NAME -c config.json -o /var/output -p 3000
##      $SCRIPT_NAME --config config.json --mode prod --verbose
##      $SCRIPT_NAME -h
##    
##    For more information, see the documentation.
##    EOF
##    }
##    
##    main() {
##        setup_arguments
##        sau_parse_args "$@"
##        
##        # Handle help and version first
##        if sau_has_arg "help"; then
##            print_usage
##            exit 0
##        fi
##        
##        if sau_has_arg "version"; then
##            echo "$SCRIPT_NAME version $SCRIPT_VERSION"
##            exit 0
##        fi
##        
##        # Validate all arguments
##        if ! sau_validate_args; then
##            sau_print_validation_errors
##            echo "Use -h or --help for usage information."
##            exit 1
##        fi
##        
##        # Check for unknown arguments
##        local unknown_args=($(sau_get_unknown))
##        if [[ ${#unknown_args[@]} -gt 0 ]]; then
##            echo "Unknown arguments: ${unknown_args[*]}" >&2
##            exit 1
##        fi
##        
##        # Display parsed arguments
##        echo "=== Parsed Arguments ==="
##        sau_has_arg "verbose" && echo "Verbose mode: enabled"
##        echo "Configuration file: $(sau_get_arg config)"
##        echo "Output directory: $(sau_get_arg output)"
##        echo "Port: $(sau_get_arg port)"
##        echo "Mode: $(sau_get_arg mode)"
##        echo "Count: $(sau_get_arg count)"
##        
##        sau_has_arg "email" && echo "Email: $(sau_get_arg email)"
##        sau_has_arg "url" && echo "URL: $(sau_get_arg url)"
##        
##        # Display positional arguments if any
##        local positional_args=($(sau_get_positional))
##        if [[ ${#positional_args[@]} -gt 0 ]]; then
##            echo "Positional arguments: ${positional_args[*]}"
##        fi
##        
##        echo "Starting application with the above configuration..."
##        sau_has_arg "verbose" && echo "Processing in verbose mode..."
##        echo "Application completed successfully!"
##    }
##    
##    main "$@"
##
#################################################################

# Global variables for argument processing
declare -A SAU_ARG_CONFIG
declare -A SAU_ARG_VALUES
declare -A SAU_ARG_VALIDATION_ERRORS
SAU_ARG_POSITIONAL=()
SAU_ARG_UNKNOWN=()

# Validation types
sau_validate_file() {
    local value="$1"
    [[ -f "$value" ]] || echo "File does not exist: $value"
}

sau_validate_dir() {
    local value="$1"
    [[ -d "$value" ]] || echo "Directory does not exist: $value"
}

sau_validate_int() {
    local value="$1"
    [[ "$value" =~ ^[0-9]+$ ]] || echo "Must be a positive integer: $value"
}

sau_validate_email() {
    local value="$1"
    [[ "$value" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] || echo "Invalid email format: $value"
}

sau_validate_url() {
    local value="$1"
    [[ "$value" =~ ^https?:// ]] || echo "Must be a valid URL (http/https): $value"
}

sau_validate_range() {
    local value="$1"
    local min="$2"
    local max="$3"
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "Must be a number: $value"
    elif (( value < min || value > max )); then
        echo "Must be between $min and $max: $value"
    fi
}

sau_validate_enum() {
    local value="$1"
    shift
    local valid_values=("$@")
    local found=false
    for valid in "${valid_values[@]}"; do
        if [[ "$value" == "$valid" ]]; then
            found=true
            break
        fi
    done
    [[ "$found" == true ]] || echo "Invalid value '$value'. Must be one of: ${valid_values[*]}"
}

# Configure argument definition
# Usage: sau_define_arg "option_name" "short_flag" "long_flag" "description" "required" "has_value" "validator" "default"
sau_define_arg() {
    local name="$1"
    local short="$2"
    local long="$3"
    local desc="$4"
    local required="${5:-false}"
    local has_value="${6:-false}"
    local validator="${7:-}"
    local default="${8:-}"
    
    SAU_ARG_CONFIG["${name}_short"]="$short"
    SAU_ARG_CONFIG["${name}_long"]="$long"
    SAU_ARG_CONFIG["${name}_desc"]="$desc"
    SAU_ARG_CONFIG["${name}_required"]="$required"
    SAU_ARG_CONFIG["${name}_has_value"]="$has_value"
    SAU_ARG_CONFIG["${name}_validator"]="$validator"
    SAU_ARG_CONFIG["${name}_default"]="$default"
    
    # Set default value if provided
    if [[ -n "$default" ]]; then
        SAU_ARG_VALUES["$name"]="$default"
    fi
}

# Get configured argument names
sau_get_arg_names() {
    local names=()
    for key in "${!SAU_ARG_CONFIG[@]}"; do
        if [[ "$key" =~ _short$ ]]; then
            names+=("${key%_short}")
        fi
    done
    printf '%s\n' "${names[@]}" | sort -u
}

# Parse command line arguments
sau_parse_args() {
    local args=("$@")
    local i=0
    
    while (( i < ${#args[@]} )); do
        local arg="${args[i]}"
        local matched=false
        
        # Check if it's a flag (starts with -)
        if [[ "$arg" =~ ^- ]]; then
            # Find matching argument configuration
            for name in $(sau_get_arg_names); do
                local short="${SAU_ARG_CONFIG[${name}_short]}"
                local long="${SAU_ARG_CONFIG[${name}_long]}"
                local has_value="${SAU_ARG_CONFIG[${name}_has_value]}"
                
                if [[ "$arg" == "-$short" ]] || [[ "$arg" == "--$long" ]]; then
                    matched=true
                    
                    if [[ "$has_value" == "true" ]]; then
                        # Argument expects a value
                        if (( i + 1 >= ${#args[@]} )) || [[ "${args[i+1]}" =~ ^- ]]; then
                            SAU_ARG_VALIDATION_ERRORS["$name"]="Option $arg requires a value"
                        else
                            i=$((i + 1))
                            SAU_ARG_VALUES["$name"]="${args[i]}"
                        fi
                    else
                        # Boolean flag
                        SAU_ARG_VALUES["$name"]="true"
                    fi
                    break
                fi
            done
            
            if [[ "$matched" == false ]]; then
                SAU_ARG_UNKNOWN+=("$arg")
            fi
        else
            # Positional argument
            SAU_ARG_POSITIONAL+=("$arg")
        fi
        
        i=$((i + 1))
    done
}

# Validate arguments
sau_validate_args() {
    local has_errors=false
    
    # Check for required arguments
    for name in $(sau_get_arg_names); do
        local required="${SAU_ARG_CONFIG[${name}_required]}"
        local validator="${SAU_ARG_CONFIG[${name}_validator]}"
        local value="${SAU_ARG_VALUES[$name]:-}"
        
        if [[ "$required" == "true" ]] && [[ -z "$value" ]]; then
            SAU_ARG_VALIDATION_ERRORS["$name"]="Required argument missing"
            has_errors=true
        elif [[ -n "$value" ]] && [[ -n "$validator" ]]; then
            # Run validation if value exists and validator is defined
            local error_msg
            case "$validator" in
                "file")
                    error_msg=$(sau_validate_file "$value")
                    ;;
                "dir")
                    error_msg=$(sau_validate_dir "$value")
                    ;;
                "int")
                    error_msg=$(sau_validate_int "$value")
                    ;;
                "email")
                    error_msg=$(sau_validate_email "$value")
                    ;;
                "url")
                    error_msg=$(sau_validate_url "$value")
                    ;;
                range:*)
                    local range_params="${validator#range:}"
                    IFS=':' read -r min max <<< "$range_params"
                    error_msg=$(sau_validate_range "$value" "$min" "$max")
                    ;;
                enum:*)
                    local enum_values="${validator#enum:}"
                    IFS=':' read -ra valid_values <<< "$enum_values"
                    error_msg=$(sau_validate_enum "$value" "${valid_values[@]}")
                    ;;
                *)
                    # Custom validator function
                    if declare -f "$validator" >/dev/null 2>&1; then
                        error_msg=$("$validator" "$value")
                    fi
                    ;;
            esac
            
            if [[ -n "$error_msg" ]]; then
                SAU_ARG_VALIDATION_ERRORS["$name"]="$error_msg"
                has_errors=true
            fi
        fi
    done
    
    return $([[ "$has_errors" == "true" ]] && echo 1 || echo 0)
}

# Get argument value
sau_get_arg() {
    local name="$1"
    echo "${SAU_ARG_VALUES[$name]:-}"
}

# Check if argument was provided
sau_has_arg() {
    local name="$1"
    [[ -n "${SAU_ARG_VALUES[$name]:-}" ]]
}

# Get positional arguments
sau_get_positional() {
    printf '%s\n' "${SAU_ARG_POSITIONAL[@]}"
}

# Get unknown arguments
sau_get_unknown() {
    printf '%s\n' "${SAU_ARG_UNKNOWN[@]}"
}

# Print validation errors
sau_print_validation_errors() {
    if [[ ${#SAU_ARG_VALIDATION_ERRORS[@]} -gt 0 ]]; then
        echo "Validation errors:" >&2
        for name in "${!SAU_ARG_VALIDATION_ERRORS[@]}"; do
            echo "  - ${SAU_ARG_VALIDATION_ERRORS[$name]}" >&2
        done
        return 1
    fi
    return 0
}

# Generate usage information (to be customized in main script)
sau_generate_usage_info() {
    local script_name="$1"
    echo "Usage: $script_name [OPTIONS]"
    echo
    echo "Options:"
    
    for name in $(sau_get_arg_names); do
        local short="${SAU_ARG_CONFIG[${name}_short]}"
        local long="${SAU_ARG_CONFIG[${name}_long]}"
        local desc="${SAU_ARG_CONFIG[${name}_desc]}"
        local required="${SAU_ARG_CONFIG[${name}_required]}"
        local has_value="${SAU_ARG_CONFIG[${name}_has_value]}"
        local default="${SAU_ARG_CONFIG[${name}_default]}"
        
        local flags="-$short, --$long"
        if [[ "$has_value" == "true" ]]; then
            flags="$flags VALUE"
        fi
        
        local req_marker=""
        if [[ "$required" == "true" ]]; then
            req_marker=" (required)"
        elif [[ -n "$default" ]]; then
            req_marker=" (default: $default)"
        fi
        
        printf "  %-20s %s%s\n" "$flags" "$desc" "$req_marker"
    done
}
