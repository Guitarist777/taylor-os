// The TAYLOR look for her KDE backup session (her build brief, "Alternate look: TAYLOR on KDE"): a classic Plasma
// desktop like the Slot reference. One full-width panel along the bottom: the app menu at the left, pinned and
// running apps, then the tray and the clock at the right. The sky picture on every desktop.
var desktopsArray = desktopsForActivity(currentActivity());
for (var j = 0; j < desktopsArray.length; j++) {
    desktopsArray[j].wallpaperPlugin = "org.kde.image";
    desktopsArray[j].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktopsArray[j].writeConfig("Image", "file:///usr/share/wallpapers/TAYLOR-Sky/");
}

var panel = new Panel;
panel.location = "bottom";
panel.height = 2 * Math.floor(gridUnit * 2.5 / 2);
try { panel.floating = false; } catch (e) {}      // full width, sitting on the bottom edge (the hills rise behind it)

var menu = panel.addWidget("org.kde.plasma.kickoff");
menu.currentConfigGroup = ["Shortcuts"];
menu.writeConfig("global", "Alt+F1");

var tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", ["preferred://filemanager", "preferred://browser",
                                "applications:org.kde.konsole.desktop", "applications:systemsettings.desktop"]);

panel.addWidget("org.kde.plasma.marginsseparator");
panel.addWidget("org.kde.plasma.systemtray");
panel.addWidget("org.kde.plasma.digitalclock");
panel.addWidget("org.kde.plasma.showdesktop");
