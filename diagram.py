import graphviz

dot = graphviz.Digraph()

# Main states
dot.node("Start", "🎲 Game Ready")
dot.node("Join", "👤 Player Joins via Touch")
dot.node("StartCmd", "🚩 /start Command")
dot.node("SelectPeril", "🔥 Select Peril Player")
dot.node("ShowDialog", "🗨️ Show Pick Dialog")
dot.node("Pick", "🎲 Player Picks Number")
dot.node("UpdateFloat", "📤 Update Float Display")
dot.node("SyncState", "🔄 Sync Game State")
dot.node("Leave", "🚪 Player Leaves")
dot.node("Reset", "♻️ Reset Game")

# Transitions
dot.edges([("Start", "Join"),
           ("Join", "SyncState"),
           ("Join", "UpdateFloat"),
           ("Start", "StartCmd"),
           ("StartCmd", "SelectPeril"),
           ("SelectPeril", "SyncState"),
           ("SelectPeril", "UpdateFloat"),
           ("SelectPeril", "ShowDialog"),
           ("ShowDialog", "Pick"),
           ("Pick", "UpdateFloat"),
           ("Pick", "SyncState"),
           ("Join", "Leave"),
           ("Start", "Reset"),
           ("Reset", "SyncState")])

dot.attr(label="🧭 Peril Dice Game Controller Flow", labelloc="top", fontsize="20")

dot.render('/home/richard/peril//peril_game_flowchart', format='png', cleanup=False)
'/home/richard/peril/peril_game_flowchart.png'
