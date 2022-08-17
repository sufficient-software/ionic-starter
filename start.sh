#!/bin/bash

echo "🐱 What directory should it be installed in?"
read DIRNAME

echo "🐱 What ionic template should be used? (e.g. blank, tabs, list, or sidemenu)"
read TEMPLATE

echo "🐱 What will the package name be? (reverse-DNS notation, like com.rokkincat.appname)"
read APP_ID

npx @ionic/cli start $DIRNAME $TEMPLATE --no-interactive --capacitor --type=react  --package-id=$APP_ID

cd ./$DIRNAME

npm run build
npx @ionic/cli cap add ios


mkdir fastlane

cat << FASTFILE > ./fastlane/Fastfile
platform :ios do
  lane :test do
    get_certificates
    get_provisioning_profile
    cocoapods(podfile: "ios/App/Podfile")
    build_app(
      scheme: "App",
      workspace: "ios/App/App.xcworkspace",
      export_method: "development",
      destination: "generic/platform=iOS Simulator",
      derived_data_path: "ios/build",
      output_directory: "ios/build",
      skip_archive: true
    )
  end
end

platform :android do
  lane :test do
    build_android_app(task: "assemble", build_type: "Debug", project_dir: "./android/")
  end
end
FASTFILE

cat << APPFILE > ./fastlane/Appfile
app_identifier("$APP_ID")
team_id("WPBN76YKX2")
apple_id("mobile@rokkincat.com")
APPFILE


cat << GEMFILE > ./Gemfile
source "https://rubygems.org"

gem "fastlane"
gem "cocoapods"
GEMFILE


echo "🐱 Go create the repo you want to use for the signing certificates, and come paste the git url here"
read GIT_URL

cat << MATCHFILE > ./fastlane/Matchfile
git_url("$GIT_URL")
storage_mode("git")
type("development")
MATCHFILE

bundle exec fastlane produce -u mobile@rokkincat.com -a $APP_ID --skip_itc

echo "🐱 This will ask you to create a password for the certificates, make sure to put this in 1password!"

bundle exec fastlane match development

