# Pin for the ChatGPT/Codex Linux desktop app (preview).
#
# OpenAI hosts a real apt repository (codex-app-prod/linux/deb) whose
# dists/stable/main/binary-amd64/Packages index lists the current version
# and hash. The versioned pool URL below is stable per version, unlike the
# moving `latest/` URL used on the download page, so the pin only goes stale
# when OpenAI ships a new build (bump with ./codex-desktop-update.sh). The
# mac app uses a versioned `sidekick` URL in nixpkgs
# (`pkgs/by-name/ch/chatgpt`); the apt pool is the Linux equivalent.
{
  version = "26.810.41047";
  src = {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_26.810.41047_amd64.deb";
    hash = "sha256-eHFfo80Tb/ZwcNqnaBmtrsxbQumYUVWWWWRdzh+/KvM=";
  };
}
