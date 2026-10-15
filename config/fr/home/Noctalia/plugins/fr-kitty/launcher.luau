--!nonstrict
-- Bar widget that opens the Kitty panes panel.

local PANEL_ID = "fr/kitty:panes"

local function render()
  local glyph = noctalia.getConfig("glyph") or "cat"
  local showText = noctalia.getConfig("show_text") == true
  local vertical = barWidget.isVertical()
  local container = vertical and ui.column or ui.row

  local children = {
    ui.glyph({ name = glyph, size = 14, color = "primary" }),
  }
  if showText then
    table.insert(children, ui.label({ text = "kitty", color = "primary" }))
  end

  barWidget.render(container({ gap = 6, align = "center" }, children))
  barWidget.setTooltip("Kitty panes")
end

function update()
  render()
end

function onClick()
  noctalia.togglePanel(PANEL_ID)
end

render()
