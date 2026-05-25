{ config, lib, pkgs, ... }:
let
  cfg = config.fr.speechToText;

  sttToggle = pkgs.writeShellApplication {
    name = "fr-stt-toggle";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      gnused
      libnotify
      pipewire
      procps
      wtype
      whisper-cpp
    ];
    text = ''
      set -euo pipefail

      state_dir="''${XDG_RUNTIME_DIR:-/tmp}/fr-stt"
      data_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/fr-stt"
      pid_file="$state_dir/record.pid"
      wav_file="$state_dir/input.wav"
      out_prefix="$state_dir/output"
      model="${cfg.modelPath}"

      mkdir -p "$state_dir" "$data_dir"

      if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        record_pid="$(cat "$pid_file")"
        kill -INT "$record_pid" 2>/dev/null || true
        for _ in $(seq 1 50); do
          kill -0 "$record_pid" 2>/dev/null || break
          sleep 0.1
        done
        rm -f "$pid_file"

        if [ ! -s "$wav_file" ]; then
          notify-send "Speech to text" "No audio recorded"
          exit 1
        fi

        if [ ! -f "$model" ]; then
          notify-send "Speech to text" "Missing Whisper model: $model"
          exit 1
        fi

        rm -f "$out_prefix.txt"
        notify-send "Speech to text" "Transcribing…"
        whisper-cli -m "$model" -f "$wav_file" -otxt -of "$out_prefix" ${lib.escapeShellArgs cfg.whisperArgs} >/dev/null
        text="$(tr '\n' ' ' < "$out_prefix.txt" | sed 's/^ *//; s/ *$//')"

        if [ -n "$text" ]; then
          wtype "$text"
          notify-send "Speech to text" "Inserted transcription"
        else
          notify-send "Speech to text" "No speech detected"
        fi

      else
        rm -f "$wav_file" "$out_prefix.txt" "$pid_file"
        notify-send "Speech to text" "Recording… run again to stop"
        pw-record --format s16 --rate 16000 --channels 1 "$wav_file" &
        echo "$!" > "$pid_file"
      fi
    '';
  };
in
{
  options.fr.speechToText = {
    enable = lib.mkEnableOption "local Whisper speech-to-text dictation";

    modelPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.local/share/whisper/models/ggml-base.en.bin";
      description = "Path to the whisper.cpp ggml model used for transcription.";
    };

    whisperArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "--no-timestamps" ];
      description = "Extra arguments passed to whisper-cli.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ sttToggle ];

    xdg.desktopEntries.fr-stt-toggle = {
      name = "Speech to Text Toggle";
      comment = "Start/stop microphone dictation and type the transcription";
      exec = "${lib.getExe sttToggle}";
      terminal = false;
      categories = [ "Utility" ];
    };
  };
}
