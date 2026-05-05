<div align="center">
  <img src="assets/logo.svg" alt="Pokerly Logo" width="160" height="160">
  <h1>Pokerly</h1>
</div>

A fully offline and LAN multiplayer Texas Hold'em game built with Flutter and Riverpod. 

## Features

- **Pure Game Engine**: A deterministic Texas Hold'em engine completely decoupled from the UI.
- **Hand Evaluation**: Full hand rank support with accurate deterministic comparison.
- **Side Pots**: Robust side pot logic capable of handling multiple all-ins and tied winners.
- **Tournament Mode**: Configurable hands-per-level and automatic blind escalation.
- **Cash-Table QoL**: Support for Rebuys and Sit Out/Return to Table status (handled safely between hands to preserve fairness).
- **Bot AI**: Opponents with hand-strength evaluation and bluffing capabilities.
- **LAN Multiplayer**: Play with friends locally over WiFi (2-10 players) with host-authoritative state sync.
- **Responsive UI**: Scales from mobile phones to larger tablet/desktop windows with dynamic felt backgrounds and animations.
- **Enhanced Visability**: The local player's cards are dynamically enlarged for easier viewing.
- **Sound Effects**: Audio feedback for dealing, chips, winning, and losing.

## Architecture

This project follows a clean architecture pattern:
- `lib/models/`: Immutable domain entities (Card, Deck, Player, GameState, etc.).
- `lib/game/`: The core `PokerEngine`, `HandEvaluator`, and Riverpod `GameController`.
- `lib/services/`: AI logic, sound effects, and LAN sockets abstraction.
- `lib/ui/`: Modular screens and widgets that strictly bind to the controller's state and trigger player actions.

## Getting Started

1. Clone the repository.
2. Run `flutter pub get`.
3. Run the app: `flutter run`.

To host a LAN game, ensure your device is connected to WiFi, click "Host LAN Game", and share the generated Join Code with friends on the same network.