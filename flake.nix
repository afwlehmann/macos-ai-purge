{
  description = "Home Manager module that turns off Apple Intelligence on macOS 26 and 27";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    systems.url = "github:nix-systems/default";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      home-manager,
      git-hooks,
      ...
    }:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
      exampleFor =
        settings:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          modules = [
            self.homeModules.default
            {
              home = {
                username = "alex";
                homeDirectory = "/Users/alex";
                stateVersion = "26.05";
              };
              programs.macosAiPurge = {
                enable = true;
              }
              // settings;
            }
          ];
        };
    in
    {
      homeModules.default = ./modules/ai-purge.nix;
      # Legacy output name, kept for consumers that still use it.
      homeManagerModules.default = self.homeModules.default;

      homeConfigurations = {
        example-26 = exampleFor {
          macosVersion = 26;
          mode = "recommended";
          aiFeatures.writing-tools = true;
          privacySettings = {
            icloud-default-save = false;
            network-ds-store-files = true;
          };
        };
        example-27 = exampleFor {
          macosVersion = 27;
          mode = "recommended";
        };
        # Module defaults only (mode "recommended").
        example-minimal = exampleFor { };
      };

      checks = forEachSystem (
        system:
        {
          pre-commit-check = git-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              # Formatting
              nixfmt.enable = true;
              # Linting
              statix.enable = true;
              deadnix.enable = true;
              # Secrets and commit messages (Conventional Commits)
              ripsecrets.enable = true;
              convco.enable = true;
            };
          };
        }
        // nixpkgs.lib.optionalAttrs (system == "aarch64-darwin") {
          example-minimal = self.homeConfigurations.example-minimal.activationPackage;
          example-26 = self.homeConfigurations.example-26.activationPackage;
          example-27 = self.homeConfigurations.example-27.activationPackage;
          module-tests = import ./tests/module.nix {
            inherit (nixpkgs) lib;
            inherit home-manager;
            pkgs = nixpkgs.legacyPackages.${system};
            module = self.homeModules.default;
          };
        }
      );

      devShells = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (self.checks.${system}.pre-commit-check) shellHook enabledPackages;
        in
        {
          default = pkgs.mkShell {
            inherit shellHook;
            buildInputs = enabledPackages;
          };
        }
      );

      formatter = forEachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
