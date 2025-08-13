#!/usr/bin/env python3
import sys
import os
import re
import logging
import datetime
from pathlib import Path

# Configure logging
def setup_logging():
    """
    Configure logging for the script.
    Sets up logging to both console and a log file.
    """
    # Create logs directory if it doesn't exist
    script_dir = Path(__file__).parent.absolute()
    log_dir = script_dir / "logs"
    log_dir.mkdir(exist_ok=True)
    
    # Create log filename with timestamp
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = log_dir / f"paas_reporter_{timestamp}.log"
    
    # Configure logging
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)
    
    # File handler (all logs)
    file_handler = logging.FileHandler(log_file)
    file_handler.setLevel(logging.DEBUG)
    file_format = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    file_handler.setFormatter(file_format)
    
    # Console handler (info and above)
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_format = logging.Formatter('%(levelname)s: %(message)s')
    console_handler.setFormatter(console_format)
    
    # Add handlers to logger
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    
    logging.info(f"Logging initialized. Log file: {log_file}")
    return logger

# Initialize logging
logger = setup_logging()

def validate_absolute_path(filepath):
    """
    Validate that a filepath is an absolute path.
    
    Args:
        filepath (str): Path to validate
        
    Returns:
        bool: True if filepath is an absolute path, False otherwise
    """
    logging.debug(f"Validating absolute path: '{filepath}'")
    if not os.path.isabs(filepath):
        logging.error(f"File path '{filepath}' is not an absolute path")
        print(f"Error: File path '{filepath}' is not an absolute path.")
        return False
    logging.debug(f"Path '{filepath}' is absolute")
    return True

def validate_file_size(filepath, max_size_bytes=1048576):  # 1 MB = 1048576 bytes
    """
    Validate that a file's size is less than the specified maximum size.
    
    Args:
        filepath (str): Path to the file to validate
        max_size_bytes (int): Maximum allowed file size in bytes (default: 1 MB)
        
    Returns:
        bool: True if file size is less than max_size_bytes, False otherwise
    """
    logging.debug(f"Validating file size for '{filepath}', max size: {max_size_bytes} bytes")
    try:
        file_size = os.path.getsize(filepath)
        logging.debug(f"File '{filepath}' size: {file_size} bytes")
        if file_size > max_size_bytes:
            logging.error(f"File '{filepath}' exceeds the maximum allowed size of 1 MB. File size: {file_size} bytes")
            print(f"Error: File '{filepath}' exceeds the maximum allowed size of 1 MB. File size: {file_size} bytes.")
            return False
        logging.debug(f"File '{filepath}' size is within limits")
        return True
    except OSError as e:
        logging.error(f"Error checking file size for '{filepath}': {e}")
        print(f"Error checking file size for '{filepath}': {e}")
        return False

def basic_yaml_syntax_check(content):
    """
    Perform a basic syntax check for YAML content.
    
    Args:
        content (str): YAML content to validate
        
    Returns:
        tuple: (is_valid, error_message)
    """
    logging.debug("Starting YAML syntax check")
    lines = content.split('\n')
    indentation_stack = []
    current_indent = 0
    
    for line_num, line in enumerate(lines, 1):
        # Skip empty lines and comments
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        
        # Check indentation
        indent = len(line) - len(line.lstrip())
        
        # Check for common YAML syntax errors
        if ':' not in line and not line.strip().startswith('-'):
            if line.strip() and not line.strip().startswith('#'):
                error_msg = f"Line {line_num}: Missing colon in key-value pair or not a list item"
                logging.error(f"YAML syntax error: {error_msg}")
                return False, error_msg
        
        # Check for invalid characters in keys
        if ':' in line:
            key = line.split(':', 1)[0].strip()
            if re.search(r'[^\w\s-]', key):  # Keys should only contain word chars, spaces, and hyphens
                error_msg = f"Line {line_num}: Invalid character in key '{key}'"
                logging.error(f"YAML syntax error: {error_msg}")
                return False, error_msg
        
        # Check for tab characters (YAML doesn't allow tabs)
        if '\t' in line:
            error_msg = f"Line {line_num}: Tab character found (YAML uses spaces for indentation)"
            logging.error(f"YAML syntax error: {error_msg}")
            return False, error_msg
        
        # Check for inconsistent indentation
        if indent > current_indent:
            indentation_stack.append(current_indent)
            current_indent = indent
        elif indent < current_indent:
            if indent not in indentation_stack:
                error_msg = f"Line {line_num}: Inconsistent indentation"
                logging.error(f"YAML syntax error: {error_msg}")
                return False, error_msg
            while indentation_stack and indent < current_indent:
                current_indent = indentation_stack.pop()
            if indent != current_indent:
                error_msg = f"Line {line_num}: Inconsistent indentation"
                logging.error(f"YAML syntax error: {error_msg}")
                return False, error_msg
    
    logging.debug("YAML syntax check completed successfully")
    return True, ""

def validate_yaml_file(filepath):
    """
    Validate that a file exists and contains valid YAML.
    
    Args:
        filepath (str): Path to the file to validate
        
    Returns:
        bool: True if file exists and contains valid YAML, False otherwise
    """
    logging.info(f"Validating YAML file: '{filepath}'")
    
    # Check if file path is absolute
    if not validate_absolute_path(filepath):
        logging.warning(f"Validation failed: '{filepath}' is not an absolute path")
        return False
        
    # Check if file exists
    if not os.path.isfile(filepath):
        logging.error(f"Validation failed: File '{filepath}' does not exist")
        print(f"Error: File '{filepath}' does not exist.")
        return False
    
    # Check if file size is less than 1 MB
    if not validate_file_size(filepath):
        logging.warning(f"Validation failed: File '{filepath}' exceeds size limit")
        return False
    
    # Try to read and parse the file as YAML
    try:
        logging.debug(f"Reading file: '{filepath}'")
        with open(filepath, 'r', encoding='utf-8') as file:
            content = file.read()
            logging.debug(f"File read successfully, performing YAML syntax check")
            is_valid, error_message = basic_yaml_syntax_check(content)
            
            if is_valid:
                logging.info(f"Validation successful: '{filepath}' is a valid YAML file")
                print(f"Success: '{filepath}' is a valid YAML file.")
                return True
            else:
                logging.error(f"Validation failed: '{filepath}' is not a valid YAML file: {error_message}")
                print(f"Error: '{filepath}' is not a valid YAML file: {error_message}")
                return False
    except Exception as e:
        logging.error(f"Error reading file '{filepath}': {e}")
        print(f"Error reading file '{filepath}': {e}")
        return False

def main():
    logging.info("Script started")
    
    # Check if a filename was provided
    if len(sys.argv) != 2:
        logging.error("No input filename provided")
        print("Usage: python commands/paas_reporter.py <filename>")
        sys.exit(1)
    
    input_filename = sys.argv[1]
    logging.info(f"Input filename: '{input_filename}'")
    
    # Check if the input file exists
    if not os.path.isfile(input_filename):
        logging.error(f"Input file '{input_filename}' does not exist")
        print(f"Error: Input file '{input_filename}' does not exist.")
        sys.exit(1)
    
    # Read the input file line by line
    success_count = 0
    error_count = 0
    
    logging.info(f"Processing file: '{input_filename}'")
    print(f"Processing file: {input_filename}")
    print("-" * 50)
    
    try:
        with open(input_filename, 'r', encoding='utf-8') as file:
            logging.debug(f"File '{input_filename}' opened successfully")
            file_lines = file.readlines()
            logging.info(f"Read {len(file_lines)} lines from '{input_filename}'")
            
            for line_number, line in enumerate(file_lines, 1):
                # Strip whitespace
                filepath = line.strip()
                
                # Skip empty lines
                if not filepath:
                    logging.debug(f"Line {line_number}: Empty line, skipping")
                    continue
                
                logging.info(f"Processing line {line_number}: '{filepath}'")
                print(f"Line {line_number}: {filepath}")
                
                if validate_yaml_file(filepath):
                    logging.info(f"Validation successful for '{filepath}'")
                    success_count += 1
                else:
                    logging.warning(f"Validation failed for '{filepath}'")
                    error_count += 1
                print("-" * 50)
    except FileNotFoundError:
        logging.error(f"Could not find file '{input_filename}'")
        print(f"Error: Could not find file '{input_filename}'")
        sys.exit(1)
    except PermissionError:
        logging.error(f"No permission to read file '{input_filename}'")
        print(f"Error: No permission to read file '{input_filename}'")
        sys.exit(1)
    except UnicodeDecodeError:
        logging.error(f"File '{input_filename}' contains invalid UTF-8 characters")
        print(f"Error: File '{input_filename}' contains invalid UTF-8 characters")
        sys.exit(1)
    except Exception as e:
        logging.error(f"Failed to process file '{input_filename}': {e}", exc_info=True)
        print(f"Error: Failed to process file '{input_filename}': {e}")
        sys.exit(1)
    
    # Print summary
    logging.info(f"Processing completed. Summary: {success_count} valid YAML files, {error_count} errors")
    print(f"Summary: {success_count} valid YAML files, {error_count} errors")
    
    logging.info("Script completed successfully")

if __name__ == "__main__":
    main()