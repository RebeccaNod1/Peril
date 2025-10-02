# LSL Development MCP Server

This MCP (Model Context Protocol) server provides AI assistants with direct access to your LSL development tools and Peril Dice project.

## What it provides

### Available Tools:
1. **lint_lsl_file** - Lint/validate LSL syntax for a specific file using lslint
2. **lint_all_lsl** - Lint/validate all LSL files in the project using lslint
3. **list_lsl_files** - List all LSL files in the project (currently shows 20 files)
4. **git_status** - Get git status of the project
5. **analyze_script_architecture** - Analyze script architecture and communication patterns
6. **get_memory_usage_info** - Extract memory usage information from LSL files

### Available Resources:
- Project README.md
- CHANGELOG.md
- WARP.md (development guide)

## Files Created:
- `lsl_mcp_server.py` - The main MCP server
- `mcp_config.json` - Configuration for MCP clients
- `test_mcp_server.py` - Test script to verify server functionality

## How to Use:

### Testing the Server:
```bash
python3 test_mcp_server.py
```

### Manual Server Start:
```bash
python3 lsl_mcp_server.py
```

### Integration with AI Tools:
The `mcp_config.json` file can be used to configure MCP-compatible AI tools to connect to this server.

## Benefits:

With this MCP server, AI assistants can:
- Directly lint and validate your LSL code using lslint
- List and examine all 20 LSL files in your Peril project
- Check git status and project state
- Analyze your script architecture (Controllers, Handlers, Modules, Linkset scripts)
- Access project documentation
- Monitor memory usage information from script comments

This creates a much more interactive and helpful development experience, where the AI can actually run your development tools and provide real-time feedback on your Peril Dice project.

## Security:

The server only has access to:
- Your Peril project directory (`/home/richard/peril`)
- Your lslint tool (`/home/richard/lslint/lslint`)
- Git commands within the project directory
- Read-only access to project documentation

It cannot modify files outside the project scope or execute arbitrary system commands.