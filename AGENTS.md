# AGENTS.md

- **Layout.**
  - `flake.nix` holds the outputs: `homeModules.default` (aliased as `homeManagerModules.default`), `homeConfigurations.example-{minimal,26,27}`, `checks`, `devShells` and `formatter`.
  - `modules/ai-purge.nix` holds the module logic.
  - `docs/logo.svg` is the README logo.
  - `modules/catalog.nix` holds the data only. Keep it in sync with RemoveMacAI's `Catalog.swift` and `Tweaks.swift`.
- **Scope.** Only Apple Intelligence features and privacy tweaks. Don't port RemoveMacAI's cosmetic tweaks (Finder, Dock, typing, windows) or its service restrictions.
- **Version gates.** Express them only through `since = <macOS major>` in the catalog, and add new supported majors to the `macosVersion` enum.
- **Never put `catalog.mdmOnlyKeys` into the profile.** macOS rejects the whole profile when they are present, and an assertion enforces this.
- **Verification.**
  - Run `nix fmt`, then `nix flake check --no-build`.
  - Build both `example-26` and `example-27` profiles (`.#homeConfigurations.<name>.config.home.file."Library/Application Support/macos-ai-purge/macos-ai-purge.mobileconfig".source`) and run `plutil -lint` on them.
  - Ask before running a full `nix flake check`.
- **Hooks.** `nix develop` installs these git hooks: nixfmt, statix, deadnix, ripsecrets and convco. Commit messages must follow Conventional Commits.
- **Keep the README in sync** with the module options. Its "Complete Option Reference" block must list every option and every catalog ID with its default value. Whenever `modules/catalog.nix` changes, also update the README's "Conflicting Settings" tables, checked against nix-darwin's `modules/system/defaults/*.nix`.
