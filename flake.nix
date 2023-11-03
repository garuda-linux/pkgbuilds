{
  description = "Garuda Linux PKGBUILD flake ❄️";

  inputs = {
    # Devshell to set up a development environment
    devshell.url = "github:numtide/devshell";
    devshell.flake = false;

    # Common used input of our flake inputs
    flake-utils.url = "github:numtide/flake-utils";

    # The single source of truth
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Easy linting of the flake and all kind of other stuff
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.flake-utils.follows = "flake-utils";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    { devshell
    , flake-parts
    , nixpkgs
    , pre-commit-hooks
    , self
    , ...
    } @ inp:
    let
      inputs = inp;

      perSystem =
        { pkgs
        , system
        , ...
        }: {
          checks.pre-commit-check = pre-commit-hooks.lib.${system}.run {
            hooks = {
              commitizen.enable = true;
              nixpkgs-fmt.enable = true;
              pkgbuilds-shellcheck = {
                enable = true;
                name = "PKGBUILD shellcheck";
                entry = "${pkgs.shellcheck}/bin/shellcheck -e SC2034 -e SC2148";
                files = "(PKGBUILD|install$)";
                types = [ "text" ];
                language = "system";
              };
              pkgbuilds-style = {
                enable = true;
                name = "PKGBUILD shfmt";
                entry = "${pkgs.shfmt}/bin/shfmt -d -w";
                files = "(PKGBUILD|install$)";
                types = [ "text" ];
                language = "system";
              };
              prettier.enable = true;
              yamllint.enable = true;
            };
            src = ./.;
          };

          devShells =
            let
              makeDevshell = import "${inp.devshell}/modules" pkgs;
              mkShell = config:
                (makeDevshell {
                  configuration = {
                    inherit config;
                    imports = [ ];
                  };
                }).shell;
            in
            rec {
              default = garuda-shell;
              garuda-shell = mkShell {
                devshell.name = "garuda-shell";
                commands = [
                  { package = "commitizen"; }
                  { package = "pre-commit"; }
                ];
                devshell.startup = {
                  preCommitHooks.text = self.checks.${system}.pre-commit-check.shellHook;
                  garudaEnv.text = ''
                    export LC_ALL="C.UTF-8"
                    export NIX_PATH=nixpkgs=${nixpkgs}
                    export SHELLCHECK_OPTS="-e SC2034 -e SC2148"
                  '';
                };
              };
            };

          formatter = pkgs.nixpkgs-fmt;

          packages = {
            deployer =
              pkgs.runCommand "deployer"
                { nativeBuildInputs = with pkgs; [ bash gnugrep openssh ]; }
                (builtins.readFile ./.ci/deployer.sh);
          };
        };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      # Flake modules
      imports = [ inputs.pre-commit-hooks.flakeModule ];

      # The available systems
      systems = [ "x86_64-linux" "aarch64-linux" ];

      # This applies to all systems
      inherit perSystem;
    };
}
