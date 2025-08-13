#!/usr/bin/env python3
import json
import os

# Create a large JSON object
large_json = {
    "name": "Large Test JSON",
    "version": 1.0,
    "description": "A large JSON file for testing file size validation",
    "items": []
}

# Add many items to make the file larger than 1 MB
for i in range(50000):
    large_json["items"].append({
        "id": i,
        "value": f"item_{i}" * 20  # Repeat the string to make it larger
    })

# Write to file
with open('large.json', 'w') as f:
    json.dump(large_json, f)

# Verify file size
file_size = os.path.getsize('large.json')
print(f"Created large.json with size: {file_size} bytes ({file_size / 1024 / 1024:.2f} MB)")