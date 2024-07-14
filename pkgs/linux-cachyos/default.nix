{ final, ... }@inputs:

let
  inherit (final.lib.trivial) importJSON;

  # CachyOS repeating stuff.
  mainVersions = importJSON ./versions.json;

  mkCachyKernel = attrs: final.callPackage ./packages-for.nix
    ({ inherit zfs-source; versions = mainVersions; } // attrs);

  stdenvLLVM = final.callPackage ./lib/llvm-stdenv.nix { };

  zfs-source = final.fetchFromGitHub {
    owner = "cachyos";
    repo = "zfs";
    inherit (mainVersions.zfs) rev hash;
  };

  llvmModuleOverlay = import ./lib/llvm-module-overlay.nix inputs stdenvLLVM;
in
(import ./custom.nix { inherit mkCachyKernel stdenvLLVM; }) //
{
  inherit mainVersions mkCachyKernel;

  cachyos = mkCachyKernel {
    taste = "linux-cachyos";
    configPath = ./config-nix/cachyos.x86_64-linux.nix;
    # since all flavors use the same versions.json, we just need the updateScript in one of them
    withUpdateScript = true;
  };

  cachyos-rc = mkCachyKernel {
    taste = "linux-cachyos-rc";
    configPath = ./config-nix/cachyos-rc.x86_64-linux.nix;

    cpuSched = "eevdf"; # rc kernel does not have scx patches ready, usually
    withUpdateScript = true;
    versions = mainVersions // {
      linux = {
        inherit (mainVersions.linuxRc) version hash;
      };
      patches = {
        # FIXME: remove patches override in next kernel update
        rev = "994b6d9ccf34fca3a7616ed4c95b252cc73cec09";
        hash = "sha256-LYNSC5mlArXov9mKdWRleQEm8rE39csG1mO3Dwzusnw=";
      };
    };
    # Prevent building kernel modules for rc kernel
    packagesExtend = _kernel: _final: prev: prev // { recurseForDerivations = false; };
  };

  cachyos-lto = mkCachyKernel {
    taste = "linux-cachyos";
    configPath = ./config-nix/cachyos-lto.x86_64-linux.nix;

    stdenv = stdenvLLVM;
    useLTO = "thin";

    description = "Linux EEVDF-BORE scheduler Kernel by CachyOS built with LLVM and Thin LTO";

    packagesExtend = kernel: _finalModules: builtins.mapAttrs (k: v:
      if builtins.elem k [ "zenpower" "v4l2loopback" "zfs_cachyos" "virtualbox" ]
      then llvmModuleOverlay kernel v
      else v
    );
  };

  cachyos-sched-ext = throw "\"sched-ext\" patches were merged with \"cachyos\" flavor.";

  cachyos-server = mkCachyKernel {
    taste = "linux-cachyos-server";
    configPath = ./config-nix/cachyos-server.x86_64-linux.nix;
    basicCachy = false;
    cpuSched = "eevdf";
    ticksHz = 300;
    tickRate = "idle";
    preempt = "server";
    hugePages = "madvise";
    withDAMON = true;
    withNTSync = false;
    withHDR = false;
    description = "Linux EEVDF scheduler Kernel by CachyOS targeted for Servers";
  };

  cachyos-hardened = mkCachyKernel {
    taste = "linux-cachyos-hardened";
    configPath = ./config-nix/cachyos-hardened.x86_64-linux.nix;
    cpuSched = "hardened";
    versions = mainVersions // {
      linux = {
        version = "6.9.2";
        hash = "sha256:1yg5j284y1gz7zwxjz2abvlnas259m1y1vzd9lmcqqar5kgmnv6l";
      };
    };

    withNTSync = false;
    withHDR = false;
  };

  zfs = final.zfs_unstable.overrideAttrs (prevAttrs: {
    src = zfs-source;
    patches = [ ];
    passthru = prevAttrs.passthru // {
      kernelModuleAttribute = "zfs_cachyos";
    };
  });
}
