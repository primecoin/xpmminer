{
  description = "xpmminer development environment (Pinned to NixOS 25.05)";

  inputs = {
    # 1. Source: Explicitly pin to the NixOS 25.05 branch
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    
    # 2. Import Devenv
    devenv.url = "github:cachix/devenv";
    
    # 3. Critical: Force Devenv to use our pinned nixpkgs (25.05)
    # This prevents Devenv from pulling its own 'rolling' version of packages.
    devenv.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, devenv, ... } @ inputs:
    let
      system = "x86_64-linux";
    in
    {
      devShells.${system}.default = let
        pkgs = import nixpkgs {
          inherit system;
          # Global configuration to allow unfree packages (Required for CUDA)
          config.allowUnfree = true;
        };
      in devenv.lib.mkShell {
        inherit inputs pkgs;
        
        # Load the configuration from devenv.nix
        modules = [
          ./devenv.nix
        ];
      };
    };
}