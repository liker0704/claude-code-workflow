# Coding Style Rules

## Immutability
- Prefer const/final declarations over mutable variables
- Avoid mutating function parameters
- Use immutable data structures where appropriate
- Make side effects explicit and minimal
- Return new values instead of modifying existing ones

## Code Size Limits
- Keep files under 500 lines of code
- Keep functions under 50 lines of code
- Split large files into focused modules
- Extract complex logic into separate functions
- Refactor when approaching size limits

## Error Handling
- Always handle errors explicitly
- Never use empty catch blocks
- Log errors with sufficient context
- Return meaningful error messages
- Use error types or codes for programmatic handling
- Fail fast on unrecoverable errors

## Naming Conventions
- Use descriptive, self-documenting names
- Follow consistent naming patterns throughout codebase
- Avoid abbreviations unless widely understood
- Use verbs for functions, nouns for variables
- Boolean variables should read as questions (isValid, hasPermission)
- Constants should be clearly distinguished (UPPER_CASE or similar)

## DRY Principle
- Don't repeat yourself - extract common logic
- Create reusable functions for repeated patterns
- Use configuration for varying behavior
- Avoid copy-paste programming
- Identify and consolidate duplicated code

## Single Responsibility
- Each function should have one clear purpose
- Each class/module should have one reason to change
- Separate concerns into distinct units
- Avoid multi-purpose utility functions
- Split complex operations into composed simple ones

## Comments
- Only comment where logic isn't self-evident
- Explain "why", not "what" (code shows what)
- Document edge cases and non-obvious behavior
- Remove outdated or misleading comments
- Prefer self-documenting code over excessive comments
- Document public APIs and interfaces

## Code Organization
- Group related functionality together
- Order code logically (dependencies before usage)
- Use consistent file and directory structure
- Keep related files close in directory hierarchy
- Separate interface from implementation

## Dependencies
- Minimize external dependencies
- Use dependency injection for testability
- Avoid circular dependencies
- Make dependencies explicit (no hidden coupling)
- Import only what you need

## Code Clarity
- Write code for humans, not just machines
- Avoid clever tricks that sacrifice readability
- Use clear control flow (avoid deeply nested logic)
- Prefer explicit over implicit behavior
- Make assumptions and constraints visible
