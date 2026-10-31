# Pinned to the v8 crate version in obscura's Cargo.lock (v8 150.4.0). When
# updating obscura, check `grep -A2 'name = "v8"' Cargo.lock` and bump both
# this version and the corresponding release shas. Obscura enables the v8
# crate's `simdutf` feature, so the prebuilt archive must be the matching
# `_simdutf` variant.
{ fetchLibrustyV8 }:

fetchLibrustyV8 {
  version = "150.4.0";
  features = "simdutf";
  shas = {
    x86_64-linux = "sha256-9IdiyhDR8fxgWkQcWuQw7Izh6egPFNePvELLh4wwtHY=";
    aarch64-linux = "sha256-U54oOBWjlqV5bzKFi0LlF7hY66rqqtBdAykO6MhkpSc=";
    x86_64-darwin = "sha256-p1AnH+xrIRRX7Qpc99LqsZJLJlYhqC2oarlZ1v8II+Q=";
    aarch64-darwin = "sha256-Wu/9jVoMG3msHXCvg9WxkJllX9nGRaeU3EPxAfd5g4w=";
  };
}
