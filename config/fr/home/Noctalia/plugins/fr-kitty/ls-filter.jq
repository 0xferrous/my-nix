.[] as $os
| ((([$os.tabs[] | select(.is_active == true) | .windows[] | select(.is_active == true) | .title] | .[0]) // $os.wm_name // $os.wm_class // "") | gsub("[[:cntrl:]]";" ")) as $ost
| $os.tabs[] as $tab
| (($tab.title // "") | gsub("[[:cntrl:]]";" ")) as $tt
| $tab.windows[] as $w
| (($w.title // "") | gsub("[[:cntrl:]]";" ")) as $wt
| (($w.cwd // "") | gsub("[[:cntrl:]]";" ")) as $cwd
| ((($w.cmdline // [])[0] // "") | split("/") | .[-1] // "" | gsub("[[:cntrl:]]";" ")) as $cmd
| ((($w.cmdline // []) | join(" ")) | gsub("[[:cntrl:]]";" ")) as $cmdl
| ([$w.foreground_processes[]? | ((.cmdline // [])[0] // "") | split("/") | .[-1] // ""] | join(" ") | gsub("[[:cntrl:]]";" ")) as $fgc
| ([$w.foreground_processes[]? | ((.cmdline // []) | join(" "))] | join(" ") | gsub("[[:cntrl:]]";" ")) as $fgcl
| ([$w.foreground_processes[]? | (.cwd // "") | select(. != "")] | join(" ") | gsub("[[:cntrl:]]";" ")) as $fgcw
| [$os.id, $ost, ($os.is_focused // false), $tab.id, $tt, ($tab.is_focused // false), ($tab.is_active // false), $w.id, $wt, $cwd, $cmd, $cmdl, $fgc, $fgcl, $fgcw, ($w.is_focused // false), ($w.is_active // false), ($w.needs_attention // false), ($w.at_prompt // false)]
| map(tostring) | join("\u001f")
