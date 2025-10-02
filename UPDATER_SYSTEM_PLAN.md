# Peril Dice External Updater System

## Architecture Overview

### Components Needed:

#### 1. **Updater Box** (`Peril_Dice_Updater.lsl`)
- Standalone object that users rez temporarily
- Downloads scripts from GitHub when activated
- Installs scripts into target Peril Dice game via remote loading
- Self-contained - includes all update logic

#### 2. **Update Receiver** (in main game)
- Modified `Update_Checker.lsl` → `Update_Receiver.lsl`
- Scans for nearby updater boxes
- Requests updates when available
- Manages the script replacement process

#### 3. **Script Manifest** (GitHub hosted)
- JSON file listing all scripts and their GitHub URLs
- Version tracking for incremental updates
- Deployment instructions for updater

## Technical Implementation

### Update Process Flow:

```
1. User rezzes "Peril Dice Updater v2.8.7" box
2. User touches their Peril Dice game → "Check for Updates"
3. Game scans for nearby updater boxes (llSensor)
4. Game requests update from updater box
5. Updater downloads scripts from GitHub
6. Game sets script access pin (llSetRemoteScriptAccessPin)
7. Updater installs scripts via llRemoteLoadScriptPin()
8. Game validates installation and reports success
9. User deletes updater box
```

### Key LSL Functions:
- `llSensor()` - Find nearby updater boxes
- `llSetRemoteScriptAccessPin()` - Allow updater access
- `llRemoteLoadScriptPin()` - Install new scripts
- `llHTTPRequest()` - Download scripts from GitHub
- `llGetInventoryName()` - Validate installed scripts

## User Experience

### For Players:
1. Receive "Peril Dice Updater v2.8.7" from creator
2. Rez updater near their game
3. Touch game → Admin Menu → "Check for Updates"
4. See "Update Available: v2.8.6 → v2.8.7"
5. Click "Install Update" 
6. Watch progress: "Installing script 3 of 17..."
7. See "✅ Update Complete! Game is now v2.8.7"
8. Delete updater box

### For Creator (You):
1. Build new scripts and test them
2. Commit to GitHub with version bump
3. Create updater box with new version number
4. Distribute updater to users via marketplace/group notices
5. Users get automatic professional updates

## Advantages Over Manual Updates

### ✅ Professional Experience:
- One-click updates like commercial software
- Progress indicators and status messages
- Automatic validation of successful installation
- No copy/paste errors or missed scripts

### ✅ Version Control:
- Updater knows exactly which scripts need updating
- Can do incremental updates (only changed files)
- Prevents version mismatches between scripts
- Tracks what was updated when

### ✅ User Friendly:
- No technical knowledge required
- Clear instructions and feedback
- Impossible to mess up the installation
- Works the same way every time

## Files to Create

### 1. `Peril_Dice_Updater.lsl`
- Main updater script for the external box
- GitHub API integration for script downloads
- Remote script installation logic
- Progress reporting and error handling

### 2. `Update_Receiver.lsl` 
- Replace existing Update_Checker.lsl
- Scan for nearby updater boxes
- Coordinate with updater for script replacement
- Validate successful updates

### 3. `updater-manifest.json` (GitHub)
- List of all scripts with GitHub URLs
- Version requirements and dependencies
- Installation order and link assignments

### 4. Instructions for packaging updater boxes
- How to create updater objects for distribution
- Testing procedures for new versions
- Distribution methods (marketplace, group, etc.)

## Implementation Priority

### Phase 1: Core Updater System
1. Create basic updater box with GitHub integration
2. Modify existing Update_Checker to work with updater
3. Test with simple single-script updates

### Phase 2: Full Integration  
1. Complete manifest system for all 17 scripts
2. Add progress indicators and error handling
3. Test complete game updates

### Phase 3: Polish & Distribution
1. Create professional updater box object
2. Write user documentation
3. Set up distribution system

This system would provide a truly professional update experience matching commercial Second Life products!