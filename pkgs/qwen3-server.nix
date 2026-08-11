{
  pkgs,
  lib ? pkgs.lib,
  llamaCpp ? pkgs.llama-cpp.override { vulkanSupport = true; },
  defaultQuant ? "Q5_K_M",
}:

let
  modelName = "Qwen3-Coder-30B-A3B-Instruct";
  modelFile = "${modelName}-${defaultQuant}.gguf";
  modelUrl = "https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/resolve/main/${modelFile}";

  cacheDir = "\${QWEN3_CACHE_DIR:-\$HOME/.cache/qwen3}";
  modelPath = "\${QWEN3_MODEL:-\$cache_dir/${modelFile}}";

  server = pkgs.writeShellApplication {
    name = "qwen3-server";
    runtimeInputs = [ llamaCpp ];
    text = ''
      set -eu

      cache_dir=${cacheDir}
      model=${modelPath}

      if [ ! -f "$model" ]; then
        echo "model not found: $model" >&2
        echo "run: qwen3-get-model" >&2
        exit 1
      fi

      exec llama-server \
        --model "$model" \
        --host "''${QWEN3_HOST:-127.0.0.1}" \
        --port "''${QWEN3_PORT:-8080}" \
        --ctx-size "''${QWEN3_CTX_SIZE:-32768}" \
        --n-gpu-layers "''${QWEN3_GPU_LAYERS:-99}" \
        --parallel "''${QWEN3_PARALLEL:-1}" \
        "$@"
    '';
  };

  get-model = pkgs.writeShellApplication {
    name = "qwen3-get-model";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      set -eu

      cache_dir=${cacheDir}
      model=${modelPath}

      if [ -f "$model" ]; then
        echo "model already present: $model"
        exit 0
      fi

      mkdir -p "$cache_dir"
      tmp="$model.part"
      echo "downloading ${modelUrl}"
      curl -L -C - --fail --progress-bar -o "$tmp" "${modelUrl}"
      mv "$tmp" "$model"
      echo "done: $model"
    '';
  };

  bench = pkgs.writeShellApplication {
    name = "qwen3-bench";
    runtimeInputs = [ llamaCpp ];
    text = ''
      set -eu

      cache_dir=${cacheDir}
      model=${modelPath}

      if [ ! -f "$model" ]; then
        echo "model not found: $model" >&2
        echo "run: qwen3-get-model" >&2
        exit 1
      fi

      for layers in 0 33 66 99; do
        echo "=== n-gpu-layers=$layers ==="
        llama-bench -m "$model" -ngl "$layers" -p 1024 -n 64 -r 1
      done
    '';
  };
in
pkgs.symlinkJoin {
  name = "qwen3-server";
  paths = [
    server
    get-model
    bench
  ];

  meta = with lib; {
    description = "Qwen3-Coder 30B-A3B served directly by llama.cpp (Vulkan backend)";
    mainProgram = "qwen3-server";
    platforms = platforms.linux;
  };
}
