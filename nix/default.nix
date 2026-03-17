{
  pkgs,
  src ? ../.,
  # Nimbus-build-system package.
  nim ? null,
  # Options: 0,1,2
  verbosity ? 1,
  # Make targets
  targets ? ["creator"],
  # These are the only platforms tested in CI and considered stable.
  stableSystems ? ["x86_64-linux" "aarch64-linux"],
}:

assert pkgs.lib.assertMsg ((src.submodules or true) == true)
  "Unable to build without submodules. Append '?submodules=1#' to the URI.";

let
  inherit (pkgs) stdenv lib writeScriptBin callPackage;
  inherit (lib) any match substring optionals optionalString;

  tools = pkgs.callPackage ./tools.nix {};
  version = tools.findKeyValue "^version += \"([a-f0-9.-]+)\"$" ../dnsdisc.nimble;
  revision = lib.substring 0 8 (src.rev or src.dirtyRev or "00000000");

in stdenv.mkDerivation {
  pname = "nim-dnsdisc";
  version = "${version}-${revision}";

  inherit src;

  enableParallelBuilding = true;

  env = {
    # Disable CPU optimizations that make binary not portable.
    NIMFLAGS = "-d:disableMarchNative";
    # Avoid errors about missing user home.
    NIMBLE_DIR = "/tmp";
    # Avoid Nim cache permission errors.
    XDG_CACHE_HOME = "/tmp";
  };

  makeFlags = targets ++ [
    "V=${toString verbosity}"
    # Built from nimbus-build-system via flake.
    "USE_SYSTEM_NIM=1"
  ];

  # Dependencies that should only exist in the build environment.
  nativeBuildInputs = let
    # Fix for Nim compiler calling 'git rev-parse' and 'lsb_release'.
    fakeGit = writeScriptBin "git" "echo ${revision}";
  in with pkgs; [
    nim pcre which fakeGit
  ];

  configurePhase = ''
    patchShebangs vendor/nimbus-build-system/scripts
    make nimbus-build-system-paths
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp build/* $out/bin/
  '';

  meta = with pkgs.lib; {
    description = "Nim discovery library supporting EIP-1459";
    homepage = "https://github.com/status-im/nim-dnsdisc";
    license = with licenses; [asl20 mit];
    platforms = stableSystems;
    mainProgram = builtins.head targets;
  };
}
