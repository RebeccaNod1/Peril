// === Dialog Handler (Updated for Peril Dice - Paginated Multiple Picks) ===

integer MSG_SHOW_DIALOG = 101;
integer numberPickChannel = -77888;

// Pagination and picking state
string currentPlayer = "";
key currentPlayerKey = NULL_KEY;
integer currentDiceType = 0;
integer picksNeeded = 1;
list currentPicks = [];
list globallyPickedNumbers = []; // Numbers already picked by other players
integer currentPage = 0;
integer NUMBERS_PER_PAGE = 9; // Leave room for navigation buttons

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
    llOwnerSay("🎮 showPickDialog called: name=" + name + ", id=" + (string)id + ", diceType=" + (string)diceType + ", picks=" + (string)picks);
    if (diceType <= 0) {
        llOwnerSay("⚠️ Cannot show dialog: diceType is 0 or invalid.");
        return;
    }

    // Initialize or update picking session
    if (currentPlayer != name) {
        currentPlayer = name;
        currentPlayerKey = id;
        currentDiceType = diceType;
        picksNeeded = picks;
        currentPicks = [];
        currentPage = 0;
    }

    list options;
    integer totalPages = 1; // Default value
    
    // If player has picked enough numbers, only show Done button
    if (llGetListLength(currentPicks) >= picksNeeded) {
        options = ["✅ Done"];
    } else {
        // Show number selection with pagination
        options = getNumbersForPage(currentPage, diceType);
        
        // Calculate total pages based on available numbers, not all numbers
        integer availableCount = diceType - llGetListLength(globallyPickedNumbers) - llGetListLength(currentPicks);
        totalPages = (availableCount + NUMBERS_PER_PAGE - 1) / NUMBERS_PER_PAGE;
        if (totalPages < 1) totalPages = 1;
        if (totalPages > 1) {
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
    
    llOwnerSay("🗨️ Showing dialog to: " + name + " - needs " + pickText + pageInfo);
    llDialog(id, dialogText, options, numberPickChannel);
}

default {
    state_entry() {
        llOwnerSay("🎮 Number Picker Dialog Handler ready!");
        llListen(numberPickChannel, "", NULL_KEY, "");
    }

    link_message(integer sender, integer num, string str, key id) {
        llOwnerSay("📥 Dialog Handler received: num=" + (string)num + ", str=" + str + ", id=" + (string)id);
        if (num == MSG_SHOW_DIALOG) {
            llOwnerSay("✅ Processing MSG_SHOW_DIALOG...");
            list parts = llParseString2List(str, ["|"], []);
            if (llGetListLength(parts) < 3) {
                llOwnerSay("⚠️ Malformed MSG_SHOW_DIALOG input: " + str);
                return;
            }

            string name = llList2String(parts, 0);
            integer diceType = (integer)llList2String(parts, 1);
            integer picks = (integer)llList2String(parts, 2);
            
            // Get globally picked numbers if provided
            if (llGetListLength(parts) >= 4) {
                string globalPicksStr = llList2String(parts, 3);
                if (globalPicksStr != "") {
                    globallyPickedNumbers = llCSV2List(globalPicksStr);
                } else {
                    globallyPickedNumbers = [];
                }
            } else {
                globallyPickedNumbers = [];
            }
            
            llOwnerSay("🎯 Calling showPickDialog for " + name + " with diceType=" + (string)diceType + ", picks=" + (string)picks);
            if (llGetListLength(globallyPickedNumbers) > 0) {
                llOwnerSay("📋 Available numbers: " + (string)(diceType - llGetListLength(globallyPickedNumbers)) + "/" + (string)diceType);
            }
            showPickDialog(name, id, diceType, picks);
        }
    }

    listen(integer channel, string name, key id, string message) {
        llOwnerSay("🔊 Listen triggered: " + message + " from " + name);
        
        // Handle navigation
        if (message == "◀ Prev") {
            if (currentPage > 0) {
                currentPage--;
                showPickDialog(currentPlayer, currentPlayerKey, currentDiceType, picksNeeded);
            }
            return;
        }
        if (message == "Next ▶") {
            integer totalPages = (currentDiceType + NUMBERS_PER_PAGE - 1) / NUMBERS_PER_PAGE;
            if (currentPage < totalPages - 1) {
                currentPage++;
                showPickDialog(currentPlayer, currentPlayerKey, currentDiceType, picksNeeded);
            }
            return;
        }
        
        // Handle completion
        if (message == "✅ Done") {
            if (llGetListLength(currentPicks) >= picksNeeded) {
                string picksStr = llList2CSV(currentPicks);
                llOwnerSay("✅ " + currentPlayer + " completed picks: " + picksStr);
                string response = "HUMAN_PICKED:" + currentPlayer + ":" + picksStr;
                llOwnerSay("📡 Sending to Main Controller: " + response);
                llMessageLinked(LINK_SET, -9998, response, NULL_KEY);
                // Reset state
                currentPlayer = "";
                currentPlayerKey = NULL_KEY;
                currentPicks = [];
            } else {
                llOwnerSay("⚠️ " + currentPlayer + " needs " + (string)(picksNeeded - llGetListLength(currentPicks)) + " more picks");
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
                llOwnerSay("✅ " + currentPlayer + " picked: " + message + " (" + (string)llGetListLength(currentPicks) + "/" + (string)picksNeeded + ")");
            } else {
                llOwnerSay("⚠️ " + currentPlayer + " has already picked enough numbers");
            }
            
            // Show updated dialog
            showPickDialog(currentPlayer, currentPlayerKey, currentDiceType, picksNeeded);
        }
    }
}