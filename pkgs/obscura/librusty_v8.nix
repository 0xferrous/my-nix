# Pinned to the v8 crate version in obscura's Cargo.lock (v8 137.3.0). When
# updating obscura, check `grep -A2 'name = "v8"' Cargo.lock` and bump both
# this version and the corresponding release shas.
{ fetchLibrustyV8 }:

fetchLibrustyV8 {
  version = "137.3.0";
  shas = {
    x86_64-linux = "sha256-omgf3lMBir0zZgGPEyYX3VmAAt948VbHvG0v9gi1ZWc=";
    aarch64-linux = "sha256-42jQy0HBecQ6mQ5OxKVeRN2XYvHTS+FWlqzEQz+KbJI=";
    x86_64-darwin = "sha256-ZnFsCn2VDqLHKqr2oMGkAqO6xV/fwLQ0H0mzjpr+zXU=";
    aarch64-darwin = "sha256-YFA9ZyTlUsRrAewmChXnnobEcVtxl8XGJ0iRG/H04HA=";
  };
}
