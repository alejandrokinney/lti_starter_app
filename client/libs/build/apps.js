const fs = require('fs-extra');
const _ = require('lodash');
const path = require('path');

const settings = require('../../config/settings');
const build = require('./index');

let launchPort = parseInt(settings.hotPort, 10);

// -----------------------------------------------------------------------------
// Root of the build directory where apps will be written
// -----------------------------------------------------------------------------
function rootBuildPath(stage) {
  return stage === 'production' ? settings.prodOutput : settings.devOutput;
}

// -----------------------------------------------------------------------------
// Generates webpack options that can be provided to webpackConfigBuilder
// -----------------------------------------------------------------------------
function buildWebpackOptions(appName, appPath, options) {
  return {
    stage: options.stage,
    appName,
    appPath,
    buildSuffix: settings.buildSuffix,
    prodOutput: options.onlyPack ? settings.prodOutput : path.join(settings.prodOutput, appName),
    prodAssetsUrl: settings.prodAssetsUrl,
    prodRelativeOutput: settings.prodRelativeOutput,
    devOutput: options.onlyPack ? settings.devOutput : path.join(settings.devOutput, appName),
    devAssetsUrl: settings.devAssetsUrl,
    devRelativeOutput: settings.devRelativeOutput
  };
}

// -----------------------------------------------------------------------------
// Iterate through all applications calling the callback with the webpackOptions
// -----------------------------------------------------------------------------
function iterateApps(options, cb) {
  _.each(settings.apps, (appPath, appName) => {
    cb(buildWebpackOptions(appName, appPath, options));
  });
}

// -----------------------------------------------------------------------------
// Wrapper to provide values for launching a webpack server
// -----------------------------------------------------------------------------
function launchHotWrapper(launchCallback, webpackOptions) {
  const servePath = path.join(settings.devOutput, webpackOptions.appName);
  launchCallback(webpackOptions, launchPort, servePath);
  launchPort += 1;
}

// -----------------------------------------------------------------------------
// Build a single app
// -----------------------------------------------------------------------------
function buildAppParts(webpackOptions, onlyPack) {
  if (onlyPack) {
    build.buildWebpackEntries(webpackOptions).then(() => {
      console.log(`Finished Javascript for ${webpackOptions.appName}`);
    });
  } else {
    const outputPath = rootBuildPath(webpackOptions.stage);
    build.build(outputPath, webpackOptions, settings.htmlOptions).then((result) => {
      console.log(`Finished Javascript for ${webpackOptions.appName}.`);
      console.log(`Built ${result.pages.length} pages.`);
    });
  }
}

// -----------------------------------------------------------------------------
// Build a single app
// -----------------------------------------------------------------------------
function buildApp(appName, options, launchCallback) {
  const appPath = _.find(settings.apps, (p, name) => appName === name);
  const webpackOptions = buildWebpackOptions(appName, appPath, options);
  buildAppParts(webpackOptions, options.onlyPack);
  if (launchCallback) {
    launchHotWrapper(launchCallback, webpackOptions);
  }
}

// -----------------------------------------------------------------------------
// Build all apps
// -----------------------------------------------------------------------------
function buildApps(options, launchCallback) {
  // Delete everything in the output path
  fs.emptydir(rootBuildPath(options.stage), () => {
    iterateApps(options, (webpackOptions) => {
      buildAppParts(webpackOptions, options.onlyPack);
      if (launchCallback) {
        launchHotWrapper(launchCallback, webpackOptions);
      }
    });
  });
}

module.exports = {
  buildApp,
  buildApps,
  buildWebpackOptions
};
