# Contributing to KeyLens

Thank you for your interest in contributing!

## What we welcome

- Bug fixes
- UI/UX improvements
- Performance improvements
- Documentation fixes

For larger features or architectural changes, please **open an issue first** to discuss before writing code.

## How to build

See [docs/HowToBuild.md](docs/HowToBuild.md).

## Code style

- Swift 5.9+, macOS 13+ target
- Comments must be written in **English**
- All user-visible strings must be **bilingual (English + Japanese)** using `L10n.shared.<property>`
  Hard-coded English-only strings are not accepted
- Follow the singleton pattern used throughout the project (`KeyCountStore.shared`, etc.)

## Submitting a PR

1. Fork the repo and create a feature branch
2. Make your changes and verify the app builds: `./build.sh --install`
3. Keep the diff focused — one fix or feature per PR
4. Write a clear PR description explaining what and why

## License

By contributing, you agree that your code will be licensed under the [Apache 2.0 License](LICENSE).
