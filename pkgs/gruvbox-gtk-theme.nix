{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  sassc,
  gnome-themes-extra,
  colorVariants ? [ ],
  sizeVariants ? [ ],
  themeVariants ? [ ],
  tweakVariants ? [ ],
  iconVariants ? [ ],
}:

let
  pname = "gruvbox-gtk-theme";
  colorVariantList = [
    "dark"
    "light"
  ];
  sizeVariantList = [
    "compact"
    "standard"
  ];
  themeVariantList = [
    "default"
    "green"
    "grey"
    "orange"
    "pink"
    "purple"
    "red"
    "teal"
    "yellow"
    "all"
  ];
  tweakVariantList = [
    "medium"
    "soft"
    "black"
    "float"
    "outline"
    "macos"
  ];
  iconVariantList = [
    "Dark"
    "Light"
  ];
in
lib.checkListOfEnum "${pname}: colorVariants" colorVariantList colorVariants lib.checkListOfEnum
  "${pname}: sizeVariants"
  sizeVariantList
  sizeVariants
  lib.checkListOfEnum
  "${pname}: themeVariants"
  themeVariantList
  themeVariants
  lib.checkListOfEnum
  "${pname}: tweakVariants"
  tweakVariantList
  tweakVariants
  lib.checkListOfEnum
  "${pname}: iconVariants"
  iconVariantList
  iconVariants
  stdenvNoCC.mkDerivation
  {
    inherit pname;
    version = "0-unstable-2025-10-23";

    # nixpkgs removed this package because the upstream theme propagated the
    # obsolete GTK2 Murrine engine. Keep the GTK3/GTK4 assets locally until
    # the upstream theme can be migrated to a GTK2-free release.
    src = fetchFromGitHub {
      owner = "Fausto-Korpsvart";
      repo = "Gruvbox-GTK-Theme";
      rev = "578cd220b5ff6e86b078a6111d26bb20ec8c733f";
      hash = "sha256-RXoPj/aj9OCTIi8xWatG0QpDAUh102nFOipdSIiqt7o=";
    };

    nativeBuildInputs = [ sassc ];
    buildInputs = [ gnome-themes-extra ];

    dontBuild = true;

    postPatch = ''
      patchShebangs themes/install.sh
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/themes
      cd themes
      ./install.sh -n Gruvbox \
        ${lib.optionalString (colorVariants != [ ]) "-c " + toString colorVariants} \
        ${lib.optionalString (sizeVariants != [ ]) "-s " + toString sizeVariants} \
        ${lib.optionalString (themeVariants != [ ]) "-t " + toString themeVariants} \
        ${lib.optionalString (tweakVariants != [ ]) "--tweaks " + toString tweakVariants} \
        -d "$out/share/themes"
      cd ../icons
      ${lib.optionalString (iconVariants != [ ]) ''
        mkdir -p $out/share/icons
        cp -a ${toString (map (v: "Gruvbox-${v}") iconVariants)} $out/share/icons/
      ''}
      runHook postInstall
    '';

    postInstall = ''
      # The generated GTK2 files refer to Murrine. GTK3 and GTK4 do not.
      find "$out/share/themes" -type d -name gtk-2.0 -prune -exec rm -rf {} +
    '';

    meta = {
      description = "GTK theme based on the Gruvbox colour palette";
      homepage = "https://github.com/Fausto-Korpsvart/Gruvbox-GTK-Theme";
      license = lib.licenses.gpl3Plus;
      platforms = lib.platforms.unix;
    };
  }
