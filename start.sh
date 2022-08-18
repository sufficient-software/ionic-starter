#!/bin/bash

echo "🐱 What directory should it be installed in?"
read DIRNAME

echo "🐱 What ionic template should be used? (e.g. blank, tabs, list, or sidemenu)"
read TEMPLATE

echo "🐱 What will the package name be? (reverse-DNS notation, like com.rokkincat.appname)"
read APP_ID

echo "🐱 What will name of the app be in the App store?"
read APP_NAME

npx @ionic/cli start $DIRNAME $TEMPLATE --no-interactive --capacitor --type=react  --package-id=$APP_ID

cd ./$DIRNAME

npm run build
npx @ionic/cli cap add ios
npx @ionic/cli cap add android


mkdir fastlane

cat << FASTFILE > ./fastlane/Fastfile
platform :ios do
  lane :test do
    get_certificates()
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
team_name("Rokkincat LLC")
apple_id("mobile@rokkincat.com")
APPFILE


cat << GEMFILE > ./Gemfile
source "https://rubygems.org"

gem "fastlane"
gem "cocoapods"
GEMFILE


GIT_URL=git@github.com:RokkinCat/apple-certificates.git

cat << MATCHFILE > ./fastlane/Matchfile
git_url("$GIT_URL")
storage_mode("git")
type("development")
MATCHFILE

export PRODUCE_APP_NAME=$APP_NAME
export PRODUCE_USERNAME=mobile@rokkincat.com
export PRODUCE_APP_IDENTIFIER=$APP_ID
bundle exec fastlane produce --skip_itc

echo "🐱 This will ask you to create a password for the certificates, make sure to put this in 1password!"

bundle exec fastlane cert

export MATCH_USERNAME=mobile@rokkincat.com
bundle exec fastlane match development

npm i --save-dev @wdio/appium-service @wdio/local-runner @wdio/mocha-framework @wdio/spec-reporter @wdio/cli ts-node webdriver appium-webdriverio appium-webdriveragent appium-xcuitest-driver

mkdir ./test
mkdir ./test/config
mkdir ./test/helpers
mkdir ./test/pageobjects
mkdir ./test/specs
mkdir -p ./test/helpers/ionic/components
mkdir -p ./test/helpers/platform

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
   ? \`http://localhost:\${process.env.SERVE_PORT}\`
   : \`http://localhost:8100\`,
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
   'appium:deviceName': 'iPhone 13',
   'appium:platformVersion': '16.0',
   'appium:orientation': 'PORTRAIT',
   'appium:automationName': 'XCUITest',
   'appium:app': join(process.cwd(), './ios/build/Build/Products/Debug-iphonesimulator/App.app'),
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


cat << TEST_HELPER_BROWSER > ./test/helpers/browser.ts
export async function getUrl(): Promise<URL> {
 return new URL(await browser.getUrl());
}
TEST_HELPER_BROWSER

cat << TEST_HELPER_DEFINITIONS > ./test/helpers/definitions.ts
export interface ElementActionOptions {
 /**
  * How long to wait (in ms) for the element to be visible before
  * the test fails. Default: 5000 ms
  */
 visibilityTimeout?: number;
}

export interface ElementSelector {
 text?: string;
}
TEST_HELPER_DEFINITIONS

cat << TEST_HELPER_ELEMENT > ./test/helpers/element.ts
import { ElementActionOptions } from './definitions';

export async function waitForElement(selector: string, { visibilityTimeout = 5000 }: ElementActionOptions = {}) {
 const el = await \$(selector);
 await el.waitForDisplayed({ timeout: visibilityTimeout });
 return el;
}

export async function blur(selector: string, { visibilityTimeout = 5000 }: ElementActionOptions = {}) {
 return browser.execute((sel) => {
   const el = document.querySelector(sel);
   if (el) {
     (el as any).blur();
   }
 }, selector);
}

export async function tryAcceptAlert() {
 try {
   return driver.acceptAlert();
 } catch (e) {
   console.warn('No alert to accept');
 }
}
TEST_HELPER_ELEMENT

cat << TEST_HELPER_GESTURES > ./test/helpers/gestures.ts
/**
* Ported from the WebdriverIO native sample https://github.com/webdriverio/appium-boilerplate
*
* MIT License
*
* Copyright (c) 2018 WebdriverIO
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

import type { RectReturn } from '@wdio/protocols/build/types';

/**
* To make a Gesture methods more robust for multiple devices and also
* multiple screen sizes the advice is to work with percentages instead of
* actual coordinates. The percentages will calculate the position on the
* screen based on the SCREEN_SIZE which will be determined once if needed
* multiple times.
*/

let SCREEN_SIZE: RectReturn;
interface XY {
 x: number;
 y: number;
}

/**
* The values in the below object are percentages of the screen
*/
const SWIPE_DIRECTION = {
 down: {
   start: { x: 50, y: 15 },
   end: { x: 50, y: 85 },
 },
 left: {
   start: { x: 95, y: 50 },
   end: { x: 5, y: 50 },
 },
 right: {
   start: { x: 5, y: 50 },
   end: { x: 95, y: 50 },
 },
 up: {
   start: { x: 50, y: 85 },
   end: { x: 50, y: 15 },
 },
};

export class Gestures {
 /**
  * Check if an element is visible and if not wipe up a portion of the screen to
  * check if it visible after x amount of scrolls
  */
 static async checkIfDisplayedWithSwipeUp(
   element: WebdriverIO.Element,
   maxScrolls: number,
   amount = 0
 ) {
   // If the element is not displayed and we haven't scrolled the max amount of scrolls
   // then scroll and execute the method again
   if (!(await element.isDisplayed()) && amount <= maxScrolls) {
     await this.swipeUp(0.85);
     await this.checkIfDisplayedWithSwipeUp(element, maxScrolls, amount + 1);
   } else if (amount > maxScrolls) {
     // If the element is still not visible after the max amount of scroll let it fail
     throw new Error(
       \`The element '\${element}' could not be found or is not visible.\`
     );
   }

   // The element was found, proceed with the next action
 }

 /**
  * Swipe down based on a percentage
  */
 static async swipeDown(percentage = 1) {
   return this.swipeOnPercentage(
     this.calculateXY(SWIPE_DIRECTION.down.start, percentage),
     this.calculateXY(SWIPE_DIRECTION.down.end, percentage)
   );
 }

 /**
  * Swipe Up based on a percentage
  */
 static async swipeUp(percentage = 1) {
   return this.swipeOnPercentage(
     this.calculateXY(SWIPE_DIRECTION.up.start, percentage),
     this.calculateXY(SWIPE_DIRECTION.up.end, percentage)
   );
 }

 /**
  * Swipe left based on a percentage
  */
 static async swipeLeft(percentage = 1) {
   return this.swipeOnPercentage(
     this.calculateXY(SWIPE_DIRECTION.left.start, percentage),
     this.calculateXY(SWIPE_DIRECTION.left.end, percentage)
   );
 }

 /**
  * Swipe right based on a percentage
  */
 static async swipeRight(percentage = 1) {
   return this.swipeOnPercentage(
     this.calculateXY(SWIPE_DIRECTION.right.start, percentage),
     this.calculateXY(SWIPE_DIRECTION.right.end, percentage)
   );
 }

 /**
  * Swipe from coordinates (from) to the new coordinates (to). The given coordinates are
  * percentages of the screen.
  */
 static async swipeOnPercentage(from: XY, to: XY) {
   // Get the screen size and store it so it can be re-used.
   // This will save a lot of webdriver calls if this methods is used multiple times.
   SCREEN_SIZE = SCREEN_SIZE || (await driver.getWindowRect());
   // Get the start position on the screen for the swipe
   const pressOptions = this.getDeviceScreenCoordinates(SCREEN_SIZE, from);
   // Get the move to position on the screen for the swipe
   const moveToScreenCoordinates = this.getDeviceScreenCoordinates(
     SCREEN_SIZE,
     to
   );

   return this.swipe(pressOptions, moveToScreenCoordinates);
 }

 /**
  * Swipe from coordinates (from) to the new coordinates (to). The given coordinates are in pixels.
  */
 static async swipe(from: XY, to: XY) {
   await driver.performActions([
     {
       // a. Create the event
       type: 'pointer',
       id: 'finger1',
       parameters: { pointerType: 'touch' },
       actions: [
         // b. Move finger into start position
         { type: 'pointerMove', duration: 0, x: from.x, y: from.y },
         // c. Finger comes down into contact with screen
         { type: 'pointerDown', button: 0 },
         // d. Pause for a little bit
         { type: 'pause', duration: 100 },
         // e. Finger moves to end position
         //    We move our finger from the center of the element to the
         //    starting position of the element.
         //    Play with the duration to make the swipe go slower / faster
         { type: 'pointerMove', duration: 1000, x: to.x, y: to.y },
         // f. Finger gets up, off the screen
         { type: 'pointerUp', button: 0 },
       ],
     },
   ]);
   // Add a pause, just to make sure the swipe is done
   return driver.pause(1000);
 }

 /**
  * Get the screen coordinates based on a device his screen size
  */
 private static getDeviceScreenCoordinates(
   screenSize: RectReturn,
   coordinates: XY
 ): XY {
   return {
     x: Math.round(screenSize.width * (coordinates.x / 100)),
     y: Math.round(screenSize.height * (coordinates.y / 100)),
   };
 }

 /**
  * Calculate the x y coordinates based on a percentage
  */
 private static calculateXY({ x, y }: XY, percentage: number): XY {
   return {
     x: x * percentage,
     y: y * percentage,
   };
 }
}
TEST_HELPER_GESTURES

cat << TEST_HELPER_INDEX > ./test/helpers/index.ts
import type { Expect } from 'expect-webdriverio';
export { Expect };

export * from './definitions';
export * from './platform/index';
export * from './element';
export * from './gestures';
export * from './browser';
export * from './storage';

export * from './ionic';
TEST_HELPER_INDEX

cat << TEST_HELPER_IONIC_ALERT > ./test/helpers/ionic/components/alert.ts
import { IonicComponent } from './component';

export class IonicAlert extends IonicComponent {
 constructor(selector?: string | WebdriverIO.Element) {
   super(selector ?? 'ion-alert');
 }

 get input() {
   return \$(this.selector).\$(\`.alert-input\`);
 }

 async button(buttonTitle: string) {
   return \$(this.selector).\$(\`button=${buttonTitle}\`);
 }
}
TEST_HELPER_IONIC_ALERT

cat << TEST_HELPER_IONIC_BUTTON > ./test/helpers/ionic/components/button.ts
import { Ionic$ } from '..';
import { ElementActionOptions } from '../..';
import { IonicComponent } from './component';

export interface TapButtonOptions extends ElementActionOptions {
 /**
  * Whether to scroll the element into view first. Default: true
  */
 scroll?: boolean;
}

export class IonicButton extends IonicComponent {
 constructor(selector: string) {
   super(selector);
 }

 static withTitle(buttonTitle: string): IonicButton {
   return new IonicButton(\`ion-button=${buttonTitle}\`);
 }

 async tap({
   visibilityTimeout = 5000,
   scroll = true,
 }: TapButtonOptions = {}) {
   const button = await Ionic$.\$(this.selector as string);
   await button.waitForDisplayed({ timeout: visibilityTimeout });
   if (scroll) {
     await button.scrollIntoView();
   }
   return button.click();
 }
}
TEST_HELPER_IONIC_BUTTON

cat << TEST_HELPER_IONIC_COMPONENT > ./test/helpers/ionic/components/component.ts
export class IonicComponent {
 constructor(public selector: string | WebdriverIO.Element) {
 }

 get \$() {
   return import('./page').then(async ({ IonicPage }) => {
     if (typeof this.selector === 'string') {
       const activePage = await IonicPage.active();
       return activePage.\$(this.selector);
     }

     return this.selector;
   });
 }
}
TEST_HELPER_IONIC_COMPONENT

cat << TEST_HELPER_IONIC_CONTENT > ./test/helpers/ionic/components/content.ts
import { IonicComponent } from './component';

export class IonicContent extends IonicComponent {
 constructor(selector: string) {
   super(selector);
 }
}
TEST_HELPER_IONIC_CONTENT

cat << TEST_HELPER_IONIC_COMPONENT_INDEX > ./test/helpers/ionic/components/index.ts
export * from './button';
export * from './content';
export * from './input';
export * from './item';
export * from './menu';
export * from './page';
export * from './segment';
export * from './select';
export * from './slides';
export * from './textarea';
export * from './toast';
TEST_HELPER_IONIC_COMPONENT_INDEX

cat << TEST_HELPER_IONIC_INPUT > ./test/helpers/ionic/components/input.ts
import { IonicComponent } from './component';
import { Ionic$ } from '..';
import { ElementActionOptions } from '../..';

export class IonicInput extends IonicComponent {
 constructor(selector: string) {
   super(selector);
 }

 async setValue(
   value: string,
   { visibilityTimeout = 5000 }: ElementActionOptions = {}
 ) {
   const el = await Ionic$.\$(this.selector as string);
   await el.waitForDisplayed({ timeout: visibilityTimeout });

   const ionTags = ['ion-input', 'ion-textarea'];
   if (ionTags.indexOf(await el.getTagName()) >= 0) {
     const input = await el.\$('input,textarea');
     await input.setValue(value);
   } else {
     return el.setValue(value);
   }
 }

 async getValue({ visibilityTimeout = 5000 }: ElementActionOptions = {}) {
   const el = await Ionic$.\$(this.selector as string);
   await el.waitForDisplayed({ timeout: visibilityTimeout });

   const ionTags = ['ion-input', 'ion-textarea'];
   if (ionTags.indexOf(await el.getTagName()) >= 0) {
     const input = await el.\$('input,textarea');
     return input.getValue();
   } else {
     return el.getValue();
   }
 }
}
TEST_HELPER_IONIC_INPUT

cat << TEST_HELPER_IONIC_ITEM > ./test/helpers/ionic/components/item.ts
import { TapButtonOptions } from '.';
import { Ionic$ } from '..';
import { IonicComponent } from './component';

export class IonicItem extends IonicComponent {
 constructor(selector: string) {
   super(selector);
 }

 static withTitle(buttonTitle: string): IonicItem {
   return new IonicItem(\`ion-item=\${buttonTitle}\`);
 }

 async tap({
   visibilityTimeout = 5000,
   scroll = true,
 }: TapButtonOptions = {}) {
   const button = await Ionic$.\$(this.selector as string);
   await button.waitForDisplayed({ timeout: visibilityTimeout });
   if (scroll) {
     await button.scrollIntoView();
   }
   return button.click();
 }
}
TEST_HELPER_IONIC_ITEM

cat << TEST_HELPER_IONIC_MENU > ./test/helpers/ionic/components/menu.ts
import { Ionic$ } from '..';
import { ElementActionOptions } from '../..';
import { IonicComponent } from './component';

export interface OpenMenuOptions extends ElementActionOptions {
 delayForAnimation?: boolean;
}

export class IonicMenu extends IonicComponent {
 constructor(selector?: string) {
   super(selector || 'ion-menu');
 }

 get menuButton() {
   return Ionic$.\$('.ion-page:not(.ion-page-hidden) ion-menu-button');
 }

 async open({
   delayForAnimation = true,
   visibilityTimeout = 5000,
 }: OpenMenuOptions = {}) {
   await (
     await this.menuButton
   ).waitForDisplayed({ timeout: visibilityTimeout });
   await (await this.menuButton).click();

   // Let the menu animate open/closed
   if (delayForAnimation) {
     return driver.pause(500);
   }
 }
}
TEST_HELPER_IONIC_MENU

cat << TEST_HELPER_IONIC_PAGE > ./test/helpers/ionic/components/page.ts
import { IonicComponent } from './component';

export class IonicPage extends IonicComponent {
 static async active() {
   await driver.waitUntil(
     async () => {
       const currentPages = await \$\$('.ion-page:not(.ion-page-hidden)');
       for (const page of currentPages) {
         if ((await page.isDisplayed())) {
           return true;
         }
       }
       return false;
     }, {
     timeout: 10000,
     timeoutMsg: 'Unable to find any visible pages',
     interval: 500,
   }
   );

   const allPages = await \$\$('.ion-page:not(.ion-page-hidden)');

   const pages: WebdriverIO.Element[] = [];

   // Collect visible pages
   for (const page of allPages) {
     if ((await page.isDisplayed())) {
       pages.push(page);
     }
   }

   // Collect all the visible pages in the app
   const pagesAndParents: WebdriverIO.Element[][] = [];
   for (const page of pages) {
     const path = await this.getPath(page);
     pagesAndParents.push(path);
   }

   // Reverse sort the pages by the ones that have the most parent elements first, since
   // we assume pages deeper in the tree are more likely to be "active" than ones higher up
   const activePage = pagesAndParents.sort((a, b) => b.length - a.length)[0][0];

   return activePage;
 }

 static async getPath(el: WebdriverIO.Element) {
   const path = [el];

   let p = el;
   while (p) {
     p = await p.parentElement();
     if (p.error) {
       break;
     }
     path.push(p);
   }

   return path;
 }
}
TEST_HELPER_IONIC_PAGE

cat << TEST_HELPER_IONIC_SEGMENT > ./test/helpers/ionic/components/segment.ts
import { IonicComponent } from './component';

import { TapButtonOptions } from './button';
import { Ionic$ } from '..';

export class IonicSegment extends IonicComponent {
 constructor(selector: string | WebdriverIO.Element) {
   super(selector);
 }

 async button(buttonTitle: string) {
   const segmentButtons = await (await this.$).\$\$('ion-segment-button');
   for (const button of segmentButtons) {
     if (
       (await button.getText()).toLocaleLowerCase() ===
       buttonTitle.toLocaleLowerCase()
     ) {
       return new IonicSegmentButton(button);
     }
   }
   return Promise.resolve(null);
 }
}

export class IonicSegmentButton extends IonicComponent {
 async tap({
   visibilityTimeout = 5000,
   scroll = true,
 }: TapButtonOptions = {}) {
   const button = await Ionic$.\$(this.selector as string);
   await button.waitForDisplayed({ timeout: visibilityTimeout });
   if (scroll) {
     await button.scrollIntoView();
   }
   return button.click();
 }
}
TEST_HELPER_IONIC_SEGMENT

cat << TEST_HELPER_IONIC_SELECT > ./test/helpers/ionic/components/select.ts
import { pause, waitForElement } from '../..';
import { IonicComponent } from './component';

export class IonicSelect extends IonicComponent {
 constructor(selector: string) {
   super(selector);
 }

 async open() {
   await (await this.$).click();
   // Wait for the alert to popup
   return pause(1000);
 }

 async select(n: number) {
   const options = await \$\$('.select-interface-option');

   return options[n]?.click();
 }

 async cancel() {
   const cancel = await waitForElement('.alert-button-role-cancel');
   await cancel.click();
   // Allow alert to close
   return cancel.waitForDisplayed({ reverse: true });
 }

 async ok() {
   const ok = await waitForElement(
     '.alert-button:not(.alert-button-role-cancel)'
   );
   await ok.click();
   // Allow alert to close
   return ok.waitForDisplayed({ reverse: true });
 }
}
TEST_HELPER_IONIC_SELECT

cat << TEST_HELPER_IONIC_SLIDES > ./test/helpers/ionic/components/slides.ts
import type { RectReturn } from '@wdio/protocols/build/types';

import { IonicComponent } from './component';
import { Ionic$ } from '..';
import { Gestures } from '../..';

export class IonicSlides extends IonicComponent {
 rects: RectReturn | null = null;

 constructor(selector: string) {
   super(selector);
 }

 /**
  * Swipe the Swiper to the LEFT (from right to left)
  */
 async swipeLeft() {
   // Determine the rectangles of the Swiper
   const SwiperRectangles = await this.getSwiperRectangles();
   // We need to determine the center position of the Swiper on the screen. This can be done by taking the
   // starting position (SwiperRectangles.y) and add half of the height of the Swiper to it.
   const y = Math.round(SwiperRectangles.y + SwiperRectangles.height / 2);

   // Execute the gesture by providing a starting position and an end position
   return Gestures.swipe(
     // Here we start on the right of the Swiper. To make sure that we don't touch the outer most right
     // part of the screen we take 10% of the x-position. The y-position has already been determined.
     {
       x: Math.round(SwiperRectangles.width - SwiperRectangles.width * 0.1),
       y,
     },
     // Here we end on the left of the Swiper. To make sure that we don't touch the outer most left
     // part of the screen we add 10% to the x-position. The y-position has already been determined.
     { x: Math.round(SwiperRectangles.x + SwiperRectangles.width * 0.1), y }
   );
 }

 /**
  * Swipe the Swiper to the RIGHT (from left to right)
  */
 async swipeRight() {
   // Determine the rectangles of the Swiper
   const SwiperRectangles = await this.getSwiperRectangles();
   // We need to determine the center position of the Swiper on the screen. This can be done by taking the
   // starting position (SwiperRectangles.y) and add half of the height of the Swiper to it.
   const y = Math.round(SwiperRectangles.y + SwiperRectangles.height / 2);

   // Execute the gesture by providing a starting position and an end position
   return Gestures.swipe(
     // Here we start on the left of the Swiper. To make sure that we don't touch the outer most left
     // part of the screen we add 10% to the x-position. The y-position has already been determined.
     { x: Math.round(SwiperRectangles.x + SwiperRectangles.width * 0.1), y },
     // Here we end on the right of the Swiper. To make sure that we don't touch the outer most right
     // part of the screen we take 10% of the x-position. The y-position has already been determined.
     {
       x: Math.round(SwiperRectangles.width - SwiperRectangles.width * 0.1),
       y,
     }
   );
 }

 /**
  * Get the Swiper position and size
  */
 async getSwiperRectangles(): Promise<RectReturn> {
   const slides2 = await Ionic$.\$(this.selector as string);
   // Get the rectangles of the Swiper and store it in a global that will be used for a next call.
   // We dont want ask for the rectangles of the Swiper if we already know them.
   // This will save unneeded webdriver calls.
   this.rects = this.rects || (await driver.getElementRect(slides2.elementId));

   return this.rects;
 }
}
TEST_HELPER_IONIC_SLIDES

cat << TEST_HELPER_IONIC_TEXTAREA > ./test/helpers/ionic/components/textarea.ts
import { IonicComponent } from './component';

export class IonicTextarea extends IonicComponent {
 constructor(selector: string) {
   super(selector);
 }

 setValue(value: string) {
   return browser.execute(
     (selector: string, valueString: string) => {
       const el = document.querySelector(selector);
       if (el) {
         (el as any).value = valueString;
       }
     },
     this.selector,
     value
   );
 }

 getValue() {
   return browser.execute((selector: string) => {
     const el = document.querySelector(selector);
     if (el) {
       return (el as any).value;
     }
     return null;
   }, this.selector);
 }
}
TEST_HELPER_IONIC_TEXTAREA

cat << TEST_HELPER_IONIC_TOAST > ./test/helpers/ionic/components/toast.ts
import { IonicComponent } from './component';

export class IonicToast extends IonicComponent {
 constructor() {
   super('ion-toast');
 }

 getText() {
   return \$(this.selector).getText();
 }
}
TEST_HELPER_IONIC_TOAST

cat << TEST_HELPER_IONIC_INDEX > ./test/helpers/ionic/index.ts
import { IonicPage } from './components';


export class Ionic$ {
 static async \$(selector: string): Promise<WebdriverIO.Element> {
   const activePage = await IonicPage.active();
   return activePage.\$(selector);
 }

 static async \$\$(selector: string): Promise<WebdriverIO.Element[]> {
   const activePage = await IonicPage.active();
   return activePage.\$\$(selector);
 }
}

export * from './components';
TEST_HELPER_IONIC_INDEX

cat << TEST_HELPER_ANDROID > ./test/helpers/platform/android.ts
import { ElementSelector } from '../definitions';

export function findElementAndroid({ text }: ElementSelector) {
 if (text) {
   return \$(\`android=new UiSelector().text("\${text}")\`);
 } else {
   throw new Error('Unknown selector strategy');
 }
}
TEST_HELPER_ANDROID

cat << TEST_HELPER_PLATFORM_INDEX > ./test/helpers/platform/index.ts
import WebView, { CONTEXT_REF } from '../webview';

export * from './android';
export * from './ios';

export async function waitForLoad() {
 if (isWeb()) {
   return Promise.resolve();
 }
 return WebView.waitForWebsiteLoaded();
}

export async function switchToNative() {
 if (isWeb()) {
   return Promise.resolve();
 }

 return WebView.switchToContext(CONTEXT_REF.NATIVE);
}

export async function switchToWeb() {
 if (isWeb()) {
   return Promise.resolve();
 }

 return WebView.switchToContext(CONTEXT_REF.WEBVIEW);
}

export async function getContexts() {
 if (isWeb()) {
   return Promise.resolve(['WEBVIEW']);
 }

 return driver.getContexts();
}

export function getContext() {
 if (isWeb()) {
   return Promise.resolve('WEBVIEW');
 }

 return driver.getContext();
}

export async function url(newUrl: string) {
 const currentUrl = await browser.getUrl();

 if (newUrl[0] === '/') {
   // Simulate baseUrl by grabbing the current url and navigating relative
   // to that
   try {
     const fullUrl = new URL(newUrl, currentUrl);
     return browser.url(fullUrl.href);
   } catch (e) {}
 }

 return browser.url(newUrl);
}

export function pause(ms: number) {
 return driver.pause(ms);
}

export function hideKeyboard() {
 return driver.hideKeyboard();
}

export function onWeb(fn: () => Promise<void>) {
 if (isWeb()) {
   return fn();
 }
}

export function onIOS(fn: () => Promise<void>) {
 if (isIOS()) {
   return fn();
 }
}
export function onAndroid(fn: () => Promise<void>) {
 if (isAndroid()) {
   return fn();
 }
}

export function isIOS() {
 return driver.isIOS;
}

export function isAndroid() {
 return driver.isAndroid;
}

export function isWeb() {
 return !driver.isMobile;
}

export async function setLocation(lat: number, lng: number) {
 if (isWeb()) {
   // Not available on web
   return Promise.resolve();
 }

 return driver.setGeoLocation({
   latitude: '' + lat,
   longitude: '' + lat,
   altitude: '94.23',
 });
}

export async function restartApp(urlPath: string) {
 // this is needed to set the "default" url on web so the DB can be cleared
 if (isWeb()) {
   return url(urlPath);
 }
}
TEST_HELPER_PLATFORM_INDEX

cat << TEST_HELPER_IOS > ./test/helpers/platform/ios.ts
import { ElementSelector } from '../definitions';

export function findElementIOS({ text }: ElementSelector) {
 if (text) {
   return \$(
     \`-ios class chain:**/XCUIElementTypeAny[\\\`label == "\${text}" OR value == "\${text}"\\\`]\`
   );
 } else {
   throw new Error('Unknown selector strategy');
 }
}
TEST_HELPER_IOS

cat << TEST_HELPER_STORAGE > ./test/helpers/storage.ts
import { pause } from '.';

export async function clearIndexedDB(dbName: string) {
 await browser.execute((name) => {
   indexedDB.deleteDatabase(name);
   // Needed to reload the page for the DB to be reloaded
   // for mobile devices
   document.location.reload();
 }, dbName);

 return pause(500);
}
TEST_HELPER_STORAGE

cat << TEST_HELPER_WEBVIEW > ./test/helpers/webview.ts
export const CONTEXT_REF = {
 NATIVE: 'native',
 WEBVIEW: 'webview',
};
const DOCUMENT_READY_STATE = {
 COMPLETE: 'complete',
 INTERACTIVE: 'interactive',
 LOADING: 'loading',
};

class WebView {
 async waitForWebViewContextLoaded() {
   const context = await driver.waitUntil(
     async () => {
       const currentContexts = await this.getCurrentContexts();

       return (
         currentContexts.length > 1 &&
         currentContexts.find((currentContext) =>
           currentContext.toLowerCase().includes(CONTEXT_REF.WEBVIEW)
         ) !== 'undefined'
       );
     },
     {
       // Wait a max of 45 seconds. Reason for this high amount is that loading
       // a webview for iOS might take longer
       timeout: 45000,
       timeoutMsg: 'Webview context not loaded',
       interval: 100,
     }
   );

   return context;
 }

 /**
  * Switch to native or webview context
  */
 async switchToContext(context: string) {
   // The first context will always be the NATIVE_APP,
   // the second one will always be the WebdriverIO web page
   const currentContexts = await this.getCurrentContexts();
   return driver.switchContext(
     currentContexts[context === CONTEXT_REF.NATIVE ? 0 : 1]
   );
 }

 /**
  * Returns an object with the list of all available contexts
  */
 getCurrentContexts(): Promise<string[]> {
   return Promise.resolve(driver.getContexts());
 }

 /**
  * Wait for the document to be fully loaded
  */
 waitForDocumentFullyLoaded() {
   return driver.waitUntil(
     // A webpage can have multiple states, the ready state is the one we need to have.
     // This looks like the same implementation as for the w3c implementation for \`browser.url('https://webdriver.io')\`
     // That command also waits for the readiness of the page, see also the w3c specs
     // https://www.w3.org/TR/webdriver/#dfn-waiting-for-the-navigation-to-complete
     async () =>
       (await driver.execute(() => document.readyState)) ===
       DOCUMENT_READY_STATE.COMPLETE,
     {
       timeout: 15000,
       timeoutMsg: 'Website not loaded',
       interval: 100,
     }
   );
 }

 /**
  * Wait for the website in the webview to be loaded
  */
 async waitForWebsiteLoaded() {
   await this.waitForWebViewContextLoaded();
   await this.switchToContext(CONTEXT_REF.WEBVIEW);
   await this.waitForDocumentFullyLoaded();
   await this.switchToContext(CONTEXT_REF.NATIVE);
 }

 async waitForWebViewIsDisplayedByXpath(
   isShown = true
 ): Promise<boolean | void> {
   const selector = browser.isAndroid
     ? '*//android.webkit.WebView'
     : '*//XCUIElementTypeWebView';
   (await \$(selector)).waitForDisplayed({
     timeout: 45000,
     reverse: !isShown,
   });
 }
}

export default new WebView();
TEST_HELPER_WEBVIEW

cat << TEST_PAGEOBJECT_PAGE > ./test/pageobjects/page.ts
export default class Page {}
TEST_PAGEOBJECT_PAGE

cat << TEST_APP_SPEC > ./test/specs/app.e2e.spec.ts
import { clearIndexedDB, pause, restartApp, url, getUrl } from '../helpers';

describe("App Loads", () => {
  beforeEach(async () => {
    await restartApp("/");
    await clearIndexedDB("_ionicstorage");
    await url("/")
  })

  it('should load the main page', async () => {
    await expect((await getUrl()).pathname).toBe("/home")
  });
});
TEST_APP_SPEC

npx --yes npm-add-script -k "e2e:ios" -v "npx @ionic/cli cap sync ios; bundle exec fastlane ios test; TS_NODE_PROJECT=./test/tsconfig.json npx @wdio/cli test/config/wdio.ios.config.ts"
npx --yes npm-add-script -k "e2e:android" -v "npx @ionic/cli cap sync android; bundle exec fastlane android test; TS_NODE_PROJECT=./test/tsconfig.json npx @wdio/cli test/config/wdio.android.config.ts"
