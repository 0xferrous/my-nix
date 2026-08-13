# Pin for the ChatGPT/Codex Linux desktop app (preview).
#
# OpenAI only publishes a moving `latest/` URL for the Linux packages, so the
# version is read from the deb's control metadata and the URL is re-fetched
# when bumping (see ./update.sh). The mac app uses a versioned `sidekick`
# URL in nixpkgs (`pkgs/by-name/ch/chatgpt`), but no equivalent exists for
# the Linux `codex-app-prod` bucket yet.
{
  version = "26.810.41047";
  src = {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb";
    hash = "sha256-eHFfo80Tb/ZwcNqnaBmtrsxbQumYUVWWWWRdzh+/KvM=";
  };
}
