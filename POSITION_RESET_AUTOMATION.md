# Position Reset System - No Config File Required!

## Overview

The Peril Dice Game now includes a fully integrated and automated position reset system that **eliminates the need for manual config file editing**. The position reset functionality is built directly into the Owner Dialog menu system and provides both automatic updates and config generation.

## Two Ways to Use Position Reset

### 🚀 Method 1: Fully Automatic (Recommended)
**No config file editing required!**

1. Position your displays where you want them
2. Go to Owner Menu → 🛠️ Troubleshooting → Reset Follower Positions  
3. Wait 3 seconds for the scan to complete
4. **Done!** Your displays automatically update to the new positions

The system will:
- ✅ Scan for all follower displays within 20 meters
- ✅ Calculate the correct offset and rotation values  
- ✅ Automatically broadcast updates to all displays
- ✅ Move displays to their new positions immediately
- ✅ Save the new positions for future use

### 📝 Method 2: Manual Config (Traditional)
If you prefer the traditional method:

1. Follow steps 1-3 above
2. Copy the displayed config values to each display's notecard
3. The displays will update when the notecard is saved

## How It Works

### Controller Side (Owner Dialog Handler)
- **Integrated Menu**: Position reset is accessible through the existing Owner Menu
- **Smart Scanning**: Broadcasts scan messages on all dynamic channels
- **Automatic Updates**: Sends position updates directly to displays
- **Multi-Instance Safe**: Uses the same dynamic channel system as the game

### Display Side (Follower Scripts)  
- **Live Updates**: Displays can receive and apply position changes instantly
- **No Config Required**: New `POSITION_UPDATE` message handling
- **Backward Compatible**: Still works with config notecards if desired
- **Immediate Application**: Updates position as soon as received

## Key Benefits

### 🎯 User Experience
- **One-Click Solution**: Reset positions with a single menu selection
- **No Manual Editing**: Eliminates error-prone notecard editing
- **Instant Results**: See position changes immediately
- **Consistent Interface**: Integrated into familiar menu system

### 🛡️ Reliability  
- **Multi-Instance Safe**: Each game table has unique channels
- **Error Prevention**: Eliminates manual copy/paste mistakes
- **Automatic Validation**: Only processes valid position data
- **State Tracking**: Prevents concurrent scans and conflicts

### 🔧 Technical Advantages
- **Dynamic Channels**: Uses per-instance unique communication
- **Memory Efficient**: Shares resources with existing dialog system
- **Future-Proof**: Extensible for additional automation features
- **Compatibility**: Works with existing config-based setups

## Setup Instructions

### For New Installations
1. Use the updated `Owner and Player Dialog Handler.lsl` in your controller
2. Use the updated `Follower_Script_Template.lsl` in your displays
3. Set the `DISPLAY_TYPE` in each follower script ("scoreboard", "leaderboard", or "dice")
4. Position displays and use the automated reset - **no config file needed!**

### For Existing Installations  
1. Replace the Owner Dialog Handler script in your controller
2. Update follower scripts in your displays (optional but recommended)
3. Existing config notecards will continue to work
4. Use automated reset for future position changes

## Troubleshooting

### "No follower displays found"
- Ensure displays are within 20 meters of the controller
- Verify follower scripts are using the updated template
- Check that displays use the same dynamic channel system
- Make sure `DISPLAY_TYPE` is set correctly in each follower

### Displays don't move after reset
- Check that follower scripts have the `POSITION_UPDATE` handler
- Verify the controller and displays have matching dynamic channels
- Ensure displays have received at least one `CONTROLLER_MOVE` message

### Config notecard still required?
- **No!** The automated system works without config files
- Config files are only needed for the traditional manual method
- If using config files, they will override automated updates

## Migration Path

### From Standalone Position Reset Tool
1. Remove the `Position_Reset_Tool.lsl` script (no longer needed)
2. Update to the new Owner Dialog Handler
3. Enjoy integrated position reset from the menu

### From Manual Config Management
1. Keep existing config notecards (they still work)
2. Try the automated reset for future changes
3. Gradually phase out manual config editing

## Future Enhancements

The automated system provides a foundation for additional features:
- **Preset Positions**: Save and recall multiple display arrangements
- **Remote Updates**: Update positions across multiple game tables
- **Template Sharing**: Export/import position configurations
- **Visual Positioning**: GUI-based position adjustment tools

---

**The config file era is over! Welcome to automated position management.** 🎉
