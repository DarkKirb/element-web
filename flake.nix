{
  description = "Description for the project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devshell.url = "github:numtide/devshell";
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
          stdenv.mkDerivation rec {
            pname = "element-web";
            version = inputs.self.lastModifiedDate;
            src = ./.;

            offlineCache = (callPackage ./yarn.nix {}).offline_cache;

            nativeBuildInputs = [yarn jq nodejs fixup_yarn_lock];

            configurePhase = ''
              runHook preConfigure

              export HOME=$(mktemp -d)

              export NODE_OPTIONS=--openssl-legacy-provider
              fixup_yarn_lock yarn.lock
              yarn config --offline set yarn-offline-mirror $offlineCache
              yarn install --offline --frozen-lockfile --ignore-platform --ignore-scripts --no-progress --non-interactive
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
