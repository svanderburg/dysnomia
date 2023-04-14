{
  inputs = {
    nixpkgs-parent.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs-parent, ... }@inputs: {
    packages.x86_64-linux.default =
      let
        nixpkgs = import nixpkgs-parent { system = "x86_64-linux"; };
      in
        with nixpkgs;
        (pkgs.callPackage ./release.nix {
          nixpkgs = nixpkgs-parent;
          inherit pkgs system;
          dysnomia = self;
        }).release;
  };
}
