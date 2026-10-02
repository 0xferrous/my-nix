{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fr.public;
in
{
  config = lib.mkIf cfg.enable {
    services.llama-cpp = {
      enable = lib.mkDefault true;
      # Bonsai's PTQ1_0/PQ2_0 formats require the PrismML runtime fork.
      package = lib.mkDefault pkgs.llama-cpp-prism-vulkan;
      models.qwen3-coder-30b = lib.mkDefault {
        repo = "unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF";
        file = "Qwen3-Coder-30B-A3B-Instruct-Q5_K_M.gguf";
        description = "Qwen3 Coder 30B-A3B (Q5_K_M)";
      };
      models.bonsai-8b = lib.mkDefault {
        repo = "prism-ml/Ternary-Bonsai-8B-gguf";
        file = "Ternary-Bonsai-8B-Q2_0_g64.gguf";
        description = "Ternary Bonsai 8B (Q2_0_g64, 1.58-bit)";
      };
      models.bonsai-8b-1bit = lib.mkDefault {
        repo = "prism-ml/Bonsai-8B-gguf";
        file = "Bonsai-8B-Q1_0.gguf";
        description = "Bonsai 8B (Q1_0, 1-bit)";
      };
      models.ternary-bonsai-2-27b = lib.mkDefault {
        repo = "prism-ml/Ternary-Bonsai-2-27B-gguf";
        file = "Ternary-Bonsai-2-27B-PQ2_0.gguf";
        mmproj = "Ternary-Bonsai-2-27B-mmproj-Q8_0.gguf";
        description = "Ternary Bonsai 2 27B (PQ2_0, vision enabled)";
      };
      # Sampling defaults follow the Ternary Bonsai 2 27B model card's
      # "thinking mode" recommendations: temperature 1.0, top-p 0.95,
      # top-k 20, min-p 0.05, presence penalty 0.0, repetition penalty 1.0.
      settings = lib.mkDefault {
        host = "127.0.0.1";
        port = 8080;
        "ctx-size" = 131072;
        "n-gpu-layers" = 99;
        parallel = 1;
        perf = true;
        "ui-config-file" = pkgs.writeText "llama-cpp-ui-config.json" (
          builtins.toJSON {
            showMessageStats = true;
            showAgenticTurnStats = true;
          }
        );
        temp = 1.0;
        "top-p" = 0.95;
        "top-k" = 20;
        "min-p" = 0.05;
        "presence-penalty" = 0.0;
        "repeat-penalty" = 1.0;
      };
    };
  };
}
