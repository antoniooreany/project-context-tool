# Conversation

## Purpose

This file stores a manually curated summary of the planning conversation used to bootstrap the repository and generate exports.

## Summary

- The repository must be English-only.
- The tool must be universal and not tied to a single framework.
- The tool must build a raw project structure first.
- All downstream artifacts must derive from the raw model.
- Detection must log candidate confidence percentages and overall confidence.
- Unknown stacks must still be supported through fallback analyzers.
- Extensibility must apply to contracts, analyzers, detectors, builders, fixtures, triggers, serializers, hooks, and profiles.
- The repository must support local exports and GitHub automation.

## Initial backlog themes

1. Raw model scanner
2. Detection pipeline
3. Confidence model
4. Plugin and contract registries
5. Output builders
6. Refresh policy
7. English-only governance
8. GitHub automation
