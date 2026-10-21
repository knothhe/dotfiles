-- Override only the keyboard option; retain Omarchy's other input defaults.
hl.config({ input = { kb_options = "ctrl:swapcaps" } })

-- BEGIN TRY OMARCHY PINCH DEVICE
-- Try Omarchy's virtual pinch touchpad only carries Windows pinch gestures.
-- Its device-only rules keep those contacts from turning into tap clicks.
-- Other Omarchy installs do not have the file, so nothing loads there.
do
  local rules = "/usr/share/try-omarchy/pinch-input.lua"
  local file = io.open(rules, "r")
  if file then
    file:close()
    dofile(rules)
  end
end
-- END TRY OMARCHY PINCH DEVICE
