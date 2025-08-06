// === StatFloat Enhanced ===
key target;
string displayText;
string myName;

integer MSG_SYNC_GAME_STATE = 107;

list lives;
list picksData;
string perilPlayer;
list names;

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
        llSetText("⏳ Waiting...", <1,1,1>, 1.0);
        llSetTimerEvent(1.0);
    }

    on_rez(integer start_param) {
        llListen(start_param, "", NULL_KEY, "");
        // Wait a moment for the description to be set
        llSleep(0.1);
        myName = llGetObjectDesc();
        if (myName == "" || myName == "(No Description)") {
            myName = "UnknownPlayer" + (string)start_param;
        }
// StatFloat ready and listening
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
                    // Set white background for all faces to eliminate gaps without tinting
                    llSetColor(<1.0, 1.0, 1.0>, 1); // White background for right side
                    llSetColor(<1.0, 1.0, 1.0>, 2); // White background for back
                    llSetColor(<1.0, 1.0, 1.0>, 3); // White background for left side
                    llSetColor(<1.0, 1.0, 1.0>, 4); // White background for front
                    llSetColor(<0.2, 0.2, 0.2>, 0); // Dark gray for top
                    llSetColor(<0.2, 0.2, 0.2>, 5); // Dark gray for bottom
                    
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

            // Note: Heart texture is set via listen() path to avoid conflicts
            
            // Update text display (lives now shown by heart textures)
            string txt = "🎲 Peril Dice\n👤 " + myName + "\n🢍 Peril: " + perilDisplay + "\n🔢 Picks: " + picksDisplay;
            llSetText(txt, <1,1,1>, 1.0);
        }
    }

    timer() {
        if (target != NULL_KEY && llKey2Name(target) != "") {
            vector pos = llList2Vector(llGetObjectDetails(target, [OBJECT_POS]), 0) + <1,0,1>;
            llSetRegionPos(pos);
        }
    }
}
