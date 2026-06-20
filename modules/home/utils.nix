{
  wrapWithEnv =
    {
      lib,
      pkgs,
      pkg,
      bin,
      envVars,
    }:
    (pkgs.symlinkJoin {
      name = pkg.name;
      version = pkg.version;
      paths = [ pkg ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/${bin} ${
          lib.concatMapStringsSep " " (var: "--set ${var.name} '${var.value}'") envVars
        }
      '';
    });
}
