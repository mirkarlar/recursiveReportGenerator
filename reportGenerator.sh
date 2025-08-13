#!/bin/bash

# Command constants
ECHO=/bin/echo
AWK=/usr/bin/awk
FIND=/usr/bin/find
DATE=/bin/date
MKDIR=/bin/mkdir

# Default values
FILEPATTERN=""
NEWER_THAN=""
COMMAND=""
VALIDATED_COMMAND=""
PATH_DIR="."
COLLATOR="/usr/bin/cat"
VALIDATED_COLLATOR=""
LOG_DIR="logs"
LOG_FILE=""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create logs directory if it doesn't exist
$MKDIR -p "$SCRIPT_DIR/$LOG_DIR"

# Set log file name with timestamp
LOG_FILE="$SCRIPT_DIR/$LOG_DIR/reportGenerator_$(date +%Y%m%d_%H%M%S).log"

# Logging functions
log_info() {
    local message="$1"
    local timestamp=$($DATE "+%Y-%m-%d %H:%M:%S")
    $ECHO "[$timestamp] [INFO] $message" >> "$LOG_FILE"
    $ECHO "[INFO] $message"
}

log_error() {
    local message="$1"
    local timestamp=$($DATE "+%Y-%m-%d %H:%M:%S")
    $ECHO "[$timestamp] [ERROR] $message" >> "$LOG_FILE"
    $ECHO "[ERROR] $message" >&2
}

log_debug() {
    local message="$1"
    local timestamp=$($DATE "+%Y-%m-%d %H:%M:%S")
    $ECHO "[$timestamp] [DEBUG] $message" >> "$LOG_FILE"
}

log_warning() {
    local message="$1"
    local timestamp=$($DATE "+%Y-%m-%d %H:%M:%S")
    $ECHO "[$timestamp] [WARNING] $message" >> "$LOG_FILE"
    $ECHO "[WARNING] $message" >&2
}

# Log script start
log_info "Script started: $0 $*"

# Function to display usage information
usage() {
    $ECHO "Usage: $0 [options]"
    $ECHO "Options:"
    $ECHO "  -f, --filepattern PATTERN   File pattern to match"
    $ECHO "  -n, --newerthan DATETIME    Files newer than specified datetime"
    $ECHO "  -c, --command COMMAND       Command to execute (must be executable in commands/ directory or in allowed directories)"
    $ECHO "  -o, --collator COMMAND      Command to process the output (default: /usr/bin/cat)"
    $ECHO "  -p, --path PATH             Path to search (default: current directory)"
    $ECHO "  -h, --help                  Display this help message"
    exit 1
}

# Global variable to store validated command path
VALIDATED_CMD_PATH=""

# Function to validate and locate the command
validate_command() {
    local cmd="$1"
    VALIDATED_CMD_PATH=""
    
    log_debug "Validating command: '$cmd'"
    
    # Allowed directories for executables
    local allowed_dirs=("/bin/" "/usr/bin/" "/usr/local/bin/" "/usr/opt/bin/")
    
    # Check if it's an absolute path and executable
    if [[ "$cmd" == /* ]] && [[ -x "$cmd" ]]; then
        log_debug "Command '$cmd' is an absolute path and executable"
        # Check if the command is in one of the allowed directories
        local is_allowed=0
        for dir in "${allowed_dirs[@]}"; do
            if [[ "$cmd" == "$dir"* ]]; then
                is_allowed=1
                log_debug "Command '$cmd' is in allowed directory: $dir"
                break
            fi
        done
        
        if [[ $is_allowed -eq 1 ]]; then
            VALIDATED_CMD_PATH="$cmd"
            log_info "Command '$cmd' is valid"
            return 0
        else
            log_error "Command '$cmd' is not in an allowed directory"
            $ECHO "Error: Command '$cmd' is not in an allowed directory." >&2
            $ECHO "Allowed directories are: ${allowed_dirs[*]}" >&2
            return 1
        fi
    fi

    # Check in commands subdirectory relative to the script
    if [[ -x "$SCRIPT_DIR/commands/$cmd" ]]; then
        VALIDATED_CMD_PATH="$SCRIPT_DIR/commands/$cmd"
        log_info "Command '$cmd' found in commands directory: $VALIDATED_CMD_PATH"
        return 0
    fi

    # Command not found or not executable
    log_error "Command '$cmd' not found or not executable in allowed locations"
    $ECHO "Error: Command '$cmd' not found or not executable in allowed locations." >&2
    $ECHO "Command must be in commands/ directory relative to this script or in one of these directories: ${allowed_dirs[*]}" >&2
    return 1
}

# Parse command line options
while getopts ":f:n:c:o:p:h-:" opt; do
    case $opt in
        f)
            FILEPATTERN="$OPTARG"
            ;;
        n)
            NEWER_THAN="$OPTARG"
            ;;
        c)
            COMMAND="$OPTARG"
            ;;
        o)
            COLLATOR="$OPTARG"
            ;;
        p)
            PATH_DIR="$OPTARG"
            ;;
        h)
            usage
            ;;
        -)
            case "${OPTARG}" in
                filepattern)
                    FILEPATTERN="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                newerthan)
                    NEWER_THAN="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                command)
                    COMMAND="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                collator)
                    COLLATOR="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                path)
                    PATH_DIR="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                help)
                    usage
                    ;;
                *)
                    $ECHO "Invalid option: --${OPTARG}" >&2
                    usage
                    ;;
            esac
            ;;
        \?)
            $ECHO "Invalid option: -$OPTARG" >&2
            usage
            ;;
        :)
            $ECHO "Option -$OPTARG requires an argument." >&2
            usage
            ;;
    esac
done

# Display parsed options
$ECHO "Script configuration:"
$ECHO "  File pattern: $FILEPATTERN"
$ECHO "  Newer than: $NEWER_THAN"
$ECHO "  Command: $COMMAND"
$ECHO "  Collator: $COLLATOR"
$ECHO "  Path: $PATH_DIR"

# Log configuration
log_info "Script configuration: FILEPATTERN='$FILEPATTERN', NEWER_THAN='$NEWER_THAN', COMMAND='$COMMAND', COLLATOR='$COLLATOR', PATH_DIR='$PATH_DIR'"

# Validate required parameters
if [ -z "$FILEPATTERN" ]; then
    log_error "File pattern is required"
    $ECHO "Error: File pattern is required." >&2
    usage
fi

# Validate command if provided
if [ -n "$COMMAND" ]; then
    log_info "Validating command: '$COMMAND'"
    # Extract the command name (first word before any arguments)
    CMD_NAME=$($ECHO "$COMMAND" | $AWK '{print $1}')
    CMD_ARGS=$($ECHO "$COMMAND" | $AWK '{$1=""; print $0}')
    log_debug "Command name: '$CMD_NAME', arguments: '$CMD_ARGS'"

    # Validate the command
    if ! validate_command "$CMD_NAME"; then
        log_error "Command validation failed for '$CMD_NAME'"
        exit 1
    fi

    # Get the validated command path from the global variable
    VALIDATED_COMMAND="$VALIDATED_CMD_PATH$CMD_ARGS"

    log_info "Using validated command: '$VALIDATED_COMMAND'"
    $ECHO "Using validated command: $VALIDATED_COMMAND"
fi

# Validate collator command
if [ -n "$COLLATOR" ]; then
    log_info "Validating collator: '$COLLATOR'"
    # Extract the collator command name (first word before any arguments)
    COLLATOR_NAME=$($ECHO "$COLLATOR" | $AWK '{print $1}')
    COLLATOR_ARGS=$($ECHO "$COLLATOR" | $AWK '{$1=""; print $0}')
    log_debug "Collator name: '$COLLATOR_NAME', arguments: '$COLLATOR_ARGS'"

    # Validate the collator command
    if ! validate_command "$COLLATOR_NAME"; then
        log_error "Collator validation failed for '$COLLATOR_NAME'"
        exit 1
    fi

    # Get the validated collator command path from the global variable
    VALIDATED_COLLATOR="$VALIDATED_CMD_PATH$COLLATOR_ARGS"

    log_info "Using validated collator: '$VALIDATED_COLLATOR'"
    $ECHO "Using validated collator: $VALIDATED_COLLATOR"
fi

# Create temporary files to store find results and process output
TEMP_FILE=$(mktemp)
OUTPUT_FILE=$(mktemp)
log_debug "Created temporary files: TEMP_FILE='$TEMP_FILE', OUTPUT_FILE='$OUTPUT_FILE'"

# Trap to ensure temp files are removed on exit
trap 'log_debug "Removing temporary files"; rm -f "$TEMP_FILE" "$OUTPUT_FILE"; log_info "Script completed"' EXIT

# Function to process files from the temp file and save output to another temp file
process_files() {
    local temp_file="$1"
    local output_file="$2"
    local file_count=0
    local processed_count=0
    
    log_info "Starting file processing"
    
    # Count the number of files to process
    file_count=$(wc -l < "$temp_file")
    log_info "Found $file_count files to process"
    
    while read -r file; do
        log_debug "Processing file: '$file'"
        if [ -n "$VALIDATED_COMMAND" ]; then
            # Execute validated command on each file without eval and redirect to output file
            log_debug "Executing command: $VALIDATED_COMMAND '$file'"
            if $VALIDATED_COMMAND "$file" >> "$output_file" 2>> "$LOG_FILE"; then
                log_debug "Command executed successfully on '$file'"
                processed_count=$((processed_count + 1))
            else
                log_error "Command execution failed on '$file'"
            fi
        else
            # Just print the file to output file
            $ECHO "$file" >> "$output_file"
            log_debug "Added file path to output: '$file'"
            processed_count=$((processed_count + 1))
        fi
    done < "$temp_file"
    
    log_info "File processing completed. Processed $processed_count of $file_count files"
}

# Store find results in temporary file
log_info "Finding files matching pattern '$FILEPATTERN' in directory '$PATH_DIR'"
if [ -n "$NEWER_THAN" ]; then
    # Find files matching pattern and newer than specified date
    log_debug "Using newer-than filter: '$NEWER_THAN'"
    $FIND "$PATH_DIR" -name "$FILEPATTERN" -newermt "$NEWER_THAN" -type f > "$TEMP_FILE"
else
    # Find files matching pattern without date restriction
    $FIND "$PATH_DIR" -name "$FILEPATTERN" -type f > "$TEMP_FILE"
fi

# Count found files
FOUND_FILES=$(wc -l < "$TEMP_FILE")
log_info "Found $FOUND_FILES files matching pattern '$FILEPATTERN'"

# Process the files from the temporary file and save output to another temp file
process_files "$TEMP_FILE" "$OUTPUT_FILE"

# If no collator was provided, use the default
if [ -z "$VALIDATED_COLLATOR" ]; then
    VALIDATED_COLLATOR="/usr/bin/cat"
    log_debug "Using default collator: '$VALIDATED_COLLATOR'"
fi

# Execute the collator command on the output file
log_info "Executing collator command: '$VALIDATED_COLLATOR' on output file"
if $VALIDATED_COLLATOR "$OUTPUT_FILE"; then
    log_info "Collator executed successfully"
else
    log_error "Collator execution failed"
    exit 1
fi

log_info "Script execution completed successfully"
