// Firefox prefs for the rice (THEME.md §3). Linked into the profile as
// user.js; Firefox applies these on every start.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true); // load userChrome.css
user_pref("extensions.activeThemeID", "default-theme@mozilla.org");    // system theme: GTK's dark colours under userChrome
user_pref("browser.theme.toolbar-theme", 0);                           // dark
user_pref("browser.theme.content-theme", 0);                           // websites see a dark system
user_pref("layout.css.prefers-color-scheme.content-override", 0);      // dark
user_pref("widget.gtk.rounded-bottom-corners.enabled", false);         // square window
user_pref("widget.use-xdg-desktop-portal.file-picker", 1);              // the GTK picker, like every other app
