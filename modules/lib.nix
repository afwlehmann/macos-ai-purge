# Pure helpers shared by the module and its tests.
{ lib }:
rec {
  # Fill in the optional fields of a catalog entry.
  normalize =
    entry:
    {
      restrictions = [ ];
      forced = { };
      prefs = { };
      modelSets = [ ];
      mode = null;
      since = 15;
    }
    // entry;

  # Catalog entries that exist on the given macOS major version.
  available =
    major: entries: lib.filterAttrs (_: e: major >= e.since) (lib.mapAttrs (_: normalize) entries);

  # Reverse-DNS identifier: dot-separated labels of letters and digits,
  # dashes only inside a label.
  identifierPattern = "[A-Za-z0-9]+(-+[A-Za-z0-9]+)*(\\.[A-Za-z0-9]+(-+[A-Za-z0-9]+)*)*";
}
