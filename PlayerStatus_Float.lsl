// === Player Status Float - Enhanced Display ===

// Helper function to get display name with fallback to username
string getPlayerName(key id) {
    string displayName = llGetDisplayName(id);
    if (displayName == "") {
        // Fallback to legacy username if display name is unavailable
        displayName = llKey2Name(id);
    }
    return displayName;
}
key target;
string displayText;
string myName;

// Listen handle management
integer listenHandle = -1;

integer MSG_SYNC_GAME_STATE = 107;

list lives;
list picksData;
string perilPlayer;
list names;

// Memory reporting function
reportMemoryUsage(string scriptName) {
    integer used = llGetUsedMemory();
    integer free = llGetFreeMemory();
    integer total = used + free;
    float percentUsed = ((float)used / (float)total) * 100.0;
    
    llOwnerSay("🧠 [" + scriptName + "] Memory: " + 
               (string)used + " used, " + 
               (string)free + " free (" + 
               llGetSubString((string)percentUsed, 0, 4) + "% used)");
}

list getPicksFor(string nameInput) {
    integer i;
    for (i = 0; i < llGetListLength(picksData); i++) {
        string entry = llList2String(picksData, i);
        list parts = llParseString2List(entry, ["|"], []);
        if (llGetListLength(parts) >= 2 && llList2String(parts, 0) == nameInput) {
            string picks = llList2String(parts, 1);
            if (picks == "") {
                return [];
            }
            // Check for corruption markers (^ symbols that shouldn't be in picks)
            if (llSubStringIndex(picks, "^") != -1) {
                return [];
            }
            // Convert semicolons back to commas, then parse
            picks = llDumpList2String(llParseString2List(picks, [";"], []), ",");
            return llParseString2List(picks, [","], []);
        }
    }
    return [];
}

default {
    state_entry() {
        // Get player name from object description if available
        string playerName = llGetObjectDesc();
        if (playerName == "" || playerName == "(No Description)") {
            playerName = "Unknown";
        }
        reportMemoryUsage("📱 Player Float (" + playerName + ")");
        
        llSetText("⏳ Waiting...", <1,1,1>, 1.0);
        llSetTimerEvent(1.0);
    }

    on_rez(integer start_param) {
        // Clean up any existing listeners
        if (listenHandle != -1) {
            llListenRemove(listenHandle);
        }
        
        // Set up managed listener
        listenHandle = llListen(start_param, "", NULL_KEY, "");
        
        // Initialize myName to empty - will be set when SET_NAME message is received
        myName = "";
        
        // Don't report memory immediately - wait for proper name to be set
// PlayerStatus_Float ready and listening
    }

    listen(integer channel, string name, key id, string message) {
        if (llSubStringIndex(message, "FLOAT:") == 0) {
            list parts = llParseString2List(message, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                target = (key)llGetSubString(llList2String(parts, 0), 6, -1);
                displayText = llList2String(parts, 1);
                
                // Extract life count from the display text to set heart texture
                // Look for "Lives: X" pattern in the text
                integer livesPos = llSubStringIndex(displayText, "Lives: ");
                if (livesPos != -1) {
                    string livesStr = llGetSubString(displayText, livesPos + 7, livesPos + 7);
                    integer lifeCount = (integer)livesStr;
                    string heartTexture = (string)lifeCount + "_hearts";
                    // Set heart texture based on current life count
                    llSetTexture(heartTexture, 1); // Face 1 (right side)
                    llSetTexture(heartTexture, 2); // Face 2 (back)
                    llSetTexture(heartTexture, 3); // Face 3 (left side)
                    llSetTexture(heartTexture, 4); // Face 4 (front)
                    
                    // IMPROVED: Special visual treatment for elimination (0 hearts)
                    if (lifeCount == 0) {
                        // Make 0 hearts more prominent with red glow
                        llSetLinkPrimitiveParamsFast(LINK_THIS, [
                            PRIM_GLOW, ALL_SIDES, 0.3,
                            PRIM_COLOR, ALL_SIDES, <1.0, 0.0, 0.0>, 1.0
                        ]);
                        
                        // Modify display text to show elimination status
                        displayText = llDumpList2String(llParseString2List(displayText, ["\n"], []), "\n") + "\n💀 ELIMINATED! 💀";
                    } else {
                        // Check for winner status first (highest priority)
                        integer isWinner = FALSE;
                        if (llSubStringIndex(displayText, "✨ ULTIMATE VICTORY!") != -1 || 
                            llSubStringIndex(displayText, "ULTIMATE SURVIVOR") != -1) {
                            isWinner = TRUE;
                        }
                        
                        // Check if this player is in peril for yellow glow
                        integer isInPeril = FALSE;
                        if (llSubStringIndex(displayText, "⚡ YOU ARE IN PERIL! ⚡") != -1) {
                            isInPeril = TRUE;
                        }
                        
                        if (isWinner) {
                            // Green glow for winner (overrides peril)
                            llSetLinkPrimitiveParamsFast(LINK_THIS, [
                                PRIM_GLOW, ALL_SIDES, 0.3,
                                PRIM_COLOR, ALL_SIDES, <0.0, 1.0, 0.0>, 1.0  // Green tint
                            ]);
                        } else if (isInPeril) {
                            // Yellow glow for peril player
                            llSetLinkPrimitiveParamsFast(LINK_THIS, [
                                PRIM_GLOW, ALL_SIDES, 0.2,
                                PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 0.0>, 1.0  // Yellow tint
                            ]);
                        } else {
                            // Normal colors for living players - remove glow
                            llSetLinkPrimitiveParamsFast(LINK_THIS, [
                                PRIM_GLOW, ALL_SIDES, 0.0,
                                PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0
                            ]);
                            llSetColor(<0.2, 0.2, 0.2>, 0); // Dark gray for top
                            llSetColor(<0.2, 0.2, 0.2>, 5); // Dark gray for bottom
                        }
                    }
                    
                    // Remove "Lives: X" from display text since hearts show it
                    list lines = llParseString2List(displayText, ["\n"], []);
                    list filteredLines = [];
                    integer i;
                    for (i = 0; i < llGetListLength(lines); i++) {
                        string line = llList2String(lines, i);
                        if (llSubStringIndex(line, "Lives: ") != 0) {
                            filteredLines += [line];
                        }
                    }
                    displayText = llDumpList2String(filteredLines, "\n");
                }
                
                llSetText(displayText, <1,1,1>, 1.0);
            }
        }
        else if (message == "CLEANUP") {
            llOwnerSay("🪟 Cleaning up...");
            llDie();
        }
        else if (llSubStringIndex(message, "SET_NAME:") == 0) {
            myName = llGetSubString(message, 9, -1);
            // Name successfully received and set
            // Update the object description as well for consistency
            llSetObjectDesc(myName);
            
            // Now report memory with the proper player name
            reportMemoryUsage("📱 " + myName);
        }
    }

    link_message(integer sender, integer num, string str, key id) {
        if (num == MSG_SYNC_GAME_STATE) {
            list parts = llParseString2List(str, ["~"], []);
            if (llGetListLength(parts) < 4) return;
            lives = llCSV2List(llList2String(parts, 0));
            
            // Use ^ delimiter for picksData to match the main system
            string picksDataStr = llList2String(parts, 1);
            if (picksDataStr == "" || picksDataStr == "EMPTY") {
                picksData = [];
            } else {
                picksData = llParseString2List(picksDataStr, ["^"], []);
            }
            
            string receivedPeril = llList2String(parts, 2);
            if (receivedPeril == "NONE") {
                perilPlayer = "";  // Convert placeholder back to empty
            } else {
                perilPlayer = receivedPeril;
            }
            names = llCSV2List(llList2String(parts, 3));

            integer nameIdx = llListFindList(names, [myName]);
            if (nameIdx == -1) return;

            list picks = getPicksFor(myName);
            integer lifeCount = llList2Integer(lives, nameIdx);

            string perilDisplay;
            // If the perilPlayer string is empty or contains a comma (indicating
            // multiple names), treat the game as not yet started.  This avoids
            // showing multiple players as the peril player before the first
            // round begins.  Once a single peril player is assigned, it will
            // not contain a comma and will be displayed normally.
            if (perilPlayer == "" || llSubStringIndex(perilPlayer, ",") != -1) {
                perilDisplay = "Waiting for game to start...";
            } else {
                perilDisplay = perilPlayer;
            }

            string picksDisplay = llList2CSV(picks);

            // IMPROVED: Set heart texture and handle elimination display
            string heartTexture = (string)lifeCount + "_hearts";
            llSetTexture(heartTexture, 1); // Face 1 (right side)
            llSetTexture(heartTexture, 2); // Face 2 (back)
            llSetTexture(heartTexture, 3); // Face 3 (left side)
            llSetTexture(heartTexture, 4); // Face 4 (front)
            
            string txt;
            if (lifeCount == 0) {
                // Special treatment for elimination - red glow and elimination message
                llSetLinkPrimitiveParamsFast(LINK_THIS, [
                    PRIM_GLOW, ALL_SIDES, 0.3,
                    PRIM_COLOR, ALL_SIDES, <1.0, 0.0, 0.0>, 1.0
                ]);
                
                txt = "🎲 Peril Dice\n👤 " + myName + "\n💀 ELIMINATED! 💀\n🔢 Final Picks: " + picksDisplay;
                // Set text to red color as well for extra visibility
                llSetText(txt, <1.0, 0.2, 0.2>, 1.0);
                return; // Skip normal text setting below
            } else {
                // Check if this is the winner (highest priority) - happens when only 1 player left
                integer isWinner = (llGetListLength(names) <= 1 && myName != "" && llListFindList(names, [myName]) != -1);
                
                // Check if this player is the peril player for yellow glow
                integer isInPeril = (myName == perilPlayer && perilPlayer != "" && llSubStringIndex(perilPlayer, ",") == -1);
                
                if (isWinner) {
                    // Green glow for winner (overrides peril)
                    llSetLinkPrimitiveParamsFast(LINK_THIS, [
                        PRIM_GLOW, ALL_SIDES, 0.3,
                        PRIM_COLOR, ALL_SIDES, <0.0, 1.0, 0.0>, 1.0  // Green tint
                    ]);
                } else if (isInPeril) {
                    // Yellow glow for peril player
                    llSetLinkPrimitiveParamsFast(LINK_THIS, [
                        PRIM_GLOW, ALL_SIDES, 0.2,
                        PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 0.0>, 1.0  // Yellow tint
                    ]);
                } else {
                    // Normal colors for living players - remove glow
                    llSetLinkPrimitiveParamsFast(LINK_THIS, [
                        PRIM_GLOW, ALL_SIDES, 0.0,
                        PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0
                    ]);
                    llSetColor(<0.2, 0.2, 0.2>, 0); // Dark gray for top
                    llSetColor(<0.2, 0.2, 0.2>, 5); // Dark gray for bottom
                }
                
                txt = "🎲 Peril Dice\n👤 " + myName + "\n🢍 Peril: " + perilDisplay + "\n🔢 Picks: " + picksDisplay;
            }
            
            llSetText(txt, <1,1,1>, 1.0);
        }
    }

    timer() {
        if (target != NULL_KEY && getPlayerName(target) != "") {
            vector pos = llList2Vector(llGetObjectDetails(target, [OBJECT_POS]), 0) + <1,0,1>;
            llSetRegionPos(pos);
        }
    }
}
