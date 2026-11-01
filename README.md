# NimbusBridge

> **Status: Early development / Proof of Concept**

NimbusBridge is an open-source project exploring a compatibility bridge between the SteelSeries Nimbus+ controller and games on macOS that do not currently handle the controller as expected.

## The problem

The SteelSeries Nimbus+ works with Apple's Game Controller framework, but controller support varies between macOS games. Some titles expect a different input layout or device representation, which can make the controller unavailable or incorrectly mapped in-game.

## Planned solution

NimbusBridge aims to:

- detect and read input from a connected Nimbus+ controller;
- provide configurable button and axis mappings;
- translate the physical controller state into a compatible virtual controller output; and
- validate the result with games that currently have compatibility issues.

## Current state

The project is in early development and should be treated as a proof of concept. A reliable end-to-end controller bridge is not available yet, and compatibility with specific games has not been validated.

The source code will be published once a working version is ready. Until then, this repository serves as a public description of the problem, direction, and project status.

## License

NimbusBridge is intended to be released under the [MIT License](LICENSE).

