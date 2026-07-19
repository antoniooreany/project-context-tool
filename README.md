# Project Context Tool

Project Context Tool is a universal context generator for AI agents and humans.

It scans any repository, builds a raw project model, detects likely stacks and frameworks with confidence scores, generates concise LLM-oriented context, and exports a full-text archive of project files with real paths.

## Core goals

- Be stack-agnostic by default.
- Build raw structure first, then derive all other artifacts from it.
- Support extensibility through contracts, registries, and plugins.
- Always report candidate confidence percentages and overall detection confidence.
- Refresh generated artifacts on change, staleness, triggers, or AI question preflight.
