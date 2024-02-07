{ pkgs, ... }: {
  roles = {
    foo = { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [ opensearch ];
        services.opensearch.enable = true;
        services.nginx.enable = true;
        services.openssh.authorizedKeysCommandUser = [
          ./cle.pub
        ];
        services.opensearch.extraJavaOptions= [
          "-Xmx512m"
          "-Xms512m"
        ];
      };
  };
  testScript = ''
    foo.succeed("true")
  '';
}
