#!/usr/bin/env python3
import sys
import json
import traceback

def debug_main():
    """Debug version to see what's happening"""
    print('{"debug": "server started"}', flush=True)
    
    try:
        while True:
            line = sys.stdin.readline()
            print(f'{{"debug": "received line: {line.strip()[:100]}"}}', flush=True)
            
            if not line:
                print('{"debug": "EOF received, exiting"}', flush=True)
                break
                
            line = line.strip()
            if not line:
                continue
                
            try:
                request = json.loads(line)
                print(f'{{"debug": "parsed request: {request.get("method", "unknown")}"}}', flush=True)
                
                if request.get("method") == "initialize":
                    response = {
                        "jsonrpc": "2.0",
                        "id": request.get("id"),
                        "result": {
                            "protocolVersion": "2025-03-26",
                            "capabilities": {"tools": {}, "resources": {}},
                            "serverInfo": {"name": "Debug LSL Server", "version": "1.0.0"}
                        }
                    }
                    print(json.dumps(response), flush=True)
                    print('{"debug": "sent initialize response"}', flush=True)
                
            except Exception as e:
                print(f'{{"debug": "error parsing: {str(e)}"}}', flush=True)
                
    except Exception as e:
        print(f'{{"debug": "main loop error: {str(e)}"}}', flush=True)
        traceback.print_exc(file=sys.stderr)
    
    print('{"debug": "server exiting"}', flush=True)

if __name__ == "__main__":
    debug_main()