{
  description = "nixos-compose - basic setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    nxc.url = "github:elegaanz/nixos-compose/fix-vde-switch-groups";
    kapack.url = "github:oar-team/nur-kapack";
    nur.url = "github:nix-community/nur";
  };

  outputs = { self, nixpkgs, nxc, kapack, nur }:
    let
      system = "x86_64-linux";
    in
    {
      packages.${system} = nxc.lib.compose {
        inherit nixpkgs system;
        NUR = nur;
        repoOverrides = { inherit kapack; };
        composition = ./composition.nix;
      };

      defaultPackage.${system} =
        self.packages.${system}."composition::vm";

      devShell.${system} = nxc.devShells.${system}.nxcShellFull;
    };
}
