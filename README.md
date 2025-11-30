# Demel

Demel is a command-line tool for scrobbling music to ListenBrainz. It uses Google's Gemini API to parse natural language inputs, allowing you to log listens by describing them rather than searching for exact metadata manually.

It integrates with MusicBrainz to ensure accurate metadata and ListenBrainz for the actual scrobbling.

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

### Commands

Once the application is running, you can type natural language descriptions of what you are listening to.

Examples:
*   "Listening to Purple Rain by Prince"
*   "I'm listening to the album Lust for Life by Iggy Pop"
*   "Scrobble track 3 from the album Unknown Pleasures"

The application will:
1.  Interpret your intent using Gemini.
2.  Search MusicBrainz for the correct release (prioritizing original studio albums).
3.  Ask you to confirm the correct match.
4.  Submit the listen to ListenBrainz.

To exit, type `exit` or `quit`.

## Configuration

The application prioritizes original studio albums over compilations, live albums, or remixes when searching. If the initial search doesn't find what you want, you can refine the search by typing a correction when prompted (e.g., "No, I meant the live version").
