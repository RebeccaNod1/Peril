# GitHub-Powered External Updater System

## Architecture: GitHub + Automatic Installation

### Components:

#### 1. **GitHub Integration** (Existing)
- ✅ GitHub Releases API for version detection
- ✅ GitHub raw file downloads for script content  
- ✅ Zero infrastructure - uses existing GitHub + Jenkins
- ✅ Professional version management

#### 2. **Peril_Dice_Updater.lsl** (New - External Box)
- Downloads scripts directly from GitHub raw URLs
- Uses GitHub API to get latest release info
- Installs scripts automatically via llRemoteLoadScriptPin()
- Handles the 2048-character LSL limit properly

#### 3. **Update_Receiver.lsl** (Modified existing Update_Checker)
- Scans for nearby updater boxes
- Still checks GitHub API for version comparison
- Coordinates automatic installation with updater box
- Validates successful updates

## User Experience Flow:

### Step 1: Get Updater
- User receives "Peril Dice GitHub Updater v2.8.7" box
- Box description: "Automatic GitHub-powered updater for Peril Dice"

### Step 2: Check & Install  
1. User rezzes updater box near their Peril Dice game
2. User touches game → Admin Menu → "Check for Updates"
3. Game checks GitHub API: "v2.8.7 available!"
4. User clicks "Install Update"
5. Game connects to nearby updater box
6. Updater downloads all needed scripts from GitHub
7. Updater installs scripts automatically: "Installing 3 of 17..."
8. Game validates: "✅ Update complete! Now running v2.8.7"
9. User deletes updater box

## Technical Implementation:

### GitHub URLs Used:
```
Version Check: https://api.github.com/repos/RebeccaNod1/Peril/releases/latest
Script Downloads: https://raw.githubusercontent.com/RebeccaNod1/Peril/main/ScriptName.lsl
```

### Script Installation Process:
```lsl
// In Updater Box:
1. llHTTPRequest() to download script from GitHub
2. llRemoteLoadScriptPin() to install in target game
3. Repeat for all 17 scripts in correct order

// In Target Game:
1. llSetRemoteScriptAccessPin() to allow updater access
2. Validate each script installation
3. Report progress to user
```

## Benefits of This Approach:

### ✅ **GitHub Integration Maintained:**
- Same zero-infrastructure benefits
- Automatic version detection  
- Professional release management
- Leverages existing CI/CD pipeline
- No separate update server needed

### ✅ **User Experience Improved:**
- One-click automatic installation
- No manual copy/paste required
- Progress indicators and feedback
- Impossible to make installation errors
- Professional software-like experience

### ✅ **Creator Benefits:**
- Same development workflow (commit → push → tag)
- GitHub releases automatically available
- Single updater box for all users
- Easy to distribute via marketplace/group

## Files to Create:

### 1. `Peril_Dice_Updater.lsl`
```lsl
// External updater box script
- GitHub API integration (version checking)
- GitHub raw file downloads (script content)
- Remote script installation
- Progress reporting
- Error handling for network issues
```

### 2. `Update_Receiver.lsl` 
```lsl  
// Replace Update_Checker.lsl in main game
- Scan for nearby GitHub updater boxes
- GitHub version checking (same as before)
- Coordinate automatic installation
- Validate successful updates
```

### 3. `github-manifest.json` (in repository)
```json
{
  "version": "2.8.7",
  "scripts": [
    {
      "name": "Main_Controller_Linkset.lsl",
      "link": 1,
      "url": "https://raw.githubusercontent.com/RebeccaNod1/Peril/main/Main_Controller_Linkset.lsl",
      "required": true
    },
    // ... all 17 scripts with GitHub URLs
  ]
}
```

## Advantages Over Current System:

| **Current (Manual)** | **New (GitHub + Auto)** |
|---------------------|-------------------------|
| ❌ User copies/pastes each script | ✅ One-click automatic installation |
| ❌ Easy to make mistakes | ✅ Impossible to mess up |
| ❌ Must update all scripts manually | ✅ Updates only changed scripts |
| ❌ No progress indication | ✅ Clear progress and status |
| ✅ Uses GitHub (good!) | ✅ Still uses GitHub (great!) |

## Implementation Steps:

### Phase 1: Build Core System
1. Create `Peril_Dice_Updater.lsl` with GitHub integration
2. Convert `Update_Checker.lsl` → `Update_Receiver.lsl`
3. Create `github-manifest.json` listing all scripts
4. Test basic single-script updates

### Phase 2: Full Integration
1. Test complete 17-script updates 
2. Add progress indicators and error handling
3. Test with multiple game instances
4. Validate version tracking

### Phase 3: Distribution
1. Create professional updater box object
2. Write user instructions
3. Set up distribution (marketplace/group/etc.)
4. Create demo videos

This gives you **all the benefits of GitHub** (zero infrastructure, automatic detection, professional workflow) **plus** the automatic installation that users expect from professional Second Life products!

Should I start building the GitHub-powered external updater system?