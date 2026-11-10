import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyStore;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.HexFormat;
import java.util.Properties;

/** Read the public signing identity without exposing passwords or private keys. */
class AndroidSigningIdentity {
    public static void main(String[] args) throws Exception {
        Path propertiesFile = Path.of(requiredEnvironment("ANDROID_KEY_PROPERTIES_FILE"));
        Path keystoreFile = Path.of(requiredEnvironment("ANDROID_KEYSTORE_FILE"));
        Properties properties = new Properties();
        // Match the exact Java Properties parsing used by android/app/build.gradle.
        try (InputStream input = Files.newInputStream(propertiesFile)) {
            properties.load(input);
        }
        String passwordValue = properties.getProperty("storePassword");
        String alias = properties.getProperty("keyAlias");
        if (passwordValue == null || alias == null) {
            throw new IllegalArgumentException("Signing properties require storePassword and keyAlias");
        }
        char[] password = passwordValue.toCharArray();
        try {
            KeyStore store = KeyStore.getInstance(keystoreFile.toFile(), password);
            if (!store.isKeyEntry(alias) || store.getCertificate(alias) == null) {
                throw new IllegalArgumentException("Configured keyAlias has no signing certificate");
            }
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(store.getCertificate(alias).getEncoded());
            System.out.println(HexFormat.of().formatHex(digest));
        } finally {
            Arrays.fill(password, '\0');
        }
    }

    private static String requiredEnvironment(String name) {
        String value = System.getenv(name);
        if (value == null || value.isEmpty()) {
            throw new IllegalArgumentException("Missing " + name);
        }
        return value;
    }
}
