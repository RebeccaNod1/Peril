//////////////////////////////////////////// 
// XyzzyText v2.1 Script (Set Line Color) by Huney Jewell
// Modified to listen directly to scoreboard channel
//
//////////////////////////////////////////// 

/////////////// CONSTANTS /////////////////// 
// XyText Message Map. 
integer DISPLAY_STRING      = 204000; 
integer DISPLAY_EXTENDED    = 204001; 
integer REMAP_INDICES       = 204002; 
integer RESET_INDICES       = 204003; 
integer SET_FADE_OPTIONS    = 204004; 
integer SET_FONT_TEXTURE    = 204005; 
integer SET_LINE_COLOR      = 204006; 
integer SET_COLOR           = 204007; 
integer RESCAN_LINKSET      = 204008;

//internal API
integer REGISTER_SLAVE      = 205000;
integer SLAVE_RECOGNIZED    = 205001;
integer SLAVE_DISPLAY       = 205003;
integer SLAVE_DISPLAY_EXTENDED = 205004;
integer SLAVE_RESET = 205005;

// Communication channel from scoreboard
integer LEADERBOARD_CHANNEL = -12346;

// This is an extended character escape sequence. 
string  ESCAPE_SEQUENCE = "\\e"; 

// This is used to get an index for the extended character. 
string  EXTENDED_INDEX  = "12345"; 

// Face numbers. 
integer FACE_1          = 3; 
integer FACE_2          = 7; 
integer FACE_3          = 4; 
integer FACE_4          = 6; 
integer FACE_5          = 1; 

// Used to hide the text after a fade-out. 
key     TRANSPARENT     = "701917a8-d614-471f-13dd-5f4644e36e3c";
key     null_key        = NULL_KEY;
///////////// END CONSTANTS //////////////// 

///////////// GLOBAL VARIABLES /////////////// 
// This is the key of the font we are displaying. 
key     gFontTexture        = "b2e7394f-5e54-aa12-6e1c-ef327b6bed9e"; 
// All displayable characters.  Default to ASCII order. 
string gCharIndex; 

// This is whether or not to use the fade in/out special effect. 
integer gCellUseFading      = FALSE; 
// This is how long to display the text before fading out (if using 
// fading special effect). 
// Note: < 0  means don't fade out. 
float   gCellHoldDelay      = 1.0; 

integer gSlaveRegistered;
list gSlaveNames;

integer BANK_STRIDE=3; //offset, length, highest_dirty
list gBankingData;

list gXyTextPrims; //rather than make it generic, we just reuse this from the original script

//////////////////////////////////////////////////////////////
// *** IMPORTANT: SET THIS FOR EACH XYZZYTEXT OBJECT ***
//  
//  Bank 0 = LEFT display   (set MY_BANK = 0;)
//  Bank 1 = MIDDLE display (set MY_BANK = 1;) 
//  Bank 2 = RIGHT display  (set MY_BANK = 2;)
//
//////////////////////////////////////////////////////////////
integer MY_BANK = 1; // ← CHANGE THIS NUMBER FOR EACH OBJECT!

/////////// END GLOBAL VARIABLES //////////// 

ResetCharIndex() { 
   gCharIndex  = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`"; 
   gCharIndex += "abcdefghijklmnopqrstuvwxyz{|}~"; 
   gCharIndex += "\\n\\n\\n\\n\\n"; 
} 

vector GetGridOffset(integer index) { 
   // Calculate the offset needed to display this character. 
   integer Row = index / 10; 
   integer Col = index % 10; 

   // Return the offset in the texture. 
   return <-0.45 + 0.1 * Col, 0.45 - 0.1 * Row, 0.0>; 
} 

ShowChars(integer link,vector grid_offset1, vector grid_offset2, vector grid_offset3, vector grid_offset4, vector grid_offset5) { 
   // Set the primitive textures directly. 
    
   llSetLinkPrimitiveParamsFast( link,[ 
        PRIM_TEXTURE, FACE_1, (string)gFontTexture, <0.126, 0.1, 0>, grid_offset1 + <0.037, 0, 0>, 0.0, 
        PRIM_TEXTURE, FACE_2, (string)gFontTexture, <0.05, 0.1, 0>, grid_offset2, 0.0, 
        PRIM_TEXTURE, FACE_3, (string)gFontTexture, <-0.74, 0.1, 0>, grid_offset3 - <0.244, 0, 0>, 0.0, 
        PRIM_TEXTURE, FACE_4, (string)gFontTexture, <0.05, 0.1, 0>, grid_offset4, 0.0, 
        PRIM_TEXTURE, FACE_5, (string)gFontTexture, <0.126, 0.1, 0>, grid_offset5 - <0.037, 0, 0>, 0.0 
        ]); 
} 

RenderString(integer link, string str) { 
   // Get the grid positions for each pair of characters. 
   vector GridOffset1 = GetGridOffset( llSubStringIndex(gCharIndex, llGetSubString(str, 0, 0)) ); 
   vector GridOffset2 = GetGridOffset( llSubStringIndex(gCharIndex, llGetSubString(str, 1, 1)) ); 
   vector GridOffset3 = GetGridOffset( llSubStringIndex(gCharIndex, llGetSubString(str, 2, 2)) ); 
   vector GridOffset4 = GetGridOffset( llSubStringIndex(gCharIndex, llGetSubString(str, 3, 3)) ); 
   vector GridOffset5 = GetGridOffset( llSubStringIndex(gCharIndex, llGetSubString(str, 4, 4)) ); 

   // Use these grid positions to display the correct textures/offsets. 
   ShowChars(link,GridOffset1, GridOffset2, GridOffset3, GridOffset4, GridOffset5); 
} 

RenderWithEffects(integer link, string str) { 
   // Get the grid positions for each pair of characters. 
   vector GridOffset1 = GetGridOffset( llSubStringIndex(gCharIndex, llGetSubString(str, 0, 0)) ); 
   vector GridOffset2 = GetGridOffset( llSubStringIndex(gCharIndex, llGetSubString(str, 1, 1)) ); 
   vector GridOffset3 = GetGridOffset( llSubStringIndex(gCharIndex, llGetSubString(str, 2, 2)) ); 
   vector GridOffset4 = GetGridOffset( llSubStringIndex(gCharIndex, llGetSubString(str, 3, 3)) ); 
   vector GridOffset5 = GetGridOffset( llSubStringIndex(gCharIndex, llGetSubString(str, 4, 4)) ); 

   // First set the alpha to the lowest possible. 
   llSetLinkAlpha(link,0.05, ALL_SIDES); 

   // Use these grid positions to display the correct textures/offsets. 
   ShowChars(link,GridOffset1, GridOffset2, GridOffset3, GridOffset4, GridOffset5);          // Now turn up the alpha until it is at full strength. 
    float Alpha = 0.10; 
    for (; Alpha <= 1.0; Alpha += 0.05) 
       llSetLinkAlpha(link,Alpha, ALL_SIDES); 
          // See if we want to fade out as well. 
   if (gCellHoldDelay < 0.0) 
       // No, bail out. (Just keep showing the string at full strength). 
       return; 
          // Hold the text for a while. 
   llSleep(gCellHoldDelay); 
      // Now fade out. 
   for (Alpha = 0.95; Alpha >= 0.05; Alpha -= 0.05) 
       llSetLinkAlpha(link,Alpha, ALL_SIDES); 
          // Make the text transparent to fully hide it. 
   llSetLinkTexture(link,TRANSPARENT, ALL_SIDES); 
} 

integer RenderExtended(integer link, string str, integer render) {
   // Look for escape sequences. 
   integer length = 0;
   list Parsed       = llParseString2List(str, [], (list)ESCAPE_SEQUENCE); 
   integer ParsedLen = llGetListLength(Parsed); 

   // Create a list of index values to work with. 
   list Indices; 
   // We start with room for 5 indices. 
   integer IndicesLeft = 5; 

   string Token; 
   integer Clipped; 
   integer LastWasEscapeSequence = FALSE; 
   // Work from left to right. 
   integer i = 0;
   for (; i < ParsedLen && IndicesLeft > 0; ++i) { 
       Token = llList2String(Parsed, i); 

       // If this is an escape sequence, just set the flag and move on. 
       if (Token == ESCAPE_SEQUENCE) { 
           LastWasEscapeSequence = TRUE; 
       } 
       else { // Token != ESCAPE_SEQUENCE 
           // Otherwise this is a normal token.  Check its length. 
           Clipped = FALSE; 
           integer TokenLength = llStringLength(Token); 
           // Clip if necessary. 
           if (TokenLength > IndicesLeft) { 
               TokenLength = llStringLength(Token = llGetSubString(Token, 0, IndicesLeft - 1)); 
               IndicesLeft = 0; 
               Clipped = TRUE; 
           } 
           else 
               IndicesLeft -= TokenLength; 

           // Was the previous token an escape sequence? 
           if (LastWasEscapeSequence) { 
               // Yes, the first character is an escape character, the rest are normal. 
               length += 2 + TokenLength;
               if(render)
               {
                    // This is the extended character. 
                    Indices += (llSubStringIndex(EXTENDED_INDEX, llGetSubString(Token, 0, 0)) + 95);
                    
                    // These are the normal characters.
                    integer j = 1;
                    for(; j < TokenLength; ++j) {
                        Indices += llSubStringIndex(gCharIndex, llGetSubString(Token, j, j));
                    }
               }
               LastWasEscapeSequence = FALSE; 
           } 
           else { 
               // Nope, just normal characters. 
               length += TokenLength;
               if(render)
               {
                    // Just add the characters normally. 
                    integer j = 0;
                    for(; j < TokenLength; ++j) { 
                        Indices += llSubStringIndex(gCharIndex, llGetSubString(Token, j, j)); 
                    }
               }
           } 

           // Bail out if this was a clipped token. 
           if (Clipped) 
               i = ParsedLen; 
       } 
   } 

   if(render) {
       // Make sure we have 5 indices. 
       integer IndicesCount = llGetListLength(Indices); 
       for (; IndicesCount < 5; ++IndicesCount) { 
           Indices += (llSubStringIndex(gCharIndex, " ")); 
       } 

       // Use the indices to create grid positions. 
       vector GridOffset1 = GetGridOffset( llList2Integer(Indices, 0) ); 
       vector GridOffset2 = GetGridOffset( llList2Integer(Indices, 1) ); 
       vector GridOffset3 = GetGridOffset( llList2Integer(Indices, 2) ); 
       vector GridOffset4 = GetGridOffset( llList2Integer(Indices, 3) ); 
       vector GridOffset5 = GetGridOffset( llList2Integer(Indices, 4) ); 

       // Use these grid positions to display the correct textures/offsets. 
       ShowChars(link,GridOffset1, GridOffset2, GridOffset3, GridOffset4, GridOffset5); 
   }
   return length;
} 

integer ConvertIndex(integer index) { 
   // This function is used to convert from an ASCII based index to our 
   // internal representation. 
   if (index >= 32) 
       // ASCII character, subtract 32. 
       return index - 32; 
   else if (index == 10) 
       // Newline character. 
       return 94; 
   else 
       // Everything else is a space. 
       return 0; 
}

PassToRender(integer render_type, string message, integer bank) {
    if(bank != MY_BANK) {
        // This message is not for our bank, ignore it
        return;
    }
    
    list lines = llParseString2List(message, ["\n"], []);
    integer line_count = llGetListLength(lines);
    
    //get the bank offset and length
    integer i = llList2Integer(gBankingData, (bank * BANK_STRIDE));
    integer bank_end = i + llList2Integer(gBankingData, (bank * BANK_STRIDE) + 1);
    
    for(; i < bank_end && (i - llList2Integer(gBankingData, (bank * BANK_STRIDE))) < line_count; ++i) {
        integer link = unpack(gXyTextPrims, i);
        if(link) {
            string line = llList2String(lines, i - llList2Integer(gBankingData, (bank * BANK_STRIDE)));
            
            if(render_type == 1) {
                RenderString(link, line);
            } else if(render_type == 2) {
                RenderExtended(link, line, TRUE);
            }
        }
    }
}

integer get_number_of_prims()
{//ignores avatars.
    integer a = llGetNumberOfPrims();
    //Mono tweak
    vector size = llGetAgentSize(llGetLinkKey(a));
    while(size.z > 0)
    {
        --a;
        size = llGetAgentSize(llGetLinkKey(a));
    }
    return a;
}

//functions to pack 8-bit shorts into ints
list pack_and_insert(list in_list, integer pos, integer value)
{
    //Safe optimized version
    integer index = pos >> 2;
    return llListReplaceList(in_list, (list)(llList2Integer(in_list, index) | (value << ((pos & 3) << 3))), index, index);
}

integer unpack(list in_list, integer pos)
{
    return (llList2Integer(in_list, pos >> 2) >> ((pos & 3) << 3)) & 0x000000FF;//unsigned
}

change_color(vector color)
{
    integer num_prims=llGetListLength(gXyTextPrims) << 2;
    
    integer i = 0;
    
    for (; i<=num_prims; ++i)
    {
        integer link = unpack(gXyTextPrims,i);
        if (!link)
            return;
        
        llSetLinkPrimitiveParamsFast( link,[ 
            PRIM_COLOR, FACE_1, color, 1.0,
            PRIM_COLOR, FACE_2, color, 1.0,
            PRIM_COLOR, FACE_3, color, 1.0,
            PRIM_COLOR, FACE_4, color, 1.0,
            PRIM_COLOR, FACE_5, color, 1.0
        ]);
    }
}

change_line_color(integer bank, vector color)
{    

    //get the bank offset and length
    integer i = llList2Integer(gBankingData, (bank * BANK_STRIDE));
    integer bank_end = i + llList2Integer(gBankingData, (bank * BANK_STRIDE) + 1);

    for (; i < bank_end; ++i)
    {     
        integer link = unpack(gXyTextPrims,i);
        if (!link)
            return;
        
        llSetLinkPrimitiveParamsFast( link,[ 
            PRIM_COLOR, FACE_1, color, 1.0,
            PRIM_COLOR, FACE_2, color, 1.0,
            PRIM_COLOR, FACE_3, color, 1.0,
            PRIM_COLOR, FACE_4, color, 1.0,
            PRIM_COLOR, FACE_5, color, 1.0
        ]);
    }
}


init()
{
    integer num_prims=get_number_of_prims();
    string link_name;
    integer prims_pointer=0;
    
    list temp_bank = [];
    integer temp_bank_stride=2;
    
    //FIXME: font texture might should be per-bank
    llMessageLinked(LINK_THIS, SET_FONT_TEXTURE, "", gFontTexture);
    
    // moving this before the prim scan so that the slaves properly configure themseves before
    // any requests to display
    llMessageLinked(LINK_THIS, SLAVE_RESET, "" , null_key);
 
    gXyTextPrims=[];
    integer x=0;
    for (;x<64;++x)
    {
        gXyTextPrims = (gXyTextPrims = []) + gXyTextPrims + 0;  //we need to pad out the list to make it easier to add things in any order later
    }
    
    gBankingData = [];
    
    // Only look for prims that match MY_BANK
    for(x=0;x<=num_prims;++x)
    {
        link_name=llGetLinkName(x);
        
        list tmp = llParseString2List(link_name, (list)"-", []);
        if(llList2String(tmp,0) == "xyzzytext")
        {
            integer prim_bank = llList2Integer(tmp,1);
            integer prim_position = llList2Integer(tmp,2);
            
            if (prim_bank == MY_BANK)
            {
                temp_bank += prim_position + (list)x;
            }
        }
    }

    if (temp_bank != [])
    {
        //sort the current bank by position
        temp_bank = llListSort(temp_bank, temp_bank_stride, TRUE);
        
        integer temp_len = llGetListLength(temp_bank);
        
        //store metadata for MY_BANK at position MY_BANK in the banking data
        while(llGetListLength(gBankingData) <= (MY_BANK * BANK_STRIDE + 2)) {
            gBankingData += [0, 0, 0]; // pad the list
        }
        
        gBankingData = llListReplaceList(gBankingData, [prims_pointer, temp_len/temp_bank_stride, 0], 
                                        MY_BANK * BANK_STRIDE, MY_BANK * BANK_STRIDE + 2);
        
        //repack the bank into the prim list
        for (x = 0; x < temp_len; x += temp_bank_stride)
        {
            integer link_num = llList2Integer(temp_bank, x + 1);
            gXyTextPrims = pack_and_insert(gXyTextPrims, prims_pointer, link_num);
            ++prims_pointer;
        }
    }
    
    llOwnerSay("XyzzyText Bank " + (string)MY_BANK + " ready with " + (string)prims_pointer + " prims");
}


default { 
   state_entry() { 
       // Initialize the character index. 
       ResetCharIndex();
       
       // Listen for messages from scoreboard
       llListen(LEADERBOARD_CHANNEL, "", "", "");
       
       init();
   } 

   on_rez(integer num)
   {
      llResetScript();       
   }
   
   listen(integer channel, string name, key id, string message) {
        if (channel == LEADERBOARD_CHANNEL) {
            if (MY_BANK == 0 && llSubStringIndex(message, "LEFT_TEXT|") == 0) {
                // This is bank 0 (left), process LEFT_TEXT messages
                string leftText = llGetSubString(message, 10, -1);
                PassToRender(1, leftText, 0);
                
            } else if (MY_BANK == 1 && llSubStringIndex(message, "MIDDLE_TEXT|") == 0) {
                // This is bank 1 (middle), process MIDDLE_TEXT messages
                string middleText = llGetSubString(message, 12, -1);
                PassToRender(1, middleText, 1);
                
            } else if (MY_BANK == 2 && llSubStringIndex(message, "RIGHT_TEXT|") == 0) {
                // This is bank 2 (right), process RIGHT_TEXT messages
                string rightText = llGetSubString(message, 11, -1);
                PassToRender(1, rightText, 2);
                
            } else if (message == "CLEAR_LEADERBOARD") {
                // Clear display for this bank
                PassToRender(1, "     ", MY_BANK);
            }
        }
    }
   
   link_message(integer sender, integer channel, string data, key id) { 
        if (id==null_key)
            id="0";
            
        if (channel == DISPLAY_STRING) { 
            PassToRender(1,data, (integer)((string)id)); 
        } 
        else if (channel == DISPLAY_EXTENDED) { 
            PassToRender(2,data, (integer)((string)id)); 
        } 
        else if (channel == REMAP_INDICES) { 
            // Parse the message, splitting it up into index values. 
            list Parsed = llCSV2List(data); 
            integer i = 0; 
            // Go through the list and swap each pair of indices. 
            for (; i < llGetListLength(Parsed); i += 2) { 
                integer Index1 = ConvertIndex( llList2Integer(Parsed, i) ); 
                integer Index2 = ConvertIndex( llList2Integer(Parsed, i + 1) ); 
        
                // Swap these index values. 
                string Value1 = llGetSubString(gCharIndex, Index1, Index1); 
                string Value2 = llGetSubString(gCharIndex, Index2, Index2); 
        
                gCharIndex = llDeleteSubString(gCharIndex, Index1, Index1); 
                gCharIndex = llInsertString(gCharIndex, Index1, Value2);
        
                gCharIndex = llDeleteSubString(gCharIndex, Index2, Index2);
                gCharIndex = llInsertString(gCharIndex, Index2, Value1);
            } 
        } 
        else if (channel == RESCAN_LINKSET)
        {
            init();
        }
        else if (channel == RESET_INDICES) { 
            // Restore the character index back to default settings. 
            ResetCharIndex(); 
        } 
        else if (channel == SET_FADE_OPTIONS) { 
            list Parsed = llCSV2List(data); 
            gCellUseFading = llList2Integer(Parsed, 0); 
            gCellHoldDelay = llList2Float(Parsed, 1); 
        } 
        else if (channel == SET_FONT_TEXTURE) { 
            gFontTexture = id; 
        } 
        else if (channel == SET_LINE_COLOR) { 
            change_line_color((integer)data, (vector)((string)id));
        } 
        else if (channel == SET_COLOR) { 
            change_color((vector)data);
        } 
        else if (channel == REGISTER_SLAVE) { 
            gSlaveNames += data; 
            llMessageLinked(sender, SLAVE_RECOGNIZED, "", ""); 
        } 
   } 
}
