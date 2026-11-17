-- Auto-start config
-- if you dont use UWSM add your auto start programs here, otherwise use XDG autostart https://wiki.archlinux.org/title/XDG_Autostart

hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("noctalia")
    -- The rice's always-on top bar and app launcher (~/.config/quickshell/rice)
    hl.exec_cmd("qs -c rice -d")
    -- Open Freeze Center (fan control) at login; no password, see /etc/polkit-1/rules.d/49-openfreezecenter.rules
    hl.exec_cmd("pkexec /usr/local/libexec/ofc-root")
    hl.exec_cmd("xhost +SI:localuser:root")
end)
