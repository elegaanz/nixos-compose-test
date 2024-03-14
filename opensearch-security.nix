final: prev:
let
  keystore-password = "usAe#%EX92R7UHSYwJ";
  truststore-password = "*!YWptTiu3&okU%E9a";
in
rec {
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

  init-keystore = prev.writeShellScript
    "init-keystore"
    ''
      if [[ -f /var/lib/opensearch/config/ssl-keystore.p12 ]]; then
        exit 0
      fi

      ${prev.jre_headless}/bin/keytool \
        -genkeypair \
        -alias opensearch \
        -storepass '${keystore-password}' \
        -dname CN=$(hostname) \
        -keyalg RSA \
        -sigalg SHA256withRSA \
        -keystore /var/lib/opensearch/config/ssl-keystore.p12 \
        -ext ExtendedKeyUsage=serverAuth,clientAuth \
        -ext SAN=dns:$(hostname),dns:localhost \
        -validity 36500

        ${prev.jre_headless}/bin/keytool -certreq -alias opensearch -keystore /var/lib/opensearch/config/ssl-keystore.p12 -file /var/lib/opensearch/config/newkey.csr -storepass '${keystore-password}'

        ${prev.jre_headless}/bin/keytool -gencert -infile /var/lib/opensearch/config/newkey.csr -outfile /var/lib/opensearch/config/newkey.crt -alias opensearch-root-cert -keystore ${opensearch-root-cert}/keystore.p12 -storepass '${keystore-password}' \
          -ext ExtendedKeyUsage=serverAuth,clientAuth \
          -ext SAN=dns:$(hostname),dns:localhost

        ${prev.jre_headless}/bin/keytool -importcert -file ${opensearch-root-cert}/root.crt -keystore /var/lib/opensearch/config/ssl-keystore.p12 -alias opensearch-root-cert -storepass '${keystore-password}' -noprompt
        
        ${prev.jre_headless}/bin/keytool -importcert -file /var/lib/opensearch/config/newkey.crt -keystore /var/lib/opensearch/config/ssl-keystore.p12 -alias opensearch -storepass '${keystore-password}' -noprompt

        cp ${opensearch-root-cert}/truststore.p12 /var/lib/opensearch/config/ssl-truststore.p12
    '';

  wait-and-run-security-admin = prev.writeShellScript
    "wait-and-run-securityadmin"
    ''
      # wait for opensearch to start
      while ! ${prev.nettools}/bin/netstat -tlnp | grep ':9200' ; do
        sleep 1
      done

      ${prev.jre_headless}/bin/keytool \
        -genkeypair \
        -alias securityclient \
        -storepass '${keystore-password}' \
        -dname CN=admin_secu_le_boss \
        -keyalg RSA \
        -sigalg SHA256withRSA \
        -keystore /var/lib/opensearch/security.p12 \
        -validity 36500

      ${prev.jre_headless}/bin/keytool \
        -certreq \
        -alias securityclient \
        -keystore /var/lib/opensearch/security.p12 \
        -file /var/lib/opensearch/security-key.csr \
        -storepass '${keystore-password}'

      ${prev.jre_headless}/bin/keytool \
        -gencert \
        -infile /var/lib/opensearch/security-key.csr \
        -outfile /var/lib/opensearch/security-key.crt \
        -alias opensearch-root-cert \
        -keystore ${opensearch-root-cert}/keystore.p12 \
        -storepass '${keystore-password}'

      ${prev.jre_headless}/bin/keytool \
        -importcert \
        -file ${opensearch-root-cert}/root.crt \
        -keystore /var/lib/opensearch/security.p12 \
        -alias opensearch-root-cert \
        -storepass '${keystore-password}' -noprompt
      
      ${prev.jre_headless}/bin/keytool \
        -importcert \
        -file /var/lib/opensearch/security-key.crt \
        -keystore /var/lib/opensearch/security.p12 \
        -alias securityclient \
        -storepass '${keystore-password}' \
        -noprompt

    ${prev.coreutils}/bin/env JAVA_HOME="${prev.jre_headless}" \
      /var/lib/opensearch/plugins/opensearch-security/tools/securityadmin.sh \
        -h $(hostname) \
        -cn boris \
        -ks /var/lib/opensearch/security.p12 \
        -kspass '${keystore-password}' \
        -ksalias securityclient \
        -ts /var/lib/opensearch/config/ssl-truststore.p12 \
        -tspass '${truststore-password}' \
        -cd /var/lib/opensearch/config/opensearch-security
    '';
}
