{ final, prev, gitOverride, ... }:

gitOverride {
  nyxKey = "lan-mouse_git";
  prev = prev.lan-mouse;

  versionNyxPath = "pkgs/lan-mouse-git/version.json";
  fetcher = "fetchFromGitHub";
  fetcherData = {
    owner = "feschber";
    repo = "lan-mouse";
  };

  withCargoDeps = lockFile: final.rustPlatform.importCargoLock {
    inherit lockFile;
  };
}
