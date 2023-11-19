{
  description = "Description for the project";

  inputs = {
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs";
    matrix-js-sdk = {
      url = "github:darkkirb/matrix-js-sdk";
      inputs.devshell.follows = "devshell";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    matrix-react-sdk = {
      url = "github:darkkirb/matrix-react-sdk";
      inputs.devshell.follows = "devshell";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.matrix-js-sdk.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.devshell.flakeModule
      ];
      systems = ["x86_64-linux" "aarch64-linux"];
      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        system,
        ...
      }: rec {
        devshells.default.devshell.packages = with pkgs; [
          nodejs
          yarn
          packages.yarn2nix
        ];
        packages.yarn2nix = with pkgs;
          yarn2nix.overrideAttrs (self: {
            postInstall =
              self.postInstall
              + ''
                cp -v ${./nix/generateNix.js} $out/libexec/yarn2nix/deps/yarn2nix/lib/generateNix.js
              '';
          });
        packages.element-web = with pkgs; let
          noPhoningHome = {
            disable_guests = true; # disable automatic guest account registration at matrix.org
            piwik = false; # disable analytics
          };
          configOverrides = writeText "element-config-overrides.json" (builtins.toJSON noPhoningHome);
        in
            mkYarnPackage rec {
            pname = "element-web";
            version = inputs.self.lastModifiedDate;
            src = ./.;

            packageJSON = ./package.json;
            yarnLock = ./yarn.lock;
            yarnNix = ./yarn.nix;

            nativeBuildInputs = [yarn jq nodejs fixup_yarn_lock];

            configurePhase = ''
              runHook preConfigure

              cp -r $node_modules node_modules

              export HOME=$(mktemp -d)

              export NODE_OPTIONS=--openssl-legacy-provider
              fixup_yarn_lock yarn.lock
              #yarn config --offline set yarn-offline-mirror $offlineCache
              #yarn install --offline --frozen-lockfile --ignore-platform --ignore-scripts --no-progress --non-interactive
              chmod -R +w node_modules
              rm -rf node_modules/matrix-js-sdk
              cp -rv ${inputs.matrix-js-sdk} node_modules/matrix-js-sdk
              rm -rf node_modules/matrix-react-sdk
              cp -rv ${inputs.matrix-react-sdk} node_modules/matrix-react-sdk
              chmod -R +w node_modules
              patchShebangs node_modules

              runHook postConfigure
            '';

            buildPhase = ''
              runHook preBuild

              export VERSION=${version}
              yarn build:res
              yarn build:module_system
              yarn build:bundle

              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall

              cp -R webapp $out
              cp ${jitsi-meet}/libs/external_api.min.js $out/jitsi_external_api.min.js
              echo "${version}" > "$out/version"
              jq -s '.[0] * .[1]' "config.sample.json" "${configOverrides}" > "$out/config.json"

              runHook postInstall
            '';

            distPhase = "true";
            meta = {
              description = "A glossy Matrix collaboration client for the web";
              homepage = "https://element.io/";
              changelog = "https://github.com/vector-im/element-web/blob/v${version}/CHANGELOG.md";
              maintainers = lib.teams.matrix.members;
              license = lib.licenses.asl20;
              platforms = lib.platforms.all;
            };
          };
        formatter = pkgs.alejandra;
      };
      flake = {
        hydraJobs = {
          inherit (inputs.self) devShells packages formatter;
        };
      };
    };
}
