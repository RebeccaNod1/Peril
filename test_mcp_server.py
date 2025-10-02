#!/usr/bin/env python3
"""
Simple test script to verify the LSL MCP server is working
"""

import json
import subprocess
import sys

def test_mcp_server():
    """Test basic MCP server functionality"""
    
    # Test tools/list
    test_request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/list",
        "params": {}
    }
    
    try:
        # Start the MCP server process
        process = subprocess.Popen([
            'python3', '/home/richard/peril/lsl_mcp_server.py'
        ], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        
        # Send the request
        stdout, stderr = process.communicate(input=json.dumps(test_request) + '\n', timeout=10)
        
        print("=== MCP Server Test Results ===")
        print("\nServer Output:")
        for line in stdout.strip().split('\n'):
            if line.strip():
                try:
                    response = json.loads(line)
                    print(json.dumps(response, indent=2))
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
    test_mcp_server()