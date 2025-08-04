// Bot Manager for Peril Dice
// Handles logic for test players (bots): picking numbers and rolling dice

// Configuration
integer LISTEN_CHANNEL = -9999; // Change if needed to match main controller
integer MSG_SYNC_GAME_STATE = 107;

// Track game state to validate bot commands
list names = [];
list lives = [];
string perilPlayer = "";

// Helper to parse and respond to pick commands
doBotPick(string botName, integer count, integer diceMax, list avoidNumbers) {
    // Validate bot exists and is still alive
    integer botIdx = llListFindList(names, [botName]);
    if (botIdx == -1) {
        llOwnerSay("[Bot Manager] ❌ Bot '" + botName + "' not found in game - ignoring command");
        return;
    }
    
    integer botLives = llList2Integer(lives, botIdx);
    if (botLives <= 0) {
        llOwnerSay("[Bot Manager] ❌ Bot '" + botName + "' is eliminated (lives=" + (string)botLives + ") - ignoring command");
        return;
    }
    
    
    list picks;
    integer attempts = 0;
    
    while (llGetListLength(picks) < count && attempts < 100) {
        integer roll = 1 + (integer)(llFrand((float)diceMax));
        string rollStr = (string)roll;
        
        integer inPicks = llListFindList(picks, [rollStr]);
        integer inAvoid = llListFindList(avoidNumbers, [rollStr]);
        
        
        // Check if not already picked by this bot and not picked by others
        if (inPicks == -1 && inAvoid == -1) {
            picks += rollStr;
        } else {
            string reason = "";
            if (inPicks != -1) {
                reason = "already picked by this bot";
            } else if (inAvoid != -1) {
                reason = "already picked by another player";
            }
        }
        attempts++;
    }
    
    
    if (llGetListLength(picks) < count) {
        llOwnerSay("[Bot Manager] ⚠️ WARNING: " + botName + " only picked " + (string)llGetListLength(picks) + "/" + (string)count + " numbers after " + (string)attempts + " attempts");
    }
    
    string pickString = llDumpList2String(picks, ";");
    string response = "BOT_PICKED:" + botName + ":" + pickString;
    llMessageLinked(LINK_SET, -9997, response, NULL_KEY);
}

// Helper to respond to peril roll commands
doBotRoll(string botName, integer diceMax) {
    // Validate bot exists and is still alive
    integer botIdx = llListFindList(names, [botName]);
    if (botIdx == -1) {
        llOwnerSay("[Bot Manager] ❌ Bot '" + botName + "' not found in game - ignoring roll command");
        return;
    }
    
    integer botLives = llList2Integer(lives, botIdx);
    if (botLives <= 0) {
        llOwnerSay("[Bot Manager] ❌ Bot '" + botName + "' is eliminated (lives=" + (string)botLives + ") - ignoring roll command");
        return;
    }
    
    if (botName != perilPlayer) {
        llOwnerSay("[Bot Manager] ❌ Bot '" + botName + "' is not the peril player (current peril: '" + perilPlayer + "') - ignoring roll command");
        return;
    }
    
    integer roll = 1 + (integer)(llFrand((float)diceMax));
    llRegionSay(LISTEN_CHANNEL, "BOT_ROLL:" + botName + ":" + (string)roll);
}

default {
    state_entry() {
        llListen(LISTEN_CHANNEL, "", NULL_KEY, "");
        llOwnerSay("[Bot Manager] Ready and listening on channel " + (string)LISTEN_CHANNEL);
        llOwnerSay("[Bot Manager] My key: " + (string)llGetKey());
        llOwnerSay("[Bot Manager] My position: " + (string)llGetPos());
    }

    link_message(integer sender, integer num, string str, key id) {
        // Handle game state sync to track player eliminations
        if (num == MSG_SYNC_GAME_STATE) {
            list parts = llParseString2List(str, ["~"], []);
            if (llGetListLength(parts) >= 4) {
                lives = llCSV2List(llList2String(parts, 0));
                // Don't need picks data for validation, skip parts[1]
                string receivedPeril = llList2String(parts, 2);
                if (receivedPeril == "NONE") {
                    perilPlayer = "";
                } else {
                    perilPlayer = receivedPeril;
                }
                names = llCSV2List(llList2String(parts, 3));
            }
            return;
        }
        
        if (num == -9999) {
                if (llSubStringIndex(str, "BOT_PICK:") == 0) {
                // Format: BOT_PICK:bot_1:3:20:1,2,3 (last part is optional already picked numbers)
                list parts = llParseStringKeepNulls(str, [":"], []);
                if (llGetListLength(parts) >= 4) {
                    string botName = llList2String(parts, 1);
                    integer count = (integer)llList2String(parts, 2);
                    integer diceMax = (integer)llList2String(parts, 3);
                    list avoidNumbers = [];
                    if (llGetListLength(parts) >= 5) {
                        string avoidStr = llList2String(parts, 4);
                        if (avoidStr != "") {
                            list rawList = llCSV2List(avoidStr);
                            // Trim whitespace from each number
                            avoidNumbers = [];
                            integer i;
                            for (i = 0; i < llGetListLength(rawList); i++) {
                                string trimmed = llStringTrim(llList2String(rawList, i), STRING_TRIM);
                                if (trimmed != "") {
                                    avoidNumbers += [trimmed];
                                }
                            }
                        }
                    }
                    doBotPick(botName, count, diceMax, avoidNumbers);
                }
            }
            else if (llSubStringIndex(str, "BOT_PERIL_ROLL:") == 0) {
                // Format: BOT_PERIL_ROLL:bot_1:20
                list parts = llParseStringKeepNulls(str, [":"], []);
                if (llGetListLength(parts) == 3) {
                    string botName = llList2String(parts, 1);
                    integer diceMax = (integer)llList2String(parts, 2);
                    doBotRoll(botName, diceMax);
                }
            }
        }
    }

    listen(integer channel, string name, key id, string message) {
        if (llSubStringIndex(message, "BOT_PICK:") == 0) {
            // Format: BOT_PICK:bot_1:3:20
            list parts = llParseStringKeepNulls(message, [":"], []);
            if (llGetListLength(parts) == 4) {
                string botName = llList2String(parts, 1);
                integer count = (integer)llList2String(parts, 2);
                integer diceMax = (integer)llList2String(parts, 3);
                doBotPick(botName, count, diceMax, []);
            }
        }
        else if (llSubStringIndex(message, "BOT_PERIL_ROLL:") == 0) {
            // Format: BOT_PERIL_ROLL:bot_1:20
            list parts = llParseStringKeepNulls(message, [":"], []);
            if (llGetListLength(parts) == 3) {
                string botName = llList2String(parts, 1);
                integer diceMax = (integer)llList2String(parts, 2);
                doBotRoll(botName, diceMax);
            }
        }
    }
}
