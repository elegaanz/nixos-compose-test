final: prev:
let
  keystore-password = "usAe#%EX92R7UHSYwJ";
  truststore-password = "*!YWptTiu3&okU%E9a";
in
{
  opensearch-root-cert = prev.stdenv.mkDerivation {
    buildInputs = [ prev.jre_headless ];
    name = "opensearch-root-cert-kebab";
    buildCommand = ''
      mkdir $out 
      keytool -genkeypair -ext BasicConstraints:critical=ca:true -dname CN=localkebab -storepass '${keystore-password}' -alias opensearch-root-cert -keyalg RSA -keysize 2048 -storetype PKCS12 -keystore $out/keystore.p12 -validity 3650
      keytool -export -alias opensearch-root-cert -storepass '${keystore-password}' -keystore $out/keystore.p12 -file $out/root.crt
      keytool -import -noprompt -alias opensearch-root-cert -storepass '${truststore-password}' -keystore $out/truststore.p12 -file $out/root.crt
      keytool -exportcert -rfc -alias opensearch-root-cert -file $out/cert.pem -keystore $out/truststore.p12 -storepass '${truststore-password}'
    '';
  };
}
