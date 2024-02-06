{ pkgs, ... }: {
  roles = {
    foo = { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [ cowsay ];
      };
  };
  testScript = ''
    foo.succeed("true")
  '';
}
