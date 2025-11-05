# iOS UDID Registration Server

This will:
- Generate, sign, and deliver a MobileConfig profile
- Capture the UDID from the MobileConfig request
- Add the UDID to AppStoreConnect

This is for:
- Distributing adhoc iOS apps without manually entering tester's device UDID

## Setup

1. Create the configuration file
```bash
cp env.example .env
```

2. Edit the configuration file (everything is required)
```bash
# This is the "Key ID" from App Store Connect
APPLE_API_KEY=
# This is the "Issuer ID" from App Store Connect
APPLE_ISSUER_ID=your_issuer_id
# This is the private API key downloaded from App Store Connect
APPLE_AUTHKEY_PATH=../AuthKey.p8
# The https URL where this server exists
SERVER_URL=https://udid.zerogon.consulting
# This is your distribution/development public key in PEM format
# Get it by exporting the certificate in Keychain Access then running the following
# openssl x509 -inform DER -outform PEM -in pub.cer -out your-pub-cert.pem
SIGNER_PATH=../your-pub-cert.pem
# This is your distribution/development private key in PEM format
# Get it by exporting the private key in Keychain Access then running the following:
# openssl pkcs12 -in Certificates.p12 -nodes -out your-priv-key.pem -legacy
PRIVKEY_PATH=../your-priv-key.pem
# which openssl
OPENSSL_PATH=/opt/homebrew/bin/openssl
# This is the FULLCHAIN cert. It needs to be fullchain in order to show as "verified". This means you include the Apple Root CA, the intermediary CA (World Wide Developer...) and your cert (the cert you get from creating a CSR in Keychain Access and uploading to Apple)
CERTFILE_PATH=../your_cert.pem
# Where user gets redirected after having their UDID added to the account. I am using a manifest.plist which links to a signed .ipa for download.
FINAL_URL=itms-services://?action=download-manifest&url=https://zerogon.consulting/manifest.plist
```

3. Run the server
```bash
swift run
```
