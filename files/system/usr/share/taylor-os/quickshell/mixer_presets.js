// Equalizer presets for her Mixer window, organised by game (her brief: "Presets open as a searchable list organized
// by game"). THESE CURVES ARE MADE-UP PLACEHOLDERS, copied from the design preview: starting points, not tuned or
// measured for any game. Gains in dB for the ten bands at 32, 64, 125, 250, 500, 1k, 2k, 4k, 8k and 16k Hz (all Bell,
// width Q 1.4). "match": the window class(es) of the game, for Game's "Follow the game" (Steam games under Proton
// show as steam_app_<the game's Steam id>).
.pragma library

var made_up = "Made-up starting points from the design preview, not tuned for these games yet.";

var groups = [
    { group: "Games", items: [
        { name: "Deadlock", gains: [-4, -3, -1, 0, 1, 2, 4, 6, 3, 1], match: ["steam_app_1422450", "deadlock", "citadel"] },
        { name: "MTG Arena", gains: [1, 1, 0, 0, 0, 1, 2, 1, 1, 0], match: ["steam_app_2141910", "mtga"] },
        { name: "Footsteps", gains: [-6, -4, -2, 0, 1, 2, 5, 7, 3, 0], match: [] }
    ] },
    { group: "Everyday", items: [
        { name: "Flat", gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], match: [] },
        { name: "Bass boost", gains: [7, 6, 4, 2, 0, 0, 0, 0, 0, 0], match: [] },
        { name: "Music", gains: [3, 2, 1, 0, -1, 0, 1, 2, 3, 2], match: [] },
        { name: "Movie", gains: [4, 3, 1, 0, 0, 2, 3, 1, 1, 2], match: [] },
        { name: "Voice clarity", gains: [-5, -4, -2, 1, 3, 4, 4, 2, 0, -2], match: [] },
        { name: "Warm", gains: [3, 3, 2, 1, 0, -1, -1, -2, -3, -4], match: [] }
    ] }
];

function find(name) {
    for (var i = 0; i < groups.length; i++)
        for (var j = 0; j < groups[i].items.length; j++)
            if (groups[i].items[j].name === name) return groups[i].items[j];
    return null;
}

// the preset whose game owns this window class / title ("" when none)
function forWindow(appId, title) {
    var a = String(appId || "").toLowerCase(), t = String(title || "").toLowerCase();
    for (var i = 0; i < groups.length; i++)
        for (var j = 0; j < groups[i].items.length; j++) {
            var m = groups[i].items[j].match;
            for (var k = 0; k < m.length; k++)
                if (a === m[k] || (m[k].indexOf("steam_app_") !== 0 && (a.indexOf(m[k]) >= 0 || t.indexOf(m[k]) >= 0)))
                    return groups[i].items[j].name;
        }
    return "";
}
