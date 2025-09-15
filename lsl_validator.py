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
                
        # Final brace balance check
        if brace_count != 0:
            self.errors.append(f"Unmatched braces: {brace_count} excess opening braces" if brace_count > 0 else f"{-brace_count} missing opening braces")

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