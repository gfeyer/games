# Asteroids

A classic Asteroids arcade game built with Godot 4.5.

## Play Now

**[Play Asteroids in your browser](https://gfeyer.github.io/games/asteroids/docs/)**

## Controls

| Key | Action |
|-----|--------|
| W / Arrow Up | Thrust forward |
| A / Arrow Left | Rotate left |
| D / Arrow Right | Rotate right |
| Space | Shoot |

## Features

- Classic arcade-style gameplay
- Progressive wave system with increasing difficulty
- Asteroids split into smaller pieces when destroyed
- Screen wrapping for ship and asteroids
- Particle effects for thrust and explosions
- Score tracking and lives system
- Fully playable in the browser (WebAssembly)

## Gameplay

- Destroy all asteroids to advance to the next wave
- Large asteroids split into medium, medium into small
- Avoid colliding with asteroids
- Brief invincibility after respawning

## Development

Built with [Godot Engine 4.5](https://godotengine.org/)

### Running Locally

1. Install Godot 4.5+
2. Open the project in Godot
3. Press F5 to run

### Building for Web

```bash
godot --headless --export-release "Web" "docs/index.html"
```

## License

MIT
