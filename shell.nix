{
  source ? builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/e7603eba51f2c7820c0a182c6bbb351181caa8e7.tar.gz";
    sha256 = "sha256:0mwck8jyr74wh1b7g6nac1mxy6a0rkppz8n12andsffybsipz5jw";
  },
  pkgs ? import source {}
}:

pkgs.mkShell {
  name = "nim-dnsdisc-shell";

  buildInputs = with pkgs; [ git which pcre nim ];

  shellHook = ''
    export MAKEFLAGS="-j$NIX_BUILD_CORES"
  '';

  # Sandbox causes Xcode issues on MacOS. Requires sandbox=relaxed.
  # https://github.com/status-im/status-mobile/pull/13912
  __noChroot = pkgs.stdenv.isDarwin;
}
