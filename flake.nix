{
  description = "I, Librarian - Reference and PDF manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f nixpkgs.legacyPackages.${system});
  in {
    packages = forAllSystems (pkgs: {
      default = pkgs.callPackage ./derivation.nix {};
    });

    nixosModules.default = import ./module.nix;

    # 1. Automated VM Test
    checks = forAllSystems (pkgs: {
      service-test = pkgs.testers.nixosTest {
        name = "i-librarian-test";
        nodes.machine = {
          config,
          pkgs,
          ...
        }: {
          imports = [self.nixosModules.default];
          services.i-librarian = {
            enable = true;
            domain = "localhost";
            port = 8080;
          };
          services.nginx.enable = true;
        };

        testScript = ''
          machine.wait_for_unit("phpfpm-i-librarian.service")
          machine.wait_for_unit("nginx.service")
          machine.wait_for_open_port(8080)
          # Verify the app is serving the index page
          machine.succeed("curl -f http://localhost:8080/index.php")
        '';
      };
    });

    # 2. Interactive Debug Shell
    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        buildInputs = [
          (pkgs.php.withExtensions ({
            enabled,
            all,
          }:
            enabled ++ [all.curl all.xml all.dom all.openssl]))
          pkgs.curl
        ];
        shellHook = ''
          echo "--- I, Librarian Debug Shell ---"
          echo "PHP version: $(php -v | head -n 1)"
          echo "Testing arXiv connectivity..."
          curl -I "https://export.arxiv.org/api/query?search_query=all:electron"
        '';
      };
    });
  };
}
