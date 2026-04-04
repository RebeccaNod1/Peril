#include "Peril_Constants.lsl"

// === Dialog Handler (Updated for Peril Dice - Paginated Multiple Picks) ===

// Verbose logging control


// =============================================================================
// DYNAMIC CHANNEL CONFIGURATION
// =============================================================================

// Base channel offset must match Main.lsl
#define CHANNEL_BASE -77000

// Calculate channels dynamically to avoid hardcoded conflicts
integer calculateChannel(integer offset) {
    // Use BOTH owner's key AND object's key to make channels unique per game instance
    // This prevents interference when same owner has multiple game tables
    string ownerStr = (string)llGetOwner();
    string objectStr = (string)llGetKey();
    string combinedStr = ownerStr + objectStr;
    
    // Create a more unique hash using both keys
    string hashStr = llMD5String(combinedStr, 0);
    integer hash1 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 0, 0));
    integer hash2 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 1, 1));
    integer combinedHash = hash1 * 16 + hash2; // Creates 0-255 range
    
    return CHANNEL_BASE - (offset * 1000) - combinedHash;
}

// Dynamic channel variables
integer NUMBERPICK_CHANNEL;

// Channel initialization function
initializeChannels() {
    NUMBERPICK_CHANNEL = calculateChannel(2);     // ~-77200 range to match Main.lsl
    
    // Report channel to owner for debugging
    dbg("🎮 [NumberPicker] 🔧 Dynamic channel initialized:");
    dbg("  Number Pick: " + (string)NUMBERPICK_CHANNEL);
}

integer numberPickChannel; // Legacy variable, will be set dynamically

// Listen handle management
integer listenHandle = -1;

// Pagination and picking state
string currentPlayer = "";
key currentPlayerKey = NULL_KEY;
integer currentDiceType = 0;
integer picksNeeded = 1;
list currentPicks = [];
list globallyPickedNumbers = []; // Numbers already picked by other players
integer currentPage = 0;
#define NUMBERS_PER_PAGE 9 // Leave room for navigation buttons

// Memory reporting function
reportMemoryUsage(string scriptName) {
    integer used = llGetUsedMemory();
    integer free = llGetFreeMemory();
    integer total = used + free;
    float percentUsed = ((float)used / (float)total) * 100.0;
    
    dbg("🧠 [" + scriptName + "] Memory: " + 
               (string)used + " used, " + 
               (string)free + " free (" + 
               llGetSubString((string)percentUsed, 0, 4) + "% used)");
}

list getNumbersForPage(integer page, integer diceType) {
    // Build list of available numbers (not picked by others OR by current player)
    list availableNumbers = [];
    integer i;
    for (i = 1; i <= diceType; i++) {
        string numStr = (string)i;
        integer pickedByOthers = llListFindList(globallyPickedNumbers, [numStr]) != -1;
        integer pickedByMe = llListFindList(currentPicks, [numStr]) != -1;
        if (!pickedByOthers && !pickedByMe) {
            availableNumbers += [numStr];
        }
    }
    
    // Get the subset for this page
    integer startIdx = page * NUMBERS_PER_PAGE;
    integer endIdx = startIdx + NUMBERS_PER_PAGE - 1;
    if (endIdx >= llGetListLength(availableNumbers)) {
        endIdx = llGetListLength(availableNumbers) - 1;
    }
    
    list buttons = [];
    for (i = startIdx; i <= endIdx && i < llGetListLength(availableNumbers); i++) {
        buttons += [llList2String(availableNumbers, i)];
    }
    return buttons;
}

showPickDialog(string name, key id, integer diceType, integer picks) {
    dbg("🎮 [NumberPicker] 📋 showPickDialog called for " + name + ", dice:" + (string)diceType + ", picks:" + (string)picks);
    
    if (diceType <= 0) {
        dbg("🎮 [Number Picker Dialog] ⚠️ Cannot show dialog: diceType is 0 or invalid.");
        return;
    }

    // Initialize or update picking session
    if (currentPlayer != name) {
        dbg("🎮 [NumberPicker] 📋 Starting new session for " + name);
        currentPlayer = name;
        currentPlayerKey = id;
        currentDiceType = diceType;
        picksNeeded = picks;
        currentPicks = [];
        currentPage = 0;
    } else {
        dbg("🎮 [NumberPicker] 📋 Updating existing session for " + name);
    }

    list options;
    integer totalPages = 1; // Default value
    
    // If player has picked enough numbers, only show Done button
    if (llGetListLength(currentPicks) >= picksNeeded) {
        options = ["✅ Done"];
    } else {
        // Show number selection with pagination
        options = getNumbersForPage(currentPage, diceType);
        
        // If current page has no numbers, go back to page 0
        if (llGetListLength(options) == 0 && currentPage > 0) {
            currentPage = 0;
            options = getNumbersForPage(currentPage, diceType);
        }
        
        // Calculate total pages based on available numbers, not all numbers
        integer availableCount = diceType - llGetListLength(globallyPickedNumbers) - llGetListLength(currentPicks);
        totalPages = (availableCount + NUMBERS_PER_PAGE - 1) / NUMBERS_PER_PAGE;
        if (totalPages < 1) totalPages = 1;
        
        // Only show navigation if there are multiple pages AND current page has numbers
        if (totalPages > 1 && llGetListLength(options) > 0) {
            if (currentPage > 0) options += ["◀ Prev"];
            if (currentPage < totalPages - 1) options += ["Next ▶"];
        }
    }

    string pickText = (string)picksNeeded;
    if (picksNeeded == 1) pickText += " number";
    else pickText += " numbers";
    
    string pageInfo = "";
    if (totalPages > 1) {
        pageInfo = " (Page " + (string)(currentPage + 1) + "/" + (string)totalPages + ")";
    }
    
    string dialogText;
    string currentPicksText = "";
    if (llGetListLength(currentPicks) > 0) {
        currentPicksText = "\nSelected: " + llList2CSV(currentPicks);
    }
    
    if (llGetListLength(currentPicks) >= picksNeeded) {
        dialogText = "✅ You have picked enough numbers!" + currentPicksText + "\n\nClick Done to confirm your selection.";
    } else {
        dialogText = "Pick " + pickText + " (1-" + (string)diceType + ")" + pageInfo + currentPicksText;
    }
    
    dbg("🎮 [NumberPicker] 📋 About to show dialog to " + name + " (" + (string)id + ")");
    dbg("🎮 [NumberPicker] 📋 Dialog text: " + dialogText);
    dbg("🎮 [NumberPicker] 📋 Options (" + (string)llGetListLength(options) + "): " + llList2CSV(options));
    dbg("🎮 [NumberPicker] 📋 Channel: " + (string)numberPickChannel);
    dbg("🎮 [NumberPicker] 📋 globallyPickedNumbers: " + llList2CSV(globallyPickedNumbers));
    
    llDialog(id, dialogText, options, numberPickChannel);
}

default {
    state_entry() {
        reportMemoryUsage("🎮 NumberPicker Dialog");
        
        // Initialize dynamic channels
        initializeChannels();
        numberPickChannel = NUMBERPICK_CHANNEL; // Set legacy variable
        
        // Clean up any existing listeners
        if (listenHandle != -1) {
            llListenRemove(listenHandle);
        }
        
        // Initialize/reset all dialog state
        currentPlayer = "";
        currentPlayerKey = NULL_KEY;
        currentDiceType = 0;
        picksNeeded = 1;
        currentPicks = [];
        globallyPickedNumbers = [];
        currentPage = 0;
        
        // Set up managed listener with dynamic channel
        listenHandle = llListen(numberPickChannel, "", NULL_KEY, "");
        dbg("🎮 [NumberPicker] Number Picker Dialog Handler ready!");
    }
    
    on_rez(integer start_param) {
        reportMemoryUsage("🎮 NumberPicker Dialog");
        
        dbg("🎮 [NumberPicker] 🔄 Number Picker rezzed - reinitializing...");
        
        // Re-initialize dynamic channels
        initializeChannels();
        numberPickChannel = NUMBERPICK_CHANNEL;
        
        // Clean up any existing listeners
        if (listenHandle != -1) {
            llListenRemove(listenHandle);
        }
        
        // Reset all dialog state variables
        currentPlayer = "";
        currentPlayerKey = NULL_KEY;
        currentDiceType = 0;
        picksNeeded = 1;
        currentPicks = [];
        globallyPickedNumbers = [];
        currentPage = 0;
        
        // Set up managed listener with dynamic channel
        listenHandle = llListen(numberPickChannel, "", NULL_KEY, "");
        dbg("🎮 [NumberPicker] ✅ Number Picker reset complete after rez!");
    }
    
    link_message(integer sender, integer num, string str, key id) {
        // Handle dialog close command
        if (num == MSG_CLOSE_ALL_DIALOGS && str == "CLOSE_ALL_DIALOGS") {

            dbg("🎮 [NumberPicker] 🚫 CLOSE_ALL_DIALOGS received! currentPlayer: " + currentPlayer + ", key: " + (string)currentPlayerKey);
            
            if (currentPlayerKey != NULL_KEY) {
                dbg("🎮 [NumberPicker] 🚫 Forced dialog close for " + currentPlayer);
                currentPlayer = "";
                currentPlayerKey = NULL_KEY;
                currentPicks = [];
            } else {
                dbg("🎮 [NumberPicker] 🚫 No active dialog to close");
            }
            return;
        }
        
        // Handle full reset from main controller
        if (num == MSG_RESET_ALL && str == "FULL_RESET") {
            // Reset all dialog state
            currentPlayer = "";
            currentPlayerKey = NULL_KEY;
            currentDiceType = 0;
            picksNeeded = 1;
            currentPicks = [];
            globallyPickedNumbers = [];
            currentPage = 0;
            dbg("🎮 [NumberPicker] Number Picker Dialog Handler reset!");
            return;
        }
        
        if (num == MSG_SHOW_DIALOG) {
            list parts = llParseString2List(str, ["|"], []);
            if (llGetListLength(parts) < 3) {
                dbg("🎮 [NumberPicker] ⚠️ Malformed MSG_SHOW_DIALOG input: " + str);
                return;
            }

            string name = llList2String(parts, 0);
            integer diceType = (integer)llList2String(parts, 1);
            integer picks = (integer)llList2String(parts, 2);
            
            // Get globally picked numbers if provided
            if (llGetListLength(parts) >= 4) {
                string globalPicksStr = llList2String(parts, 3);
                if (globalPicksStr != "") {
                    // IMPROVED: Handle mixed formats properly
                    globallyPickedNumbers = [];
                    
                    // First split by comma to handle CSV format
                    list csvParts = llParseString2List(globalPicksStr, [","], []);
                    integer i;
                    for (i = 0; i < llGetListLength(csvParts); i++) {
                        string part = llStringTrim(llList2String(csvParts, i), STRING_TRIM);
                        
                        // Check if this part contains semicolons (bot format)
                        if (llSubStringIndex(part, ";") != -1) {
                            // Split this part by semicolon and add each number
                            list semiParts = llParseString2List(part, [";"], []);
                            integer j;
                            for (j = 0; j < llGetListLength(semiParts); j++) {
                                string num = llStringTrim(llList2String(semiParts, j), STRING_TRIM);
                                if (num != "" && llListFindList(globallyPickedNumbers, [num]) == -1) {
                                    globallyPickedNumbers += [num];
                                }
                            }
                        } else {
                            // Single number, add it if not already present
                            if (part != "" && llListFindList(globallyPickedNumbers, [part]) == -1) {
                                globallyPickedNumbers += [part];
                            }
                        }
                    }
                } else {
                    globallyPickedNumbers = [];
                }
            } else {
                globallyPickedNumbers = [];
            }
            
            showPickDialog(name, id, diceType, picks);
        }
        
        // Handle dialog recovery requests
        else if (num == MSG_GET_CURRENT_DIALOG) {
            string playerName = str;
            // Only show dialog if this player is the current picker
            if (currentPlayer == playerName && currentPlayerKey == id) {
                dbg("🎮 [NumberPicker] 🔄 Restoring dialog for " + playerName);
                showPickDialog(currentPlayer, currentPlayerKey, currentDiceType, picksNeeded);
            } else {
                llRegionSayTo(id, 0, "❌ You don't have an active dialog to restore.");
            }
        }
    }

    listen(integer channel, string name, key id, string message) {
        // Ignore any responses if no active dialog session
        if (currentPlayerKey == NULL_KEY || currentPlayer == "") {
            dbg("🎮 [NumberPicker] 🚫 Ignoring stale dialog response (no active session). Player: " + name + ", Key: " + (string)id + ", Message: " + message);
            return;
        }
        
        // Ignore responses from wrong player
        if (id != currentPlayerKey) {
            dbg("🎮 [NumberPicker] 🚫 Ignoring dialog response from wrong player. Expected: " + (string)currentPlayerKey + ", Got: " + (string)id + ", Message: " + message);
            return;
        }
        
        // Additional validation: if this is a number selection, make sure it's still valid
        integer messageNum = (integer)message;
        if (messageNum > 0 && messageNum <= currentDiceType) {
            // This looks like a number selection - verify it's not already globally picked
            if (llListFindList(globallyPickedNumbers, [message]) != -1) {
                dbg("🎮 [NumberPicker] 🚫 Ignoring stale dialog response - number " + message + " already globally picked. Player: " + name);
                return;
            }
            
            // Also verify it's not already in current picks
            if (llListFindList(currentPicks, [message]) != -1) {
                dbg("🎮 [NumberPicker] 🚫 Ignoring stale dialog response - number " + message + " already in current picks. Player: " + name);
                return;
            }
        }
        
        // Handle navigation
        if (message == "◀ Prev") {
            if (currentPage > 0) {
                currentPage--;
                showPickDialog(currentPlayer, currentPlayerKey, currentDiceType, picksNeeded);
            }
            return;
        }
        if (message == "Next ▶") {
            // Calculate total pages based on AVAILABLE numbers, not all dice numbers
            integer availableCount = currentDiceType - llGetListLength(globallyPickedNumbers) - llGetListLength(currentPicks);
            integer totalPages = (availableCount + NUMBERS_PER_PAGE - 1) / NUMBERS_PER_PAGE;
            if (totalPages < 1) totalPages = 1;
            
            if (currentPage < totalPages - 1) {
                currentPage++;
                showPickDialog(currentPlayer, currentPlayerKey, currentDiceType, picksNeeded);
            }
            return;
        }
        
        // Handle completion
        if (message == "✅ Done") {
            dbg("📋 [NumberPicker] Done button clicked by " + name + ", currentPicks: " + llList2CSV(currentPicks) + ", needed: " + (string)picksNeeded);
            if (llGetListLength(currentPicks) >= picksNeeded) {
                string picksStr = llList2CSV(currentPicks);
                string response = "HUMAN_PICKED:" + currentPlayer + ":" + picksStr;
                dbg("📤 [NumberPicker] SENDING HUMAN_PICKED: " + response);
                llMessageLinked(LINK_SET, MSG_HUMAN_PICKED, response, NULL_KEY);
                // Reset state
                dbg("🎮 [NumberPicker] 📋 Resetting session state for " + currentPlayer);
                currentPlayer = "";
                currentPlayerKey = NULL_KEY;
                currentPicks = [];
            } else {
                dbg("🎮 [NumberPicker] ⚠️ " + currentPlayer + " needs " + (string)(picksNeeded - llGetListLength(currentPicks)) + " more picks");
                showPickDialog(currentPlayer, currentPlayerKey, currentDiceType, picksNeeded);
            }
            return;
        }
        
        // Handle number selection
        integer pickedNumber = (integer)message;
        if (pickedNumber > 0 && pickedNumber <= currentDiceType) {
            if (llGetListLength(currentPicks) < picksNeeded) {
                // Add to picks (numbers already picked won't be shown in dialog)
                currentPicks += [message];
            } else {
                dbg("🎮 [NumberPicker] ⚠️ " + currentPlayer + " has already picked enough numbers");
            }
            
            // Show updated dialog
            showPickDialog(currentPlayer, currentPlayerKey, currentDiceType, picksNeeded);
        }
    }
}