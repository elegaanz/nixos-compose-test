# k3s uses enough resources the default vm fails.
# need more memory to run: export MEM=2048
{ pkgs, nur, ... }: {
  roles =
    let
      tokenFile = pkgs.writeText "token" "p@s$w0rd";
    in
    {
      server = { pkgs, ... }: {
        environment.systemPackages = with pkgs; [ gzip jq kubectl ];
        system.activationScripts.k3s-config = ''
          SERVER=$( grep server /etc/nxc/deployment-hosts | ${pkgs.gawk}/bin/awk '{ print $1 }')
          echo 'bind-address: "'$SERVER'"' > /etc/k3s.yaml  
          echo 'node-external-ip: "'$SERVER'"' >> /etc/k3s.yaml
        '';
          
        services.k3s = {
          inherit tokenFile;
          enable = true;
          role = "server";
          configPath = "/etc/k3s.yaml";
        };        
    };

      agent = { pkgs, ... }: {
      services.k3s= {
        inherit tokenFile;
        enable = true;
        role = "agent";
        serverAddr = "https://server:6443";
      };
    };
  };
  testScript = ''
    server.succeed("true")
    #TODO example:  k3s kubectl get nodes
  '';
}
