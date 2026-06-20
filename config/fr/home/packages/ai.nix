{
  pkgs,
  myNixInputs,
  system,
  AIPackages,
  ...
}:
with pkgs;
[
  aichat
  mods
  alpaca

  # LLM CLI
  (python314Packages.llm.withPlugins {
    llm-docs = true;
    llm-ollama = true;
  })

  # AI agent packages (from flake, but cross-platform CLI tools)
  AIPackages.claude-code
  AIPackages.ccusage
  AIPackages.handy
  AIPackages.openspec
  AIPackages.spec-kit
  AIPackages.opencode
  myNixInputs.codexbar.packages.${system}.default
  AIPackages.codex
  AIPackages.amp
  AIPackages.pi
  AIPackages.tuicr
]
