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
  helpers = import ../modules/lib.nix { inherit lib; };
  profilePath = "Library/Application Support/macos-ai-purge/macos-ai-purge.mobileconfig";

  # Evaluate the module (enabled by default) with extra modules.
  evalWith =
    extraModules:
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
          programs.macosAiPurge.enable = lib.mkDefault true;
        }
      ]
      ++ extraModules;
    };
  eval = settings: evalWith [ { programs.macosAiPurge = settings; } ];
  activationOf = hm: hm.config.home.activation.macosAiPurge.data;
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

    # auto_opt_in is only written when some AI feature is off.
    testOptOutWrittenByDefault = {
      expr = (defaultsOf { })."com.apple.CloudSubscriptionFeatures.optIn".auto_opt_in or null;
      expected = false;
    };
    testOptOutOmittedWhenAllFeaturesEnabled = {
      expr =
        (defaultsOf {
          aiFeatures = lib.genAttrs (lib.attrNames catalog.features) (_: true);
        })
          ? "com.apple.CloudSubscriptionFeatures.optIn";
      expected = false;
    };

    # A bool from one module and a per-set value from another merge.
    testBlockModelDownloadsMergesAcrossModules = {
      expr =
        (evalWith [
          { programs.macosAiPurge.blockModelDownloads = true; }
          { programs.macosAiPurge.blockModelDownloads.spatial = false; }
        ]).config.programs.macosAiPurge.blockModelDownloads;
      expected = lib.genAttrs (lib.attrNames catalog.modelSets) (s: s != "spatial");
    };
    testBlockModelDownloadsFalseDisablesAll = {
      expr = (cfgOf { blockModelDownloads = false; }).blockModelDownloads;
      expected = lib.genAttrs (lib.attrNames catalog.modelSets) (_: false);
    };

    # Version gating (helper used by the module), with a dummy 27-only entry.
    testVersionGateHidesNewerEntries = {
      expr = lib.attrNames (
        helpers.available 26 {
          old = { };
          new.since = 27;
        }
      );
      expected = [ "old" ];
    };
    testVersionGateShowsEntriesOnTheirVersion = {
      expr = lib.attrNames (
        helpers.available 27 {
          old = { };
          new.since = 27;
        }
      );
      expected = [
        "new"
        "old"
      ];
    };

    # Leftover profiles are reported, also when the module is disabled.
    testMarkerCarriesIdentifier = {
      expr =
        builtins.match
          ".*<key>macosAiPurgeIdentifier</key>[[:space:]]*<string>com.afwlehmann.macos-ai-purge</string>.*"
          (profileOf { }) != null;
      expected = true;
    };
    testActivationWarnsAboutOtherProfiles = {
      expr = lib.hasInfix "old identifier" (activationOf (eval { }));
      expected = true;
    };
    testDisabledModuleWarnsAboutInstalledProfile = {
      expr = lib.hasInfix "the module is disabled" (
        activationOf (evalWith [ { programs.macosAiPurge.enable = false; } ])
      );
      expected = true;
    };
    testDisabledModuleWritesNothing = {
      expr =
        let
          hm = evalWith [ { programs.macosAiPurge.enable = false; } ];
        in
        hm.config.home.file ? ${profilePath};
      expected = false;
    };

    # Reverse-DNS identifiers only.
    testIdentifierTrailingDotRejected = {
      expr = rejected { profile.identifier = "com.example."; };
      expected = true;
    };
    testIdentifierDoubleDotRejected = {
      expr = rejected { profile.identifier = "com..example"; };
      expected = true;
    };
    testIdentifierWithDashAccepted = {
      expr = rejected { profile.identifier = "com.example.my-profile"; };
      expected = false;
    };
    testNoDoubleDotInPayloadIdentifiers = {
      expr = lib.hasInfix ".." (profileOf { });
      expected = false;
    };
  };
in
if failures == [ ] then
  pkgs.runCommand "macos-ai-purge-module-tests" { } "touch $out"
else
  throw "macos-ai-purge module tests failed:\n${lib.generators.toPretty { } failures}"
