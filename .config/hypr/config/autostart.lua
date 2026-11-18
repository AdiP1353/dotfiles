-- Auto-start config
-- if you dont use UWSM add your auto start programs here, otherwise use XDG autostart https://wiki.archlinux.org/title/XDG_Autostart

hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("noctalia")
    -- The rice's always-on top bar and app launcher (~/.config/quickshell/rice)
    hl.exec_cmd("qs -c rice -d")
    hl.exec_cmd("hypridle")                                   -- idle: dim, lock, sleep (hypr/hypridle.conf)
    hl.exec_cmd("udiskie")                                    -- USB drives: mount + notify (udiskie/config.yml)
    hl.exec_cmd(os.getenv("HOME") .. "/.config/rice/bin/rice-notify-focus")  -- click a notification: go to its app
    -- Open Freeze Center (fan control) at login; no password, see /etc/polkit-1/rules.d/49-openfreezecenter.rules
    -- Only on machines that have it (this laptop): elsewhere pkexec would just
    -- fail, and root apps don't need access to the screen.
    local ofc = io.open("/usr/local/libexec/ofc-root", "r")
    if ofc then
        ofc:close()
        hl.exec_cmd("pkexec /usr/local/libexec/ofc-root")
        hl.exec_cmd("xhost +SI:localuser:root")
    end
end)
