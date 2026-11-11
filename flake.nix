{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
  # The Faun compiler, from faun-lang's main.
  inputs.faun.url = "git+https://github.com/benburk/faun-lang?ref=main";
  inputs.faun.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    {
      self,
      nixpkgs,
      faun,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              just
              dprint
              fd
              ripgrep
              nixfmt
              faun.packages.${system}.default
            ];
          };
        }
      );
    };
}
