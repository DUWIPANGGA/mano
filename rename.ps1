param (
    [Parameter(Mandatory=$true)]
    [string]$APP_NAME
)

# normalize bundle id part
$PACKAGE = ($APP_NAME -replace '\s+', '').ToLower()

Write-Host "Rename Flutter App"
Write-Host "App Name  : $APP_NAME"
Write-Host "Bundle ID : com.company.$PACKAGE"

flutter pub get

flutter pub run rename setAppName --targets android,ios --value "$APP_NAME"

flutter pub run rename setBundleId --targets android,ios --value "com.company.$PACKAGE"

dart run flutter_launcher_icons

flutter clean
flutter pub get
flutter build apk

flutter install

Write-Host "DONE"
