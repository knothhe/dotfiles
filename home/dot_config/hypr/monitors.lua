-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = 1.375

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })

-- BEGIN OMARCHY QEMU PROFILE
-- QEMU publishes the live window's size and host refresh rate through Virtio
-- GPU EDID. Preserve its recorded mode and override the helper's scale;
-- keep normal guest cursor visibility. The matching host runtime can display
-- guest-defined sprites independently from desktop frames.
local function omarchy_kernel_option_enabled(expected_option)
  if type(io) ~= "table" or type(io.open) ~= "function" then
    return false
  end

  local opened, cmdline_file = pcall(io.open, "/proc/cmdline", "r")
  if not opened or not cmdline_file then
    return false
  end

  local read_ok, cmdline = pcall(cmdline_file.read, cmdline_file, "*a")
  pcall(cmdline_file.close, cmdline_file)
  if not read_ok or type(cmdline) ~= "string" then
    return false
  end

  for option in cmdline:gmatch("%S+") do
    if option == expected_option then
      return true
    end
  end
  return false
end

-- Hyprland re-reads this file on every reload, and each theme switch runs
-- one. Keep the mode display sync last applied from the window's EDID;
-- falling back to "preferred" changes the mode, which blanks the window and
-- can restore an older window size.
local function omarchy_synced_display_mode()
  if type(os) ~= "table" or type(os.getenv) ~= "function" or type(io) ~= "table" or type(io.open) ~= "function" then
    return nil
  end
  local runtime_dir = os.getenv("XDG_RUNTIME_DIR")
  if type(runtime_dir) ~= "string" or runtime_dir == "" then
    return nil
  end

  local opened, mode_file = pcall(io.open, runtime_dir .. "/try-omarchy/display-mode", "r")
  if not opened or not mode_file then
    return nil
  end
  local mode_ok, mode = pcall(mode_file.read, mode_file, "*l")
  local scale_ok, scale = pcall(mode_file.read, mode_file, "*l")
  pcall(mode_file.close, mode_file)
  if not mode_ok or not scale_ok or type(mode) ~= "string" or type(scale) ~= "string" then
    return nil
  end
  if not mode:match("^modeline [%d ]+ [+-]hsync [+-]vsync$") or not scale:match("^%d+%.?%d*$") then
    return nil
  end
  return mode, scale
end

if omarchy_kernel_option_enabled("omarchy.qemu=1") then
  -- Dynamic VM resolutions may not divide evenly at the requested scale.
  hl.config({ debug = { disable_scale_checks = true } })
  -- Virgl cursor GPU buffers arrive inverted; use a small CPU cursor buffer.
  hl.config({ cursor = { invisible = false, use_cpu_buffer = 1 } })
  local synced_mode, synced_scale = omarchy_synced_display_mode()
  local user_scale = tonumber(omarchy_monitor_scale)
  if synced_mode then
    -- A number the user set in this file is explicit intent and outranks
    -- the scale guessed from the EDID; "auto" keeps the guessed scale.
    if user_scale and user_scale > 0 then
      synced_scale = tostring(user_scale)
    end
    hl.monitor({ output = "", mode = synced_mode, scale = synced_scale })
    -- A specific output rule takes precedence over the VM helper's catch-all.
    -- Keep the recorded VM resolution while preserving the requested scale.
    -- After resizing the host window, reload to adopt the newly recorded mode.
    hl.monitor({ output = "Virtual-1", mode = synced_mode, scale = synced_scale })
  elseif user_scale and user_scale > 0 then
    -- Runtime state disappears on reboot. Protect the explicit scale before
    -- display sync starts and replaces the catch-all rule with a rounded scale.
    hl.monitor({ output = "Virtual-1", mode = "preferred", position = "auto", scale = user_scale })
  end
  o.exec_on_start("/usr/local/bin/omarchy-native-display-sync")
end

-- On CPU rendering (llvmpipe) every animation frame is CPU time the desktop
-- feels. Start with animations off; looknfeel.lua loads after this file, so
-- an explicit choice there still wins.
if omarchy_kernel_option_enabled("tryomarchy.render=cpu") then
  hl.config({ animations = { enabled = false } })
end
-- END OMARCHY QEMU PROFILE
