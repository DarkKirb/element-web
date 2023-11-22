{
  prsJSON,
  nixpkgs,
}: let
  pkgs = import nixpkgs {};
  prs = builtins.fromJSON (builtins.readFile prsJSON);
  jobsets =
    (builtins.listToAttrs (
      pkgs.lib.attrsets.mapAttrsToList (
        _: info: {
          name = "pr${toString info.number}";
          value = {
            enabled = info.state == "open";
            hidden = info.state != "open";
            description = "PR ${toString info.number}: ${info.title}";
            nixexprinput = "element-web";
            nixexprpath = "hydra/default.nix";
            checkinterval = 3600;
            schedulingshares = 100;
            enableemail = false;
            emailoverride = "";
            keepnr = 1;
            inputs = {
              element-web = {
                type = "git";
                value = "${info.head.repo.clone_url} ${info.head.ref}";
                emailresponsible = false;
              };
              nixpkgs = {
                type = "git";
                value = "https://github.com/NixOS/nixpkgs.git master";
                emailresponsible = false;
              };
              github_input = {
                type = "string";
                value = "element-web";
              };
              github_repo_owner = {
                type = "string";
                value = info.head.repo.owner.login;
              };
              github_repo_name = {
                type = "string";
                value = info.head.repo.name;
              };
            };
          };
        }
      )
      prs
    ))
    // {
      element-web = {
        enabled = 1;
        hidden = false;
        description = "Current nixos config";
        nixexprinput = "element-web";
        nixexprpath = "hydra/default.nix";
        checkinterval = 0;
        schedulingshares = 100;
        enableemail = false;
        emailoverride = "";
        keepnr = 1;
        inputs = {
          element-web = {
            type = "git";
            value = "https://github.com/DarkKirb/element-web develop";
            emailresponsible = false;
          };
          nixpkgs = {
            type = "git";
            value = "https://github.com/NixOS/nixpkgs.git master";
            emailresponsible = false;
          };
          github_input = {
            type = "string";
            value = "element-web";
          };
          github_repo_owner = {
            type = "string";
            value = "DarkKirb";
          };
          github_repo_name = {
            type = "string";
            value = "element-web";
          };
        };
      };
    };
in {jobsets = pkgs.writeText "jobsets.json" (builtins.toJSON jobsets);}
