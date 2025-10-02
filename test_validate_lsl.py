#!/usr/bin/env python3
"""
Test script to validate a specific LSL file using the comprehensive validator
"""

import json
import subprocess
import sys

def test_validate_lsl():
    """Test LSL validation through MCP server"""
    
    # Test validate_lsl_file with Main_Controller_Linkset.lsl
    validate_request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {
            "name": "validate_lsl_file",
            "arguments": {
                "file_path": "Main_Controller_Linkset.lsl"
            }
        }
    }
    
    try:
        # Start the MCP server process
        process = subprocess.Popen([
            'python3', '/home/richard/peril/lsl_mcp_server.py'
        ], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        
        # Send the request
        stdout, stderr = process.communicate(input=json.dumps(validate_request) + '\n', timeout=15)
        
        print("=== LSL Comprehensive Validation Test ===")
        print("\nValidating Main_Controller_Linkset.lsl:")
        
        lines = stdout.strip().split('\n')
        for line in lines:
            if line.strip():
                try:
                    response = json.loads(line)
                    if 'content' in response:
                        print(response['content'][0]['text'])
                    elif 'method' in response and response['method'] == 'server/initialized':
                        print("✅ Server initialized successfully")
                except json.JSONDecodeError:
                    print(f"Non-JSON output: {line}")
        
        if stderr:
            print(f"\nServer Errors:\n{stderr}")
        
        print("\n=== Test Complete ===")
        
    except subprocess.TimeoutExpired:
        print("Server test timed out")
        process.kill()
    except Exception as e:
        print(f"Test failed: {e}")

if __name__ == "__main__":
    test_validate_lsl()