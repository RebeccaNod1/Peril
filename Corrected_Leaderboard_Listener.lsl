// Corrected Leaderboard Listener - uses link messages for XyzzyText v2.1
// Place one of these in each leaderboard object alongside XyzzyText v2.1
// Configure MY_BANK for each object: 0, 1, 2, or 3

integer MY_BANK = 0; // Change this for each bank: 0, 1, 2, or 3
integer LEADERBOARD_CHANNEL = -12346; // Match the scoreboard manager channel
integer DISPLAY_STRING = 204000; // XyzzyText constant

// Map bank numbers to message prefixes that scoreboard actually sends
list MESSAGE_PREFIXES = ["LEFT_TEXT", "MIDDLE_LEFT_TEXT", "MIDDLE_RIGHT_TEXT", "RIGHT_TEXT"];

default
{
    state_entry()
    {
        llListen(LEADERBOARD_CHANNEL, "", "", "");
        string prefix = llList2String(MESSAGE_PREFIXES, MY_BANK);
        llOwnerSay("Corrected Leaderboard Listener Bank " + (string)MY_BANK + " ready");
        llOwnerSay("Listening on channel " + (string)LEADERBOARD_CHANNEL);
        llOwnerSay("Looking for messages starting with: " + prefix);
        llOwnerSay("Will send link messages to XyzzyText on channel " + (string)DISPLAY_STRING);
        
        // Test XyzzyText with simple text first
        llSetTimerEvent(3.0);
    }
    
    timer()
    {
        llSetTimerEvent(0.0); // Stop timer
        llOwnerSay("=== TESTING XyzzyText with simple text ===");
        
        // Send simple test: "HELLO     " (10 chars) to first prim only
        llMessageLinked(LINK_SET, DISPLAY_STRING, "HELLO     ", (key)((string)0));
        llOwnerSay("Sent test text: 'HELLO     ' to XyzzyText bank 0");
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if (channel != LEADERBOARD_CHANNEL) return;
        
        // Get the expected message prefix for this bank
        string expectedPrefix = llList2String(MESSAGE_PREFIXES, MY_BANK);
        
        // Check if this message is for our bank
        if (llSubStringIndex(message, expectedPrefix + "|") == 0)
        {
            // Extract the text part (everything after the prefix and |)
            string text = llGetSubString(message, llStringLength(expectedPrefix) + 1, -1);
            
            llOwnerSay("=== BANK " + (string)MY_BANK + " RECEIVED ===");
            llOwnerSay("Message: " + message);
            llOwnerSay("Raw text: '" + text + "'");
            llOwnerSay("Text length: " + (string)llStringLength(text));
            
            // XyzzyText v2.1 expects one continuous string without newlines
            // Split the multi-line text and concatenate into one string
            list lines = llParseString2List(text, ["\n"], []);
            string continuousText = "";
            
            llOwnerSay("Processing " + (string)llGetListLength(lines) + " lines for XyzzyText");
            
            integer i;
            for (i = 0; i < llGetListLength(lines); i++) {
                string line = llList2String(lines, i);
                
                // Ensure each line is exactly 10 characters (pad or truncate)
                if (llStringLength(line) > 10) {
                    line = llGetSubString(line, 0, 9);  // Truncate to 10 chars
                } else if (llStringLength(line) < 10) {
                    // Pad with spaces to make exactly 10 characters
                    while (llStringLength(line) < 10) {
                        line += " ";
                    }
                }
                
                // Add this 10-character line to the continuous string
                continuousText += line;
                llOwnerSay("Line " + (string)i + ": '" + line + "'");
            }
            
            llOwnerSay("Sending continuous text (" + (string)llStringLength(continuousText) + " chars) to XyzzyText");
            
            // Send the continuous string to XyzzyText with bank 0
            llMessageLinked(LINK_SET, DISPLAY_STRING, continuousText, (key)((string)0));
            llOwnerSay("Sent continuous text to XyzzyText - bank: 0");
        }
        else if (message == "CLEAR_LEADERBOARD")
        {
            // Clear display for this bank - send blank lines
            llOwnerSay("=== BANK " + (string)MY_BANK + " CLEARING ===");
            string clearText = "          ";
            integer i;
            for (i = 1; i < 12; i++) {
                clearText += "          ";  // 12 lines of 10 spaces each = 120 chars total
            }
            
            llMessageLinked(LINK_SET, DISPLAY_STRING, clearText, (key)((string)0));
            llOwnerSay("Sent clear message to XyzzyText");
        }
    }
}
