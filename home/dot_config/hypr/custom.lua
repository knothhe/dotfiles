-- Personal window rules layered on top of Omarchy's default rules.
-- The floating-window tag is retained; geometry follows Omarchy defaults.
o.window("(org.omarchy.pass_fzf)", {
  tag = "+floating-window",
  no_screen_share = true,
})

o.window({ class = "(wechat)", title = [[negative:^(wechat)\W*]] }, {
  tag = "+floating-window",
})

o.window({ class = "(wechat)", title = [[negative:^(朋友圈|设置|聊天文件|预览|图片和视频)\W*]] }, {
  no_blur = true,
  border_size = 0,
  no_shadow = true,
})

o.window({ class = "^(flameshot)$", title = "^(flameshot-pin)$" }, {
  tag = "+floating-window",
  no_blur = true,
  border_size = 0,
  no_shadow = true,
})

o.window("^(confirmo)$", {
  tag = "+floating-window",
  border_size = 0,
  pin = true,
})
