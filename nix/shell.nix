{ pkgs, nim ? null, }:

let
  creator = pkgs.callPackage ./default.nix { inherit nim; };
in pkgs.mkShell {
  name = "nim-dnsdisc-shell";

  inputsFrom = [ creator ];

  shellHook = ''
    export MAKEFLAGS="-j$NIX_BUILD_CORES"
  '';

  # Sandbox causes Xcode issues on MacOS. Requires sandbox=relaxed.
  # https://github.com/status-im/status-mobile/pull/13912
  __noChroot = pkgs.stdenv.isDarwin;
}
