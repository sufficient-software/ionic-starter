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

npm i --save-dev @wdio/appium-service @wdio/local-runner @wdio/mocha-framework @wdio/spec-reporter @wdio/cli webdriver wdio appium 

mkdir ./test
mkdir ./test/config
mkdir ./test/helpers
mkdir ./test/pageobjects
mkdir ./test/specs

cat << TEST_TSCONFIG > ./test/tsconfig.json
{
 "extends": "../tsconfig.json",
 "compilerOptions": {
   "outDir": "../.tsbuild/",
   "sourceMap": false,
   "module": "commonjs", 
   "removeComments": true, 
   "noImplicitAny": true, 
   "esModuleInterop": true,
   "strictPropertyInitialization": true,
   "strictNullChecks": true,
   "types": [
     "node",
     "webdriverio/async",
     "@wdio/mocha-framework",
     "expect-webdriverio"
   ],
   "target": "es2019"
 }
}
TEST_TSCONFIG

cat << TEST_WDIO_SHARED_CONFIG > ./test/config/wdio.shared.config.ts
export const config: WebdriverIO.Config = {
 autoCompileOpts: {
   autoCompile: true,
   tsNodeOpts: {
     transpileOnly: true
   },
   tsConfigPathsOpts: {
     paths: {},
     baseUrl: './'
   },
 },
 baseUrl: process.env.SERVE_PORT
   ? `http://localhost:${process.env.SERVE_PORT}`
   : `http://localhost:8100`,
 runner: 'local',
 specs: ['./test/**/*.spec.ts'],
 capabilities: [],
 logLevel: process.env.VERBOSE === 'true' ? 'debug' : 'error',
 bail: 0, // Set to 1 if you want to bail on first failed test
 waitforTimeout: 45000,
 connectionRetryTimeout: 120000,
 connectionRetryCount: 3,
 services: [],
 framework: 'mocha',
 reporters: ['spec'],
 mochaOpts: {
   timeout: 120000
 }
}
TEST_WDIO_SHARED_CONFIG

cat << TEST_WDIO_APPIUM_CONFIG > ./test/config/wdio.shared.appium.config.ts
import { config } from './wdio.shared.config';

config.port = 4723;
config.baseUrl = "capacitor://localhost/";

config.services = (config.services ? config.services : []).concat([
 [
   'appium',
   {
     command: 'node_modules/.bin/appium',
     args: {
       relaxedSecurity: true,
       address: 'localhost'
     }
   }
 ]
]);

export default config;
TEST_WDIO_APPIUM_CONFIG

cat << TEST_WDIO_ANDROID_CONFIG > ./test/config/wdio.android.config.ts
import { join } from 'path';
import config from './wdio.shared.appium.config';

config.capabilities = [
  {
    platformName: 'Android',
    maxInstances: 1,
    'appium:deviceName': 'Pixel 2 API 32',
    'appium:platformVersion': '12',
    'appium:orientation': 'PORTRAIT',
    'appium:automationName': 'UiAutomator2',
    'appium:app': join(process.cwd(), './android/app/build/outputs/apk/debug/app-debug.apk'),
    'appium:appWaitActivity': 'com.rkkn.driversseatcoop2.MainActivity',
    'appium:newCommandTimeout': 240,
    'appium:autoWebview': true,
    'appium:noReset': false,
    'appium:dontStopAppOnReset': false,
    'appium:avd': 'Pixel_2_API_32'
  },
];

exports.config = config;
TEST_WDIO_ANDROID_CONFIG

cat << TEST_WDIO_IOS_CONFIG > ./test/config/wdio.ios.config.ts
import { join } from 'path';
import config from './wdio.shared.appium.config';

config.capabilities = [
 {
   platformName: 'iOS',
   maxInstances: 1,
   'appium:deviceName': 'iPhone 13 mini',
   'appium:platformVersion': '15.5',
   'appium:orientation': 'PORTRAIT',
   'appium:automationName': 'XCUITest',
   'appium:app': join(process.cwd(), './build/Build/Products/Debug-iphonesimulator/App.app'),
   'appium:newCommandTimeout': 240,
   'appium:autoWebview': true,
   'appium:noReset': false
 }
]
config.maxInstances = 1
exports.config = config;
TEST_WDIO_IOS_CONFIG

cat << TEST_WDIO_WEB_CONFIG > ./test/config/wdio.web.config.ts
import { config } from './wdio.shared.config';

config.specs = [['./test/**/*.spec.ts']];
config.filesToWatch = ['./test/**/*.spec.ts'];

config.services = (config.services ? config.services : []).concat([
 [
   'chromedriver',
   {
     args: [
       '--use-fake-ui-for-media-stream',
       '--use-fake-device-for-media-stream',
     ],
   },
 ],
]);

config.capabilities = [
 {
   maxInstances: 1,
   browserName: 'chrome',
   'goog:chromeOptions': {
     args: ['--window-size=500,1000'],
     // See https://chromedriver.chromium.org/mobile-emulation
     // For more details
     mobileEmulation: {
       deviceMetrics: { width: 393, height: 851, pixelRatio: 3 },
       userAgent:
         'Mozilla/5.0 (Linux; Android 8.0.0; Pixel 2 XL Build/OPD1.170816.004) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/%s Mobile Safari/537.36',
     },
     prefs: {
       'profile.default_content_setting_values.media_stream_camera': 1,
       'profile.default_content_setting_values.media_stream_mic': 1,
       'profile.default_content_setting_values.notifications': 1,
     },
   },
 },
];

exports.config = config;
TEST_WDIO_WEB_CONFIG


