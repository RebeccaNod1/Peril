#!/usr/bin/env python3
"""
LSL Validator - Simple syntax and style checker for Linden Scripting Language files
Created for the Peril Dice Game project

Usage:
    python3 lsl_validator.py filename.lsl      # Validate single file
    python3 lsl_validator.py .                 # Validate all .lsl files in directory
    python3 lsl_validator.py /path/to/dir      # Validate all .lsl files in specified directory
"""

import os
import sys
import re
import glob
from pathlib import Path

class LSLValidator:
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.info = []
        
        # Common LSL functions and constants for basic validation
        self.lsl_functions = {
            # State management
            'default', 'state_entry', 'state_exit', 'on_rez',
            # Events
            'touch_start', 'touch_end', 'listen', 'timer', 'link_message',
            'collision_start', 'collision', 'collision_end', 'http_response',
            'sensor', 'no_sensor', 'control', 'land_collision_start', 'land_collision', 
            'land_collision_end', 'at_target', 'not_at_target', 'at_rot_target', 
            'not_at_rot_target', 'money', 'email', 'run_time_permissions', 'changed', 
            'attach', 'dataserver', 'moving_start', 'moving_end', 'transaction_result', 
            'path_update', 'remote_data',
            # String functions
            'llStringLength', 'llGetSubString', 'llSubStringIndex', 'llToUpper', 'llToLower',
            'llMD5String', 'llSHA1String', 'llEscapeURL', 'llUnescapeURL',
            # List functions  
            'llGetListLength', 'llList2String', 'llList2Integer', 'llList2Float', 'llList2Key',
            'llList2Vector', 'llList2Rot', 'llDeleteSubList', 'llListReplaceList',
            'llListFindList', 'llListInsertList', 'llCSV2List', 'llList2CSV',
            'llParseString2List', 'llDumpList2String', 'llParseStringKeepNulls',
            # Communication
            'llSay', 'llWhisper', 'llShout', 'llRegionSay', 'llOwnerSay',
            'llListen', 'llListenRemove', 'llDialog', 'llMessageLinked',
            # Object functions
            'llSetText', 'llSetTexture', 'llGetTexture', 'llSetAlpha', 'llGetAlpha',
            'llSetColor', 'llGetColor', 'llSetScale', 'llGetScale',
            'llSetPos', 'llGetPos', 'llSetRot', 'llGetRot',
            # Avatar functions
            'llKey2Name', 'llGetDisplayName', 'llRequestDisplayName',
            'llGetOwner', 'llDetectedKey', 'llDetectedName', 'llGetAgentSize',
            # Time functions
            'llGetUnixTime', 'llGetTimestamp', 'llSleep', 'llSetTimerEvent',
            # Memory functions
            'llGetUsedMemory', 'llGetFreeMemory', 'llResetScript',
            # Math functions
            'llAbs', 'llCeil', 'llFloor', 'llRound', 'llSqrt', 'llPow',
            'llSin', 'llCos', 'llTan', 'llAsin', 'llAcos', 'llAtan2',
            'llFrand', 'llGenerateKey',
            # Type conversion
            '(string)', '(integer)', '(float)', '(key)', '(vector)', '(rotation)',
        }
        
        self.lsl_constants = {
            'TRUE', 'FALSE', 'NULL_KEY', 'EOF', 'ZERO_VECTOR', 'ZERO_ROTATION',
            'PI', 'PI_BY_TWO', 'TWO_PI', 'DEG_TO_RAD', 'RAD_TO_DEG',
            'LINK_ROOT', 'LINK_SET', 'LINK_ALL_OTHERS', 'LINK_ALL_CHILDREN', 'LINK_THIS',
        }
        
        # Keywords that are definitely forbidden in LSL (conservative list)
        self.forbidden_keywords = {
            'break', 'continue', 'switch', 'case', 'goto', 
            'class', 'struct', 'enum', 'union', 'namespace'
        }
        
        # LSL data types
        self.lsl_types = {
            'integer', 'float', 'string', 'key', 'vector', 'rotation', 'list'
        }
        
        # Scope tracking for variables
        self.global_vars = set()  # Global variables
        self.local_vars = []      # Stack of local scopes
        self.current_function = None

    def validate_file(self, filepath):
        """Validate a single LSL file"""
        self.errors = []
        self.warnings = []  
        self.info = []
        
        try:
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                lines = content.split('\n')
                
            self._check_syntax(lines, filepath)
            self._check_style(lines, filepath)
            self._check_scope(lines, filepath)
            self._check_performance(content, filepath)
            self._check_memory_usage(content, filepath)
            
            return self._generate_report(filepath)
            
        except FileNotFoundError:
            return f"❌ ERROR: File not found: {filepath}"
        except Exception as e:
            return f"❌ ERROR: Failed to validate {filepath}: {str(e)}"

    def _check_syntax(self, lines, filepath):
        """Check for basic syntax errors"""
        brace_count = 0
        paren_count = 0
        in_string = False
        in_comment = False
        
        for line_num, line in enumerate(lines, 1):
            original_line = line
            line = line.strip()
            
            # Skip empty lines
            if not line:
                continue
                
            # Track multi-line comments
            if '/*' in line and '*/' not in line:
                in_comment = True
                continue
            elif '*/' in line and in_comment:
                in_comment = False
                continue
            elif in_comment:
                continue
                
            # Skip single-line comments
            if line.startswith('//'):
                continue
                
            # Check for common syntax errors
            if line.endswith(';') and line.count(';') > 1:
                if not any(keyword in line for keyword in ['for', 'if', 'while']):
                    self.warnings.append(f"Line {line_num}: Multiple statements on one line")
                    
            # Check brace balance
            brace_count += line.count('{') - line.count('}')
            if brace_count < 0:
                self.errors.append(f"Line {line_num}: Unmatched closing brace")
                
            # Check parentheses balance  
            paren_count += line.count('(') - line.count(')')
            
            # Check for missing semicolons (basic check)
            if (line.endswith(')') and not line.startswith('if') and not line.startswith('while') 
                and not line.startswith('for') and not line.endswith(');') and '{' not in line 
                and '}' not in line and not line.startswith('state') and not line.startswith('default')):
                self.warnings.append(f"Line {line_num}: Possible missing semicolon")
                
            # Check for forbidden LSL keywords
            self._check_forbidden_keywords(line, line_num)
                
        # Final brace balance check
        if brace_count != 0:
            self.errors.append(f"Unmatched braces: {brace_count} excess opening braces" if brace_count > 0 else f"{-brace_count} missing opening braces")
    
    def _check_forbidden_keywords(self, line, line_num):
        """Check for keywords that are forbidden in LSL"""
        # Skip comments
        if '//' in line:
            line = line[:line.index('//')]
        
        # Remove strings to avoid false positives
        # Simple approach: remove content between quotes
        import re
        line_no_strings = re.sub(r'"[^"]*"', '""', line)
        
        # Check each forbidden keyword
        for keyword in self.forbidden_keywords:
            # Use word boundaries to avoid matching substrings
            pattern = r'\b' + re.escape(keyword) + r'\b'
            if re.search(pattern, line_no_strings):
                self.errors.append(f"Line {line_num}: '{keyword}' is not supported in LSL")
    
    def _check_scope(self, lines, filepath):
        """Check for variable scope issues"""
        # Reset scope tracking
        self.global_vars = set()
        self.local_vars = []
        self.current_function = None
        
        in_function = False
        brace_depth = 0
        
        for line_num, line in enumerate(lines, 1):
            original_line = line
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith('//') or line.startswith('/*'):
                continue
            
            # Remove comments from line
            if '//' in line:
                line = line[:line.index('//')]
                line = line.strip()
            
            # Track brace depth for scope management
            open_braces = line.count('{')
            close_braces = line.count('}')
            
            # Check for function definitions
            if not in_function and ('(' in line and ')' in line and '{' in line):
                # This might be a function definition
                if any(event in line for event in ['state_entry', 'touch_start', 'listen', 'timer', 'on_rez', 'link_message', 'http_response']):
                    in_function = True
                    self.local_vars.append(set())  # New local scope
            
            # Handle scope changes
            if open_braces > 0:
                for _ in range(open_braces):
                    brace_depth += 1
                    if in_function and brace_depth > 1:  # Nested scope within function
                        self.local_vars.append(set())
            
            # Check for variable declarations
            self._check_variable_declaration(line, line_num, in_function)
            
            # Check for variable usage
            self._check_variable_usage(line, line_num)
            
            # Handle closing braces
            if close_braces > 0:
                for _ in range(close_braces):
                    brace_depth -= 1
                    if in_function and len(self.local_vars) > 1:
                        self.local_vars.pop()  # Exit nested scope
                    elif brace_depth == 0 and in_function:
                        # Exiting function
                        in_function = False
                        self.local_vars.clear()
    
    def _check_variable_declaration(self, line, line_num, in_function):
        """Check for variable declarations"""
        import re
        
        # Remove string literals to avoid false matches
        line_no_strings = re.sub(r'"[^"]*"', '""', line)
        
        # Pattern to match LSL variable declarations: type varname;
        for lsl_type in self.lsl_types:
            # Handle special case of for loop declarations: for(integer i = 0; ...)
            for_loop_pattern = rf'for\s*\(\s*{lsl_type}\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*='
            for_matches = re.findall(for_loop_pattern, line_no_strings)
            
            for var_name in for_matches:
                if var_name.startswith('ll') or var_name in self.lsl_functions:
                    continue
                # For loop variables are always local and shouldn't conflict with globals
                if len(self.local_vars) > 0:
                    self.local_vars[-1].add(var_name)
                continue
            
            # Regular variable declarations: type identifier; or type identifier =
            # Skip for loop variable declarations by checking the line content
            if 'for(' not in line_no_strings.replace(' ', '') and 'for (' not in line_no_strings:
                pattern = rf'\b{lsl_type}\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*[;=]'
                matches = re.findall(pattern, line_no_strings)
            else:
                matches = []
            
            for var_name in matches:
                # Skip LSL built-in functions that might match the pattern
                if var_name.startswith('ll') or var_name in self.lsl_functions:
                    continue
                    
                # Skip common parameter names that aren't real declarations
                if var_name in {'total_number', 'sender', 'num', 'str', 'id', 'start_param', 
                               'channel', 'name', 'msg', 'message', 'request_id', 'status', 'metadata', 'body'}:
                    continue
                
                if in_function:
                    # Check if already declared in current local scope
                    if len(self.local_vars) > 0 and var_name in self.local_vars[-1]:
                        self.errors.append(f"Line {line_num}: Variable '{var_name}' already declared in this scope")
                    else:
                        # Add to current local scope
                        if len(self.local_vars) > 0:
                            self.local_vars[-1].add(var_name)
                else:
                    # Global variable - only flag if it's a real redeclaration
                    if var_name in self.global_vars:
                        # Only error if this looks like a real declaration line
                        if ';' in line or '=' in line:
                            self.errors.append(f"Line {line_num}: Global variable '{var_name}' already declared")
                    else:
                        self.global_vars.add(var_name)
    
    def _check_variable_usage(self, line, line_num):
        """Check for usage of undefined variables (conservative approach)"""
        import re
        
        # Skip variable declarations and function definitions
        if any(lsl_type in line for lsl_type in self.lsl_types):
            return
            
        # Skip comments and string literals
        if line.strip().startswith('//') or line.strip().startswith('/*') or '"' in line:
            return
        
        # Skip lines that are clearly not variable usage
        if (line.startswith('state') or line.startswith('#') or line.strip() == 'default' or
            'llOwnerSay' in line or 'llSay' in line or 'llMessageLinked' in line or
            ('{' in line and '}' in line and line.count('{') == line.count('}'))):
            return
        
        # Only check very specific patterns where we're confident it's a variable usage
        # Pattern 1: variable assignment: varname = something
        assignment_vars = re.findall(r'([a-zA-Z_][a-zA-Z0-9_]*)\s*=', line)
        
        # Pattern 2: variable in arithmetic: something + varname or varname + something  
        arithmetic_vars = re.findall(r'(?:^|[+\-*/=\s])([a-zA-Z_][a-zA-Z0-9_]*)(?:\s*[+\-*/]|\s*;|$)', line)
        
        # Combine patterns
        potential_vars = set(assignment_vars + arithmetic_vars)
        
        for var_name in potential_vars:
            # Skip LSL functions, constants, keywords, and common false positives
            if (var_name in self.lsl_functions or var_name in self.lsl_constants or
                var_name in self.lsl_types or var_name.startswith('ll') or
                var_name in {'if', 'else', 'for', 'while', 'do', 'return', 'jump', 'state', 'default',
                           'total_number', 'sender', 'num', 'str', 'id', 'start_param', 'channel',
                           'name', 'msg', 'message', 'request_id', 'status', 'metadata', 'body',
                           # Common English words that show up in strings/comments
                           'the', 'and', 'or', 'not', 'has', 'been', 'with', 'from', 'this', 'that',
                           'will', 'can', 'may', 'all', 'any', 'some', 'new', 'old', 'get', 'set'} or
                var_name.isdigit() or len(var_name) <= 2):
                continue
            
            # Check if variable is defined
            is_defined = var_name in self.global_vars
            
            # Check local scopes (from innermost to outermost)
            if not is_defined:
                for scope in reversed(self.local_vars):
                    if var_name in scope:
                        is_defined = True
                        break
            
            # Only warn for very likely variable usage patterns
            if not is_defined:
                # Must be lowercase and used in assignment or arithmetic context
                if (var_name.islower() and 
                    (var_name in assignment_vars or 
                     (var_name in arithmetic_vars and any(op in line for op in ['+', '-', '*', '/'])))):
                    self.warnings.append(f"Line {line_num}: Variable '{var_name}' may not be defined")

    def _check_style(self, lines, filepath):
        """Check for style and best practice issues"""
        for line_num, line in enumerate(lines, 1):
            stripped = line.strip()
            
            # Skip comments and empty lines
            if not stripped or stripped.startswith('//') or stripped.startswith('/*'):
                continue
                
            # Check for very long lines
            if len(line) > 120:
                self.warnings.append(f"Line {line_num}: Line too long ({len(line)} characters)")
                
            # Check for tabs vs spaces (LSL prefers spaces)
            if '\t' in line:
                self.info.append(f"Line {line_num}: Contains tabs (LSL prefers spaces)")
                
            # Check for deprecated or problematic patterns
            if 'llOwnerSay' in stripped and 'DEBUG' in stripped.upper():
                self.info.append(f"Line {line_num}: Debug message found - consider removing for production")

    def _check_performance(self, content, filepath):
        """Check for performance issues"""
        # Check for expensive operations in loops
        lines = content.split('\n')
        in_loop = False
        loop_indent = 0
        
        for line_num, line in enumerate(lines, 1):
            stripped = line.strip()
            current_indent = len(line) - len(line.lstrip())
            
            # Detect loop start
            if any(keyword in stripped for keyword in ['for', 'while', 'do']):
                in_loop = True
                loop_indent = current_indent
                
            # Detect loop end
            elif in_loop and stripped == '}' and current_indent <= loop_indent:
                in_loop = False
                
            # Check for expensive operations in loops
            elif in_loop:
                if 'llList2CSV' in stripped or 'llCSV2List' in stripped:
                    self.warnings.append(f"Line {line_num}: Expensive CSV operation in loop")
                if 'llParseString2List' in stripped:
                    self.warnings.append(f"Line {line_num}: String parsing in loop may be expensive")

    def _check_memory_usage(self, content, filepath):
        """Check for potential memory issues"""
        # Count string operations
        csv_ops = content.count('llList2CSV') + content.count('llCSV2List')
        if csv_ops > 10:
            self.warnings.append(f"High number of CSV operations ({csv_ops}) - may impact memory")
            
        # Check for large string concatenations
        if content.count(' + ') > 50:
            self.warnings.append("High number of string concatenations - consider optimizing")
            
        # Check for memory monitoring
        if 'llGetFreeMemory' in content:
            self.info.append("✅ Memory monitoring detected")
            
        # Check for flood protection
        if 'cooldown' in content.lower() or 'flood' in content.lower():
            self.info.append("✅ Flood protection detected")

    def _generate_report(self, filepath):
        """Generate validation report"""
        filename = os.path.basename(filepath)
        report = [f"\n🔍 LSL Validation Report: {filename}"]
        report.append("=" * 60)
        
        if not self.errors and not self.warnings:
            report.append("✅ No issues found!")
        else:
            if self.errors:
                report.append(f"\n❌ ERRORS ({len(self.errors)}):")
                for error in self.errors:
                    report.append(f"   {error}")
                    
            if self.warnings:
                report.append(f"\n⚠️  WARNINGS ({len(self.warnings)}):")
                for warning in self.warnings:
                    report.append(f"   {warning}")
                    
        if self.info:
            report.append(f"\nℹ️  INFO ({len(self.info)}):")
            for info in self.info:
                report.append(f"   {info}")
                
        # File stats
        try:
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                lines = len(content.split('\n'))
                chars = len(content)
                
            report.append(f"\n📊 FILE STATS:")
            report.append(f"   Lines: {lines}")
            report.append(f"   Characters: {chars:,}")
            report.append(f"   Size: {os.path.getsize(filepath):,} bytes")
            
        except:
            pass
            
        return '\n'.join(report)

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 lsl_validator.py <file.lsl|directory>")
        sys.exit(1)
        
    target = sys.argv[1]
    validator = LSLValidator()
    
    if os.path.isfile(target):
        # Single file validation
        if not target.endswith('.lsl'):
            print("❌ ERROR: File must have .lsl extension")
            sys.exit(1)
            
        result = validator.validate_file(target)
        print(result)
        
    elif os.path.isdir(target):
        # Directory validation
        lsl_files = glob.glob(os.path.join(target, "*.lsl"))
        
        if not lsl_files:
            print(f"❌ No .lsl files found in {target}")
            sys.exit(1)
            
        print(f"🔍 Validating {len(lsl_files)} LSL files in {target}")
        print("=" * 80)
        
        total_errors = 0
        total_warnings = 0
        
        for lsl_file in sorted(lsl_files):
            result = validator.validate_file(lsl_file)
            print(result)
            
            total_errors += len(validator.errors)
            total_warnings += len(validator.warnings)
            
        print("\n" + "=" * 80)
        print(f"📋 SUMMARY: {len(lsl_files)} files validated")
        print(f"   Total Errors: {total_errors}")
        print(f"   Total Warnings: {total_warnings}")
        
        if total_errors > 0:
            sys.exit(1)
            
    else:
        print(f"❌ ERROR: {target} is not a file or directory")
        sys.exit(1)

if __name__ == "__main__":
    main()