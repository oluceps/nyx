{ mkCachyKernel, stdenvLLVM }: {

  cachyos-zen3 = mkCachyKernel {
    taste = "linux-cachyos";
    configPath = ./config-nix/cachyos.x86_64-linux.nix;
    archOptimize = "ZEN3";
    withBBR3 = true;
    withUpdateScript = true;
  };

  cachyos-lto-zen3 = mkCachyKernel {
    taste = "linux-cachyos";
    configPath = ./config-nix/cachyos.x86_64-linux.nix;

    stdenv = stdenvLLVM;
    useLTO = "thin";
    archOptimize = "ZEN3";
    withBBR3 = true;
  };

  cachyos-lto-zen4 = mkCachyKernel {
    taste = "linux-cachyos";
    configPath = ./config-nix/cachyos.x86_64-linux.nix;

    stdenv = stdenvLLVM;
    useLTO = "thin";
    archOptimize = "ZEN4";
    withBBR3 = true;
  };

  cachyos-server-lto-zen3 = mkCachyKernel {
    taste = "linux-cachyos-server";
    configPath = ./config-nix/cachyos-server.x86_64-linux.nix;
    basicCachy = false;
    cpuSched = "eevdf";
    ticksHz = 300;
    tickRate = "idle";
    preempt = "server";
    hugePages = "madvise";
    withDAMON = true;
    stdenv = stdenvLLVM;
    useLTO = "thin";
    archOptimize = "ZEN3";
    withBBR3 = true;
  };


  cachyos-server-lto-broadwell = mkCachyKernel {
    taste = "linux-cachyos-server";
    configPath = ./config-nix/cachyos-server.x86_64-linux.nix;
    basicCachy = false;
    cpuSched = "eevdf";
    ticksHz = 300;
    tickRate = "idle";
    preempt = "server";
    hugePages = "madvise";
    withDAMON = true;
    stdenv = stdenvLLVM;
    useLTO = "thin";
    archOptimize = "BROADWELL";
    withBBR3 = true;
  };

  cachyos-server-lto = mkCachyKernel {
    taste = "linux-cachyos-server";
    configPath = ./config-nix/cachyos-server.x86_64-linux.nix;
    basicCachy = false;
    cpuSched = "eevdf";
    ticksHz = 300;
    tickRate = "idle";
    preempt = "server";
    hugePages = "madvise";
    withDAMON = true;
    stdenv = stdenvLLVM;
    useLTO = "thin";
    withBBR3 = true;
  };

}
