#!/bin/sh
#Functionality from signing macos package
# create variables

import_certificate() {
    echo "runner them is " $RUNNER_TEMP
    CERTIFICATE=$RUNNER_TEMP/certificate.p12
    OSX_KEYCHAIN=$RUNNER_TEMP/app-signing.keychain
    # import certificate from secrets
    echo -n "$OSX_INSTALLER_CERT_BASE64" | base64 --decode --output $CERTIFICATE
    echo $OSX_INSTALLER_CERT_BASE64
    echo $OSX_INSTALLER_CERT_PASS
    # create temporary keychain
    OSX_KEYCHAIN_PASSWORD="passphrase"
    security list-keychains
    security create-keychain -p "$OSX_KEYCHAIN_PASSWORD" $OSX_KEYCHAIN
    security unlock-keychain -p "$OSX_KEYCHAIN_PASSWORD" $OSX_KEYCHAIN 
    ls $RUNNER_TEMP
    security list-keychains
    security import $CERTIFICATE -k $OSX_KEYCHAIN -f pkcs12 -A -T /usr/bin/codesign -T /usr/bin/security -P "$OSX_INSTALLER_CERT_PASSWORD"
    security set-key-partition-list -S apple-tool:,apple: -k "$OSX_KEYCHAIN_PASSWORD" $OSX_KEYCHAIN
    #security import $CERTIFICATE_PATH -k $KEYCHAIN_PATH -A -P $OSX_INSTALLER_CERT_PASSWORD -T /usr/bin/codesign -T /usr/bin/security
    security find-identity
}
notarize_and_staple() {
    #Functionality  to notarize application
    #xcrun notarytool store-credentials new-profile --apple-id "kgoswami@twilio.com" --password "tqsk-taur-nnau-kvxm" --team-id "VPZ4UMT2G9"
    xcrun notarytool store-credentials new-profile --apple-id "$APPLE_ID" --password "$APPLE_ID_APP_PASSWORD" --team-id "$APPLE_TEAM_ID"
    xcrun notarytool submit "$FILE_PATH" --keychain-profile new-profile --wait -f json >> $RUNNER_TEMP/notarization_log.json
    notarization_status=$(jq -r .status $RUNNER_TEMP/notarization_log.json)
    notarization_id=$(jq -r .id $RUNNER_TEMP/notarization_log.json)
    echo "for notarization id ${notarization_id} the status is ${notarization_status}"
    if [${notarization_status} = "Accepted"]
    then
      xcrun stapler staple "$FILE_PATH"
      spctl --assess -vv --type install "$FILE_PATH"
    else
      echo "Notarization unsuccessfull"
      #get notarization logs
      xcrun notarytool log ${notarization_id} --keychain-profile new-profile $RUNNER_TEMP/notarization_log.json
      jq . $RUNNER_TEMP/notarization_log.json
      exit 1
    fi
}

pack_macos() {
    import_certificate
    npx oclif-dev pack:macos
    notarize_and_staple
}

make install
brew install makensis
pack_macos
