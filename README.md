🎲 Peril Dice — Modular Game System for Second Life
Overview
Peril Dice is a multiplayer elimination game where each player selects numbers before a die is rolled. If the peril player’s number is rolled, they lose a life. Players are eliminated when they reach zero lives.

🔧 Features
✅ Player System
Max players: 10

Each player starts with 3 lives

Players can Join, Leave, or mark themselves Ready

The first player to join gets a Start Game button

The owner can join the game and also has a special Owner menu

🎲 Dice Scaling
Dice type is automatically chosen to ensure at least 3 picks per player

Dice types supported: d6, d12, d20, d30

Player Count	Dice Type
1–2	d6
3–4	d12
5–6	d20
7–10	d30

🧍 Test Players
Owner can add/remove test players (bots)

Test players rez stat floaters at offset positions to prevent overlap

Floater objects follow players and update in real time

🪟 HUD & Stat Floaters
Players receive a floating HUD showing:

Player name

Lives

Picks

Peril status or game state

📦 Modular Architecture
Separated scripts:

Main Controller: Handles core game logic

Dialog Handler: Manages pick dialogs

Dice Selector: Returns dice type based on player count

Stat Float Manager: Rezzes and updates floaters

Stat Float Object: Displays floating text per player

🕹️ Game Flow
Players touch the controller object to join the game

Once 2+ players have joined, the first player gets the option to Start Game

Dice type is selected automatically

Each player is prompted (in order) to select 3 numbers

After all picks are made:

The dice is rolled

The result is compared to each player’s picks

If the peril player’s number is rolled or no one picked it, the peril player loses a life

The system checks for eliminations and starts the next round

🧰 Admin Controls
Owner can:

Join or leave the game

Open a special Owner menu

Add/remove test bots

Reset the game

Debug current state (optional)



Below what was started, ill have this up just a reminder




# Peril Dice
Notice these rules were made by Noose the Bunny (djmusica28)  secondlife:///app/agent/5935e159-63ba-415a-b20b-4813b50367d0/about, im baseing off this but im also automating it

🎲 PERIL DICE – GAME RULES
🧍 Objective:
Avoid becoming the “person in peril” and losing all your lives.
The last player with lives remaining wins!

🛠️ Setup
Each player wears a Peril Dice Tracker HUD

Everyone starts with 3 lives

Choose a dice type: d6, d12, or d21

One player clicks "Set Yourself In Peril" on the HUD to start

🔁 Game Rounds
1. Determine Lives of Person in Peril

3 Lives → Each player picks 1 number

2 Lives → Each player picks 2 numbers

1 Life → Each player picks 3 numbers

2. Players Pick Numbers
Everyone (including the player in peril) picks their numbers from the die range.
Example: On a d12 with 2 lives in peril → pick 2 numbers between 1–12.

3. Roll the Die
Use a real or scripted dice object in SL to roll (matching your chosen type).

🎯 Check the Result
If the roll matches another player's pick →
That player becomes the new person in peril

If the roll matches no one, or the peril player’s own pick →
The peril player loses 1 life and stays in peril

💀 Elimination
When a player reaches 0 lives, they're eliminated from the game.

🏆 Winning the Game
The last remaining player with lives wins!

✅ Game Example
4 players, using a d12

Alice is in peril with 2 lives

Everyone picks 2 numbers:

makefile
Copy
Edit
Bob:   3, 7  
Carol: 6, 11  
Dave:  2, 9  
Alice: 1, 12
🎲 Roll = 6 → Carol becomes the new person in peril

📟 PERIL DICE TRACKER HUD GUIDE
Touch the tracker to access the menu:

🔘 Set Dice
Pick d6, d12, or d20 — defines the range of possible numbers.

🔘 Pick Numbers
Lets you pick numbers (based on how many the current person in peril is allowed).
Your picks are shown in the floating text.

🔘 Set Yourself in Peril
Marks you as the current player in peril. Everyone’s HUD will update with your name and lives.

🔘 Lose Life / Reset Lives
Used only by the wearer of the HUD to manage their own lives.
If you’re the player in peril, everyone else will see your life change reflected in their menus.

🧠 Odds of Rolling a Specific Number
Here’s the chance of any one number being rolled:

Dice    Total Sides    % Chance per Number
d6    6    16.7%
d12    12    8.3%
d20    20    5.0%

The more numbers you can pick, the better your odds — but lives are limited!
# Peril Dice
