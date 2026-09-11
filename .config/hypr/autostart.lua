-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- Reload hyprpm-loaded plugins (hyprbars) on login.
o.exec_on_start("hyprpm reload")
o.exec_on_start("bash ~/.config/hypr/hyprbars-group-title.sh")
