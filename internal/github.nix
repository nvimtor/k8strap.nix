{
  terraform = {
    required_providers = {
      github = {
        source = "integrations/github";
      };

      sops = {
        source = "carlpett/sops";
      };
    };
  };

  data = {
    sops_file = {
      secrets = {
        source_file = "internal/secrets.enc.yaml";
      };
    };
  };

  provider = {
    github = {
      token = "\${data.sops_file.secrets.data[\"github_token\"]}";
    };
  };

  resource = {
    github_repository.k8strap-nix = {
      name = "k8strap.nix";
      description = "";
      visibility = "public";
    };
  };
}
