{
  description = "My forth version on turning my neovim configuration in to a flake";
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
    neovim-src = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils = {
      url = "github:numtide/flake-utils";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    neovim-src,
    ...
  }:
    {
      overlay = self.overlays.default;
      overlays = {
        neovim = _: final: {
          neovim = self.packages.${final.system}.default;
        };
        default = self.overlays.neovim;
      };
    }
    // flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      lib = pkgs.lib;
      getPlugins = import ./plugins/_sources/generated.nix {inherit (pkgs) fetchurl dockerTools fetchgit fetchFromGitHub;};
    in rec {
      formatter = pkgs.alejandra;
      apps = rec {
        neovim = {
          type = "app";
          program = "${packages.default}/bin/nvim";
        };
        default = neovim;
      };

      packages = rec {
        neovim = pkgs.callPackage ./wrapper.nix {
          plugins =
            (lib.attrsets.mapAttrsToList (
                _: value:
                  pkgs.vimUtils.buildVimPluginFrom2Nix {
                    pname = value.pname;
                    version = value.version;
                    src = value.src;
                  }
              )
              getPlugins)
            ++ [pkgs.vimPlugins.nvim-treesitter.withAllGrammars];
          unwrappedTarget = neovim-src.packages.${system}.default;
          extraPackages = with pkgs; [
            #rust
            rustfmt
            #nix
            deadnix
            statix
            alejandra
            nil

            #other
            ripgrep
            fd
          ];
        };
        default = neovim;
      };

      devShells = {
        default = pkgs.mkShell {
          packages = [packages.default pkgs.nvfetcher];
        };
      };
    });
}
