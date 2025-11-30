# Contributing to Demel

Thanks for your interest in contributing to Demel! We welcome contributions from everyone.

## How to Contribute

### Reporting Bugs
- Open an issue on GitHub.
- Describe the bug in detail.
- Include steps to reproduce the bug.
- Mention your OS and Lua version.

### Suggesting Enhancements
- Open an issue on GitHub.
- Describe the enhancement in detail.
- Explain why this enhancement would be useful.

### Pull Requests
1. Fork the repository.
2. Create a new branch for your feature or bug fix.
3. Make your changes.
4. Run the syntax check: `find . -name "*.lua" -exec lua5.4 -p {} +`
5. Submit a pull request.

## Code Style
- Use 2 spaces for indentation.
- Keep code clean and readable.
- Add comments where necessary.

## Adding New Modules
If you want to add a new scrobbling source or API integration:
1. Create a new file in `src/`.
2. Follow the pattern in `src/listenbrainz.lua` or `src/musicbrainz.lua`.
3. Expose the necessary functions in `main.lua`.
