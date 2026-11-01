# Evaluation-time tests for the module. Fails evaluation (and therefore
# `nix flake check`) with the list of failing tests.
{
  lib,
  pkgs,
  home-manager,
  module,
}:
let
  catalog = import ../modules/catalog.nix;
  profilePath = "Library/Application Support/macos-ai-purge/macos-ai-purge.mobileconfig";

  eval =
    settings:
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        module
        {
          home = {
            username = "test";
            homeDirectory = "/Users/test";
            stateVersion = "26.05";
          };
          programs.macosAiPurge = {
            enable = true;
          }
          // settings;
        }
      ];
    };
  cfgOf = settings: (eval settings).config.programs.macosAiPurge;
  defaultsOf = settings: (eval settings).config.targets.darwin.defaults;
  profileOf = settings: (eval settings).config.home.file.${profilePath}.source.text;
  hasKey = key: text: lib.hasInfix "<key>${key}</key>" text;
  rejected =
    settings:
    let
      result = builtins.tryEval (
        builtins.deepSeq (cfgOf settings) (eval settings).activationPackage.drvPath
      );
    in
    !result.success;

  allTrue = lib.genAttrs (lib.attrNames catalog.privacy) (_: true);
  recommendedOff = [
    "analytics"
    "personalized-ads"
    "siri-data-sharing"
    "search-data-sharing"
    "spotlight-web-results"
    "lookup-suggestions"
    "network-ds-store-files"
  ];
  withOff = names: allTrue // lib.genAttrs names (_: false);

  failures = lib.runTests {
    testModeAppleEqualsNull = {
      expr = (cfgOf { mode = "apple"; }).privacySettings;
      expected = (cfgOf { mode = null; }).privacySettings;
    };
    testModeAppleKeepsAppleDefaults = {
      expr = (cfgOf { mode = "apple"; }).privacySettings;
      expected = allTrue;
    };
    testModeRecommendedIsDefault = {
      expr = (cfgOf { }).privacySettings;
      expected = withOff recommendedOff;
    };
    testModePrivacyAddsSafariAndGameCenter = {
      expr = (cfgOf { mode = "privacy"; }).privacySettings;
      expected = withOff (
        recommendedOff
        ++ [
          "safari-suggestions"
          "game-center"
        ]
      );
    };
    testExplicitSettingOverridesMode = {
      expr =
        (cfgOf {
          mode = "privacy";
          privacySettings.game-center = true;
        }).privacySettings.game-center;
      expected = true;
    };

    testAiFeaturesOffByDefault = {
      expr = hasKey "allowWritingTools" (profileOf { });
      expected = true;
    };
    testEnabledAiFeatureNotRestricted = {
      expr = hasKey "allowWritingTools" (profileOf {
        aiFeatures.writing-tools = true;
      });
      expected = false;
    };
    testEnabledAiFeatureKeepsItsModels = {
      expr =
        hasKey "DownloadServerBaseURLOverride-com.apple.MobileAsset.UAF.FM.GenerativeModels"
          (profileOf {
            aiFeatures.writing-tools = true;
          });
      expected = false;
    };
    testModelsBlockedByDefault = {
      expr = map (s: hasKey "DownloadServerBaseURLOverride-${s}" (profileOf { })) (
        lib.attrValues catalog.modelSets
      );
      expected = map (_: true) (lib.attrValues catalog.modelSets);
    };
    testModelBlockingPerSet = {
      expr =
        hasKey "DownloadServerBaseURLOverride-com.apple.MobileAsset.UAF.Photos.SpatialPhotosRelive"
          (profileOf {
            blockModelDownloads.spatial = false;
          });
      expected = false;
    };
    testNoMdmOnlyKeysInProfile = {
      expr = lib.filter (
        k:
        hasKey k (profileOf {
          mode = "privacy";
        })
      ) catalog.mdmOnlyKeys;
      expected = [ ];
    };
    testLockedPrivacyItemGoesIntoProfile = {
      expr = hasKey "allowDiagnosticSubmission" (profileOf { });
      expected = true;
    };
    testLockedPrivacyItemOmittedWhenEnabled = {
      expr = hasKey "allowDiagnosticSubmission" (profileOf {
        mode = "apple";
      });
      expected = false;
    };

    testUserDefaultWrittenWhenOff = {
      expr = (defaultsOf { })."com.apple.desktopservices".DSDontWriteNetworkStores;
      expected = true;
    };
    # Home Manager declares this key itself (default null = not written).
    testUserDefaultOmittedWhenOn = {
      expr = (defaultsOf { mode = "apple"; })."com.apple.desktopservices".DSDontWriteNetworkStores;
      expected = null;
    };
    testIcloudDefaultSaveOff = {
      expr =
        (defaultsOf { privacySettings.icloud-default-save = false; })
        .NSGlobalDomain.NSDocumentSaveNewDocumentsToCloud;
      expected = false;
    };

    testUnknownPrivacySettingRejected = {
      expr = rejected { privacySettings.bogus = false; };
      expected = true;
    };
    testUnknownAiFeatureRejected = {
      expr = rejected { aiFeatures.bogus = true; };
      expected = true;
    };
    testUnknownModelSetRejected = {
      expr = rejected { blockModelDownloads.spacial = false; };
      expected = true;
    };
    testUnsupportedMacosVersionRejected = {
      expr = rejected { macosVersion = 25; };
      expected = true;
    };
    testUnknownModeRejected = {
      expr = rejected { mode = "strict"; };
      expected = true;
    };
  };
in
if failures == [ ] then
  pkgs.runCommand "macos-ai-purge-module-tests" { } "touch $out"
else
  throw "macos-ai-purge module tests failed:\n${lib.generators.toPretty { } failures}"
