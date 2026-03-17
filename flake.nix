{
  description = "Nim discovery library supporting EIP-1459";

  nixConfig = {
    extra-substituters = [ "https://nix-cache.status.im/" ];
    extra-trusted-public-keys = [ "nix-cache.status.im-1:x/93lOfLU+duPplwMSBR+OlY4+mo+dCN7n0mr4oPwgY=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?rev=2a777ace4b722f2714cc06d596f2476ee628c04a";
    nimbusBuildSystem = {
      url = "git+file:./vendor/nimbus-build-system?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # WARNING: Does not work with 'github:' schema URLs.
    # https://github.com/NixOS/nix/issues/14982
    self.submodules = true;
  };

  outputs = { self, nixpkgs, nimbusBuildSystem }:
    assert (builtins.compareVersions builtins.nixVersion "2.27") <= 0
      -> throw "Nix 2.27 or newer needed for proper submodules support!";

    let
      stableSystems = [
        "x86_64-linux" "aarch64-linux"
        "x86_64-darwin" "aarch64-darwin"
        "x86_64-windows" "i686-linux"
        "i686-windows"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs stableSystems (system: f system);
      pkgsFor = forAllSystems (
        system: import nixpkgs { inherit system; }
      );

    in rec {
      packages = forAllSystems (system: let
        nim = nimbusBuildSystem.packages.${system}.nim;

        buildTargets = pkgsFor.${system}.callPackage ./nix/default.nix {
          inherit stableSystems nim;
          src = self;
        };
      in rec {
        creator = buildTargets.override { targets = [ "creator" ]; };

        default = creator;
      });

      devShells = forAllSystems (system: {
        default = pkgsFor.${system}.callPackage ./nix/shell.nix {
          inherit (nimbusBuildSystem.packages.${system}) nim;
        };
      });
    };
}
