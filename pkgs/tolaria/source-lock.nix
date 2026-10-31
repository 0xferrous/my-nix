# Pin for the Tolaria Linux desktop app.
#
# Tolaria (https://github.com/refactoringhq/tolaria) ships Linux builds as
# GitHub release assets (amd64 deb/rpm/AppImage). Releases are calendar-tagged
# (`vYYYY-MM-DD`) and the deb asset name embeds the same version as `YYYY.M.D`
# (leading zeros stripped), so the pin only goes stale when a new release
# ships (bump with ./update.sh). There is no apt repo to index and no
# upstream Nix build support, so the release deb is the authoritative binary
# distribution channel.
{
  version = "2026.10.30";
  src = {
    url = "https://github.com/refactoringhq/tolaria/releases/download/v2026-10-30/Tolaria_2026.10.30_amd64.deb";
    hash = "sha256-WgYV3SJhNQXQjMRjbohjM1kReAi9Uk1B15BY51Grgtc=";
  };
}
