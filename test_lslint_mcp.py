#!/usr/bin/env python3
"""
Test script to verify lslint functionality with MCP server
"""

import json
import subprocess
import sys

def test_lslint_functionality():
    """Test lslint functionality through MCP server"""
    
    # Test list_lsl_files first
    list_request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {
            "name": "list_lsl_files",
            "arguments": {}
        }
    }
    
    try:
        # Start the MCP server process
        process = subprocess.Popen([
            'python3', '/home/richard/peril/lsl_mcp_server.py'
        ], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        
        # Send the request
        stdout, stderr = process.communicate(input=json.dumps(list_request) + '\n', timeout=10)
        
        print("=== LSL MCP Server - LSLint Test ===")
        print("\nListing LSL Files:")
        
        lines = stdout.strip().split('\n')
        for line in lines:
            if line.strip():
                try:
                    response = json.loads(line)
                    if 'content' in response:
                        print(response['content'][0]['text'])
                    elif 'tools' in response:
                        print("Server initialized successfully")
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
    test_lslint_functionality()