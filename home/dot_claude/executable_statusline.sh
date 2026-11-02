#!/bin/sh
# Claude Code status line: model | dir | ctx | 5h quota left | weekly quota left
input=$(cat)

printf '%s' "$input" | jq -r '
  # Color by remaining quota: red <= 20%, yellow <= 50%, green otherwise.
  def color(p): if p <= 20 then "\u001b[31m" elif p <= 50 then "\u001b[33m" else "\u001b[32m" end;
  def reset: "\u001b[0m";
  def left(t):
    ((t - now) | floor) as $s
    | if $s <= 0 then "now"
      elif $s >= 86400 then "\($s / 86400 | floor)d\(($s % 86400) / 3600 | floor)h"
      elif $s >= 3600 then "\($s / 3600 | floor)h\(($s % 3600) / 60 | floor)m"
      else "\($s / 60 | floor)m" end;
  def win($name; w):
    if w == null then empty
    else ([100 - w.used_percentage, 0] | max | round) as $p
      | "\($name) \(color($p))\($p)% left\(reset) (\(left(w.resets_at)))"
    end;

  [
    (.model.display_name // empty),
    ((.workspace.current_dir // .cwd // "") | split("/") | last // empty),
    (if .context_window.used_percentage != null
       then "ctx \(.context_window.used_percentage | round)%" else empty end),
    win("5h"; .rate_limits.five_hour),
    win("W"; .rate_limits.seven_day)
  ] | map(select(. != null and . != "")) | join(" │ ")
'
