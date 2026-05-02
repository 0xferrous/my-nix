{ ... }:
{
  programs.alacritty = {
    enable = true;
    settings = {
      # Shell (matching ghostty: command = /run/current-system/sw/bin/nu)
      shell = {
        program = "/run/current-system/sw/bin/nu";
      };

      # Font (matching ghostty: RecMonoCasual Nerd Font Mono, size 11)
      font = {
        normal = {
          family = "RecMonoCasual Nerd Font Mono";
        };
        bold = {
          family = "RecMonoCasual Nerd Font Mono";
        };
        italic = {
          family = "RecMonoCasual Nerd Font Mono";
        };
        bold_italic = {
          family = "RecMonoCasual Nerd Font Mono";
        };
        size = 11;
      };

      # Cursor (matching ghostty: block, no blink, color #EBDBB2)
      cursor = {
        style = {
          shape = "Block";
          blinking = "Off";
        };
        vi_mode_style = {
          shape = "Block";
          blinking = "Off";
        };
      };

      # Colors - Gruvbox Dark Hard theme
      colors = {
        primary = {
          background = "#1d2021";
          foreground = "#ebdbb2";
        };
        cursor = {
          text = "CellBackground";
          cursor = "#ebdbb2";
        };
        normal = {
          black = "#1d2021";
          red = "#cc241d";
          green = "#98971a";
          yellow = "#d79921";
          blue = "#458588";
          magenta = "#b16286";
          cyan = "#689d6a";
          white = "#a89984";
        };
        bright = {
          black = "#928374";
          red = "#fb4934";
          green = "#b8bb26";
          yellow = "#fabd2f";
          blue = "#83a598";
          magenta = "#d3869b";
          cyan = "#8ec07c";
          white = "#ebdbb2";
        };
      };

      # Scrollback (matching ghostty's 500MB ~ 1M lines)
      scrolling = {
        history = 1000000;
      };

      # Window settings
      window = {
        padding = {
          x = 5;
          y = 5;
        };
        opacity = 0.95;
        decorations = "Full";
        resize_increments = true;
      };

      # Selection settings (matching ghostty: copy_on_select = false)
      selection = {
        save_to_clipboard = false;
      };

      # URL hints (matching ghostty: link-url = true)
      hints = {
        enabled = [
          {
            command = "xdg-open"; # Linux
            hyperlinks = true;
            post_processing = true;
            persist = false;
            mouse = {
              enabled = true;
              mods = "Control";
            };
            regex = "(ipfs:|ipns:|magnet:|mailto:|gemini://|gopher://|https://|http://|news:|file:|git://|ssh:|ftp://)[^\\u0000-\\u001F\\u007F-\\u009F<>\"\\s{-}\\^⟨⟩`]+";
          }
        ];
      };

      # Keyboard bindings (translated from ghostty keybinds)
      keyboard.bindings = [
        # Config management
        {
          key = "Comma";
          mods = "Control";
          action = "SpawnNewInstance"; # Approximation of open_config
        }
        {
          key = "F5";
          mods = "Control|Shift";
          action = "ResetFontSize"; # No direct reload_config equivalent
        }

        # Fullscreen
        {
          key = "Return";
          mods = "Control";
          action = "ToggleFullscreen";
        }

        # Clear screen
        {
          key = "K";
          mods = "Super";
          action = "ClearHistory";
        }

        # Tabs navigation
        {
          key = "Tab";
          mods = "Control";
          action = "SelectNextTab";
        }
        {
          key = "Tab";
          mods = "Control|Shift";
          action = "SelectPreviousTab";
        }

        # Tab management
        {
          key = "Comma";
          mods = "Control|Shift";
          action = "MovePreviousTab";
        }
        {
          key = "Period";
          mods = "Control|Shift";
          action = "MoveNextTab";
        }
        {
          key = "W";
          mods = "Control|Shift";
          action = "CloseTab";
        }

        # Copy/Paste (matching ghostty: ctrl+insert/shift+insert)
        {
          key = "Insert";
          mods = "Control";
          action = "Copy";
        }
        {
          key = "Insert";
          mods = "Shift";
          action = "Paste";
        }

        # Scrolling (matching ghostty: shift+PageUp/Down, Home/End)
        {
          key = "PageUp";
          mods = "Shift";
          action = "ScrollPageUp";
        }
        {
          key = "PageDown";
          mods = "Shift";
          action = "ScrollPageDown";
        }
        {
          key = "Home";
          mods = "Shift";
          action = "ScrollToTop";
        }
        {
          key = "End";
          mods = "Shift";
          action = "ScrollToBottom";
        }

        # Enter literal newline on Shift+Enter
        {
          key = "Return";
          mods = "Shift";
          chars = "\\n";
        }

        # Word navigation (bonus - useful for shell)
        {
          key = "Left";
          mods = "Control";
          chars = "\\u001Bb";
        }
        {
          key = "Right";
          mods = "Control";
          chars = "\\u001Bf";
        }
      ];
    };
  };
}
