# Contributing to Expandable Animation

Thanks for helping improve `expandable_animation`.

## Development setup

```bash
git clone https://github.com/boffincoders/expandable_animation.git
cd expandable_animation
./scripts/setup.sh
```

You need the Flutter SDK (stable channel). The minimum supported version is
listed in `pubspec.yaml`.

## Before opening a pull request

Run the same checks as CI:

```bash
./scripts/ci.sh
```

Useful subsets:

```bash
./scripts/ci.sh --test       # format, analyze and tests
./scripts/ci.sh --coverage   # tests with coverage report
./scripts/ci.sh --web        # build the web demo
./scripts/ci.sh --help
```

On Windows, run the scripts from Git Bash or WSL, or run the underlying
commands directly: `dart format --set-exit-if-changed .`, `flutter analyze`,
`flutter test` and `dart pub publish --dry-run`.

## Guidelines

- Keep the public API small and documented. Every public member needs a doc
  comment with an example where useful.
- Add or update tests with every behavior change. Golden tests are tagged
  `golden`; regenerate them on macOS with
  `flutter test --tags golden --update-goldens`.
- Update `README.md`, `CHANGELOG.md` and the example app when behavior
  changes.
- Use [Conventional Commits](https://www.conventionalcommits.org/), for
  example `feat: add horizontal dismissal` or `fix: keep source hidden while
  collapsing`.
- Do not add runtime dependencies without discussing it in an issue first.

## Reporting bugs and requesting features

Use the issue templates. For bugs, include the Flutter version
(`flutter --version`), the platform and a minimal reproduction.
