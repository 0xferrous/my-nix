return {
  {
    "dmtrKovalenko/fff.nvim",
    -- Official docs say not to lazy-load via the plugin manager.
    -- fff.nvim initializes itself lazily.
    config = function()
      require("fff").setup({
        prompt = "  ",
        layout = {
          width = 0.9,
          height = 0.85,
          prompt_position = "top",
          preview_position = "right",
          preview_size = 0.55,
          show_scrollbar = false,
        },
      })

      local ok, picker_ui = pcall(require, "fff.picker_ui")
      if ok and picker_ui and picker_ui.state then
        picker_ui.state.preview_debounce_ms = 0

        picker_ui.update_preview_smart = function()
          if not picker_ui.enabled_preview() then
            return
          end
          if not picker_ui.state.active then
            return
          end
          picker_ui.update_preview()
        end

        local original_move_down = picker_ui.move_down
        local original_move_up = picker_ui.move_up

        local function wrap_cursor_to(target)
          picker_ui.state.cursor = target
          picker_ui.render_list()
          if picker_ui.state.mode == "grep" or picker_ui.state.suggestion_source == "grep" then
            picker_ui.update_preview_smart()
          else
            picker_ui.update_preview()
          end
          picker_ui.update_status()
        end

        picker_ui.move_down = function()
          if not picker_ui.state.active or #picker_ui.state.filtered_items == 0 then
            return original_move_down()
          end

          local prompt_position = picker_ui.state.config
            and picker_ui.state.config.layout
            and picker_ui.state.config.layout.prompt_position
            or "bottom"
          local items_count = #picker_ui.state.filtered_items
          local at_last = prompt_position == "top" and picker_ui.state.cursor >= items_count
          local at_first = prompt_position == "bottom" and picker_ui.state.cursor <= 1

          if at_last or at_first then
            return wrap_cursor_to(prompt_position == "top" and 1 or items_count)
          end

          return original_move_down()
        end

        picker_ui.move_up = function()
          if not picker_ui.state.active or #picker_ui.state.filtered_items == 0 then
            return original_move_up()
          end

          local prompt_position = picker_ui.state.config
            and picker_ui.state.config.layout
            and picker_ui.state.config.layout.prompt_position
            or "bottom"
          local items_count = #picker_ui.state.filtered_items
          local at_first = prompt_position == "top" and picker_ui.state.cursor <= 1
          local at_last = prompt_position == "bottom" and picker_ui.state.cursor >= items_count

          if at_first or at_last then
            return wrap_cursor_to(prompt_position == "top" and items_count or 1)
          end

          return original_move_up()
        end
      end
    end,
  },
}
