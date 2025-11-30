# Demel

Demel is a command-line tool for scrobbling music to ListenBrainz. It uses Google's Gemini API to parse natural language inputs, allowing you to log listens by describing them rather than searching for exact metadata manually.

It integrates with MusicBrainz to ensure accurate metadata and ListenBrainz for the actual scrobbling.

## Features

- **Natural Language Processing**: Describe what you're listening to naturally
- **AI-Powered Intent Parsing**: Gemini understands vague queries and artist names
- **Smart Album Prioritization**: Automatically favors original albums over compilations
- **Full Album Scrobbling**: Scrobble entire albums with proper track timing
- **Statistics & Analytics**: Track your top artists, albums, and tracks
- **Cover Art Support**: Fetch and display album artwork
- **Intelligent Caching**: Reduce API calls with 24-hour search cache
- **Retry Logic**: Exponential backoff for failed network requests
- **Export Capabilities**: Export your listening stats to CSV

## Requirements

*   Lua 5.1 or higher (Lua 5.4 recommended)
*   `lua-cjson` library
*   `curl`
*   A ListenBrainz User Token
*   A Google Gemini API Key

## Installation

1.  Clone the repository.
2.  Install the dependencies. On Debian/Ubuntu:
    ```bash
    sudo apt install lua5.4 lua-cjson curl
    ```
3.  Create a `.env` file in the project root:
    ```bash
    touch .env
    ```
4.  Add your API keys to the `.env` file:
    ```
    GEMINI_API_KEY=your_gemini_key_here
    LISTENBRAINZ_TOKEN=your_listenbrainz_token_here
    ```

## Usage

Run the application using the wrapper script:

```bash
./demel
```

Or directly with Lua:

```bash
lua main.lua
```

### Command Line Options

```bash
demel --help              # Show help and usage
demel --version           # Show version information
demel --stats             # Display your listening statistics
demel --export stats.csv  # Export stats to CSV
demel --clear-cache       # Clear the MusicBrainz search cache
demel --debug             # Enable debug logging
```

### Interactive Commands

Once the application is running, you can type natural language descriptions of what you are listening to.

Examples:
*   "Listening to Purple Rain by Prince"
*   "I'm listening to the album Lust for Life by Iggy Pop"
*   "Scrobble track 3 from the album Unknown Pleasures"
*   "barracuda" (AI will figure out it's Heart)
*   "10.000 by NIN" (AI corrects to "10,000 Days")

## How It Works

1. **Input Parsing**: Gemini AI interprets your natural language query
2. **MusicBrainz Search**: Finds matching tracks/albums with smart prioritization
3. **Smart Selection**: AI helps disambiguate when multiple matches exist
4. **Scrobbling**: Submits to ListenBrainz with accurate timestamps
5. **Statistics**: Tracks your listening habits locally

## Contributing

Contributions are welcome! Please check out our [Contributing Guide](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md).

## License

MIT License - see [LICENSE](LICENSE) for details.

The application will:
1.  Interpret your intent using Gemini.
2.  Search MusicBrainz for the correct release (prioritizing original studio albums).
3.  Ask you to confirm the correct match.
4.  Submit the listen to ListenBrainz.

To exit, type `exit` or `quit`.

## Configuration

The application prioritizes original studio albums over compilations, live albums, or remixes when searching. If the initial search doesn't find what you want, you can refine the search by typing a correction when prompted (e.g., "No, I meant the live version").
