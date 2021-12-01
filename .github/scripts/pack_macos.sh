#!/bin/sh
#Functionality from signing macos package
# create variables

import_certificate() {
    echo "runner them is " $RUNNER_TEMP
    CERTIFICATE_PATH=$RUNNER_TEMP/build_certificate.p12
    # import certificate from secrets
    echo -n "$OSX_INSTALLER_CERT_BASE64" | base64 --decode --output $CERTIFICATE_PATH
    # create temporary keychain
    OSX_KEYCHAIN_PASSWORD=passphrase
    security create-keychain -pf "$OSX_KEYCHAIN_PASSWORD" build.keychain
    security default-keychain -s build.keychain
    security unlock-keychain -p "$OSX_KEYCHAIN_PASSWORD" build.keychain
    security import $CERTIFICATE_PATH -k build.keychain -A -P $OSX_INSTALLER_CERT_PASSWORD -T /usr/bin/codesign
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k $OSX_KEYCHAIN_PASSWORD build.keychain
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