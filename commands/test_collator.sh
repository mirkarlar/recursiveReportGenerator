#!/bin/bash

# Simple test collator script for reportGenerator.sh
echo "=== TEST COLLATOR OUTPUT ==="
echo "Processing file: $1"
echo "=== FILE CONTENT ==="
cat "$1"
echo "=== END OF CONTENT ==="
echo "=== END OF TEST COLLATOR OUTPUT ==="