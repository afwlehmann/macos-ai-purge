# Data ported from RemoveMacAI 1.2.0-beta.1 (Sources/removemacai/Catalog.swift,
# Tweaks.swift). `since` is the minimum macOS major version; everything that
# RemoveMacAI gates on 15.x collapses to 15 because this module targets 26+.
{
  # Model set name -> MobileAsset asset type (Catalog.swift:43-57).
  modelSets = {
    foundation = "com.apple.MobileAsset.UAF.FM.GenerativeModels";
    visual = "com.apple.MobileAsset.UAF.FM.Visual";
    spatial = "com.apple.MobileAsset.UAF.Photos.SpatialPhotosRelive";
    cleanup = "com.apple.MobileAsset.UAF.Photos.MagicCleanup";
    code = "com.apple.MobileAsset.UAF.FM.CodeLM";
  };

  # Apple Intelligence features (Catalog.swift:59-123); each entry holds the
  # changes that turn the feature off. All switches are
  # profile-only: `restrictions` go to com.apple.applicationaccess (= false),
  # `forced` to com.apple.ManagedClient.preferences.
  features = {
    siri = {
      restrictions = [ "allowAssistant" ];
      forced = {
        "com.apple.assistant.support"."Assistant Enabled" = false;
        "com.apple.Siri" = {
          StatusMenuVisible = false;
          VoiceTriggerUserEnabled = false;
        };
      };
      modelSets = [ "foundation" ];
    };
    chatgpt.restrictions = [
      "allowExternalIntelligenceIntegrations"
      "allowExternalIntelligenceIntegrationsSignIn"
    ];
    writing-tools = {
      restrictions = [ "allowWritingTools" ];
      modelSets = [ "foundation" ];
    };
    genmoji = {
      restrictions = [ "allowGenmoji" ];
      modelSets = [
        "foundation"
        "visual"
      ];
    };
    image-playground = {
      restrictions = [ "allowImagePlayground" ];
      modelSets = [
        "foundation"
        "visual"
      ];
    };
    mail = {
      restrictions = [
        "allowMailSummary"
        "allowMailSmartReplies"
      ];
      forced."group.com.apple.mail" = {
        DisableAutomaticMessageSummarization = true;
        PersonalizedSmartReplies = false;
      };
      modelSets = [ "foundation" ];
    };
    notification-summaries = {
      forced."group.com.apple.usernoted".summarize_previews = false;
      modelSets = [ "foundation" ];
    };
    messages-summaries = {
      forced."com.apple.MobileSMS".messageSummarizationEnabled = false;
      modelSets = [ "foundation" ];
    };
    safari-summaries = {
      restrictions = [ "allowSafariSummary" ];
      modelSets = [ "foundation" ];
    };
    notes-summaries = {
      restrictions = [ "allowNotesTranscriptionSummary" ];
      modelSets = [ "foundation" ];
    };
    inline-predictions.forced.".GlobalPreferences".NSAutomaticInlinePredictionEnabled = false;
    spatial-photos = {
      forced."com.apple.spatialphotosrelive".LocallyDisabled = true;
      modelSets = [ "spatial" ];
      since = 26;
    };
    # No switch: only turned off by blocking/removing the models.
    photos-clean-up.modelSets = [ "cleanup" ];
    xcode-completion.modelSets = [ "code" ];
  };

  # Privacy-relevant macOS behaviours (Tweaks.swift:149-356), named after the
  # behaviour itself; each entry holds the changes that turn it off.
  # `restrictions`/`forced` are profile-only, `prefs` are plain user defaults.
  # `mode` is the smallest mode (RemoveMacAI preset) that turns it off
  # (privacy = recommended + privacy-only). RemoveMacAI IDs: siri-data-sharing = improve-siri,
  # search-data-sharing = improve-search, spotlight-web-results = spotlight-web,
  # network-ds-store-files = network-ds-store, icloud-default-save = save-locally.
  # RemoveMacAI's cosmetic tweaks (Finder, Dock, typing, windows) and its
  # service restrictions (iPhone Mirroring, Music, Book Store) are out of scope.
  privacy = {
    analytics = {
      restrictions = [ "allowDiagnosticSubmission" ];
      mode = "recommended";
    };
    personalized-ads = {
      restrictions = [ "allowApplePersonalizedAdvertising" ];
      mode = "recommended";
    };
    siri-data-sharing = {
      forced."com.apple.assistant.support"."Siri Data Sharing Opt-In Status" = 2;
      mode = "recommended";
    };
    search-data-sharing = {
      forced."com.apple.assistant.support"."Search Queries Data Sharing Status" = 2;
      mode = "recommended";
    };
    spotlight-web-results = {
      restrictions = [ "allowSpotlightInternetResults" ];
      mode = "recommended";
    };
    lookup-suggestions = {
      forced."com.apple.lookup.shared".LookupSuggestionsDisabled = true;
      mode = "recommended";
    };
    safari-suggestions = {
      forced."com.apple.Safari" = {
        UniversalSearchEnabled = false;
        SuppressSearchSuggestions = true;
      };
      mode = "privacy";
    };
    game-center = {
      restrictions = [ "allowGameCenter" ];
      mode = "privacy";
    };
    network-ds-store-files = {
      prefs."com.apple.desktopservices".DSDontWriteNetworkStores = true;
      mode = "recommended";
    };
    icloud-default-save.prefs.NSGlobalDomain.NSDocumentSaveNewDocumentsToCloud = false;
  };

  # Restriction keys that are MDM-only; macOS rejects the whole profile when a
  # user-approved profile contains them (SelfTest.swift:279-288).
  mdmOnlyKeys = [
    "allowedExternalIntelligenceWorkspaceIDs"
    "allowRosettaUsageAwareness"
    "allowSafariHistoryClearing"
    "allowSafariPrivateBrowsing"
    "forceBypassScreenCaptureAlert"
  ];
}
