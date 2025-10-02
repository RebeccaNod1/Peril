#!/usr/bin/env python3
"""
LSL Development MCP Server for Peril Dice Project
Provides tools for LSL validation, preprocessing, and project management.
"""

import json
import sys
import subprocess
import os
import glob
from pathlib import Path
from typing import Dict, List, Any, Optional


class LSLMCPServer:
    def __init__(self, project_root: str = "/home/richard/peril"):
        self.project_root = Path(project_root)
        self.lsl_validator_path = self.project_root / "lsl_validator.py"
        
    def handle_request(self, request: Dict[str, Any]) -> Dict[str, Any]:
        """Handle incoming MCP requests"""
        method = request.get("method", "")
        params = request.get("params", {})
        
        if method == "initialize":
            return self._handle_initialize(params)
        elif method == "tools/list":
            return self._list_tools()
        elif method == "tools/call":
            return self._call_tool(params)
        elif method == "resources/list":
            return self._list_resources()
        elif method == "resources/read":
            return self._read_resource(params)
        else:
            return {"error": f"Unknown method: {method}"}
    
    def _handle_initialize(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Handle MCP initialization request"""
        # Use the client's protocol version if provided
        client_version = params.get("protocolVersion", "2024-11-05")
        return {
            "protocolVersion": client_version,
            "capabilities": {
                "tools": {},
                "resources": {}
            },
            "serverInfo": {
                "name": "LSL Development Server",
                "version": "1.0.0"
            }
        }
    
    def _list_tools(self) -> Dict[str, Any]:
        """List available LSL development tools"""
        return {
            "tools": [
                {
                    "name": "validate_lsl_file",
                    "description": "Comprehensive LSL validation for a specific file (syntax, scope, style, performance, memory)",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "file_path": {"type": "string", "description": "Path to LSL file to validate"}
                        },
                        "required": ["file_path"]
                    }
                },
                {
                    "name": "validate_all_lsl",
                    "description": "Comprehensive LSL validation for all files in the project",
                    "inputSchema": {
                        "type": "object",
                        "properties": {}
                    }
                },
                {
                    "name": "list_lsl_files",
                    "description": "List all LSL files in the project",
                    "inputSchema": {
                        "type": "object",
                        "properties": {}
                    }
                },
                {
                    "name": "git_status",
                    "description": "Get git status of the project",
                    "inputSchema": {
                        "type": "object",
                        "properties": {}
                    }
                },
                {
                    "name": "analyze_script_architecture",
                    "description": "Analyze the script architecture and communication patterns",
                    "inputSchema": {
                        "type": "object",
                        "properties": {}
                    }
                },
                {
                    "name": "get_memory_usage_info",
                    "description": "Extract memory usage information from LSL files",
                    "inputSchema": {
                        "type": "object",
                        "properties": {}
                    }
                }
            ]
        }
    
    def _call_tool(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Execute a specific tool"""
        tool_name = params.get("name", "")
        arguments = params.get("arguments", {})
        
        try:
            if tool_name == "validate_lsl_file":
                return self._validate_lsl_file(arguments["file_path"])
            elif tool_name == "validate_all_lsl":
                return self._validate_all_lsl()
            elif tool_name == "list_lsl_files":
                return self._list_lsl_files()
            elif tool_name == "git_status":
                return self._git_status()
            elif tool_name == "analyze_script_architecture":
                return self._analyze_script_architecture()
            elif tool_name == "get_memory_usage_info":
                return self._get_memory_usage_info()
            else:
                return {"error": f"Unknown tool: {tool_name}"}
        except Exception as e:
            return {"error": f"Tool execution failed: {str(e)}"}
    
    def _validate_lsl_file(self, file_path: str) -> Dict[str, Any]:
        """Validate a specific LSL file using the comprehensive LSL validator"""
        full_path = self.project_root / file_path if not os.path.isabs(file_path) else Path(file_path)
        
        if not full_path.exists():
            return {"error": f"File not found: {full_path}"}
        
        if not self.lsl_validator_path.exists():
            return {"error": f"LSL validator not found at: {self.lsl_validator_path}"}
        
        try:
            result = subprocess.run([
                "python3", str(self.lsl_validator_path), str(full_path)
            ], capture_output=True, text=True, cwd=str(self.project_root))
            
            return {
                "content": [
                    {
                        "type": "text",
                        "text": f"LSL Validation Result for {file_path}:\n\n"
                               f"Exit Code: {result.returncode}\n"
                               f"Output:\n{result.stdout}\n"
                               f"Errors:\n{result.stderr}"
                    }
                ]
            }
        except Exception as e:
            return {"error": f"Failed to run LSL validator: {str(e)}"}
    
    def _validate_all_lsl(self) -> Dict[str, Any]:
        """Validate all LSL files in the project using the comprehensive LSL validator"""
        if not self.lsl_validator_path.exists():
            return {"error": f"LSL validator not found at: {self.lsl_validator_path}"}
        
        try:
            result = subprocess.run([
                "python3", str(self.lsl_validator_path), "."
            ], capture_output=True, text=True, cwd=str(self.project_root))
            
            return {
                "content": [
                    {
                        "type": "text",
                        "text": f"LSL Validation Results for All Files:\n\n"
                               f"Exit Code: {result.returncode}\n\n"
                               f"Output:\n{result.stdout}\n"
                               f"Errors:\n{result.stderr}"
                    }
                ]
            }
        except Exception as e:
            return {"error": f"Failed to run LSL validator on all files: {str(e)}"}
    
    def _list_lsl_files(self) -> Dict[str, Any]:
        """List all LSL files in the project"""
        lsl_files = list(self.project_root.glob("*.lsl"))
        file_list = [f.name for f in sorted(lsl_files)]
        
        return {
            "content": [
                {
                    "type": "text",
                    "text": f"LSL Files in Project ({len(file_list)} total):\n\n" + 
                            "\n".join([f"• {f}" for f in file_list])
                }
            ]
        }
    
    def _git_status(self) -> Dict[str, Any]:
        """Get git status of the project"""
        try:
            result = subprocess.run([
                "git", "status", "--porcelain"
            ], capture_output=True, text=True, cwd=str(self.project_root))
            
            branch_result = subprocess.run([
                "git", "branch", "--show-current"
            ], capture_output=True, text=True, cwd=str(self.project_root))
            
            status_text = "Git Status:\n\n"
            status_text += f"Current Branch: {branch_result.stdout.strip()}\n\n"
            
            if result.stdout.strip():
                status_text += "Modified Files:\n"
                for line in result.stdout.strip().split('\n'):
                    status_text += f"  {line}\n"
            else:
                status_text += "Working directory clean\n"
            
            return {
                "content": [
                    {
                        "type": "text",
                        "text": status_text
                    }
                ]
            }
        except Exception as e:
            return {"error": f"Failed to get git status: {str(e)}"}
    
    def _analyze_script_architecture(self) -> Dict[str, Any]:
        """Analyze the script architecture"""
        lsl_files = list(self.project_root.glob("*.lsl"))
        
        architecture_info = "Peril Dice Script Architecture Analysis:\n\n"
        architecture_info += f"Total Scripts: {len(lsl_files)}\n\n"
        
        # Categorize scripts by type
        controllers = [f for f in lsl_files if "Controller" in f.name or "Manager" in f.name]
        handlers = [f for f in lsl_files if "Handler" in f.name]
        modules = [f for f in lsl_files if "Module" in f.name]
        linkset_scripts = [f for f in lsl_files if "Linkset" in f.name]
        
        architecture_info += f"Controllers/Managers ({len(controllers)}):\n"
        for script in controllers:
            architecture_info += f"  • {script.name}\n"
        
        architecture_info += f"\nHandlers ({len(handlers)}):\n"
        for script in handlers:
            architecture_info += f"  • {script.name}\n"
        
        architecture_info += f"\nModules ({len(modules)}):\n"
        for script in modules:
            architecture_info += f"  • {script.name}\n"
        
        architecture_info += f"\nLinkset-Specific Scripts ({len(linkset_scripts)}):\n"
        for script in linkset_scripts:
            architecture_info += f"  • {script.name}\n"
        
        return {
            "content": [
                {
                    "type": "text",
                    "text": architecture_info
                }
            ]
        }
    
    def _get_memory_usage_info(self) -> Dict[str, Any]:
        """Extract memory usage information from comments in LSL files"""
        lsl_files = list(self.project_root.glob("*.lsl"))
        memory_info = "Memory Usage Information:\n\n"
        
        for lsl_file in lsl_files:
            try:
                with open(lsl_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                    # Look for memory usage comments
                    lines = content.split('\n')
                    memory_lines = [line for line in lines if 'memory' in line.lower() and ('%' in line or 'usage' in line.lower())]
                    
                    if memory_lines:
                        memory_info += f"{lsl_file.name}:\n"
                        for line in memory_lines:
                            memory_info += f"  {line.strip()}\n"
                        memory_info += "\n"
            except Exception:
                continue
        
        return {
            "content": [
                {
                    "type": "text",
                    "text": memory_info if memory_info.strip() != "Memory Usage Information:" else "No memory usage information found in comments."
                }
            ]
        }
    
    def _list_resources(self) -> Dict[str, Any]:
        """List available project resources"""
        return {
            "resources": [
                {
                    "uri": "file:///home/richard/peril/README.md",
                    "name": "Project README",
                    "description": "Main project documentation",
                    "mimeType": "text/markdown"
                },
                {
                    "uri": "file:///home/richard/peril/CHANGELOG.md", 
                    "name": "Changelog",
                    "description": "Project changelog",
                    "mimeType": "text/markdown"
                },
                {
                    "uri": "file:///home/richard/peril/WARP.md",
                    "name": "WARP Development Guide",
                    "description": "Development guidance for WARP",
                    "mimeType": "text/markdown"
                }
            ]
        }
    
    def _read_resource(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Read a specific resource"""
        uri = params.get("uri", "")
        
        if uri.startswith("file://"):
            file_path = Path(uri[7:])  # Remove file:// prefix
            
            if not file_path.exists():
                return {"error": f"File not found: {file_path}"}
            
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                return {
                    "contents": [
                        {
                            "uri": uri,
                            "mimeType": "text/markdown" if file_path.suffix == ".md" else "text/plain",
                            "text": content
                        }
                    ]
                }
            except Exception as e:
                return {"error": f"Failed to read file: {str(e)}"}
        
        return {"error": f"Unsupported URI: {uri}"}


def main():
    """Main server loop"""
    server = LSLMCPServer()
    
    try:
        # Read requests from stdin continuously
        while True:
            try:
                line = sys.stdin.readline()
                if not line:  # EOF
                    break
                    
                line = line.strip()
                if not line:
                    continue
                    
                request = json.loads(line)
                response = server.handle_request(request)
                
                # Wrap response in proper JSON-RPC format
                json_rpc_response = {
                    "jsonrpc": "2.0",
                    "id": request.get("id", None)
                }
                
                if "error" in response:
                    json_rpc_response["error"] = response["error"]
                else:
                    json_rpc_response["result"] = response
                    
                print(json.dumps(json_rpc_response))
                sys.stdout.flush()  # Ensure immediate output
                
            except json.JSONDecodeError:
                error_response = {
                    "jsonrpc": "2.0",
                    "error": {"code": -32700, "message": "Parse error"},
                    "id": None
                }
                print(json.dumps(error_response))
                sys.stdout.flush()
            except Exception as e:
                error_response = {
                    "jsonrpc": "2.0", 
                    "error": {"code": -32603, "message": str(e)},
                    "id": None
                }
                print(json.dumps(error_response))
                sys.stdout.flush()
    except KeyboardInterrupt:
        pass
    except EOFError:
        pass


if __name__ == "__main__":
    main()