# Pong

A classic Pong game built with Godot 4.5.

## Play Now

**[Play Pong in your browser](https://gfeyer.github.io/games/pong/)**

## Controls

| Key | Action |
|-----|--------|
| Arrow Up | Move paddle up |
| Arrow Down | Move paddle down |
| Space | Start game |

## Features

- Clean, modern visual design with glow effects
- AI opponent with adjustable difficulty
- Ball speed increases with each paddle hit
- First to 10 points wins
- Fully playable in the browser (WebAssembly)

## Screenshots

The game features:
- Cyan player paddle (left)
- Pink AI paddle (right)
- Yellow glowing ball
- Dark themed background with center line

## Development

Built with [Godot Engine 4.5](https://godotengine.org/)

### Running Locally

1. Install Godot 4.5+
2. Open the project in Godot
3. Press F5 to run

### Building for Web

```bash
godot --headless --export-release "Web" "index.html"
```

## License

MIT
