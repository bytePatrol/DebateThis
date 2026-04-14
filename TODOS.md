# TODOS

## Layer 1 Prerequisites

### Verify MacPaw/OpenAI custom header support for OpenRouter
- **Why:** OpenRouter requires `HTTP-Referer` and `X-Title` headers for app ranking/attribution. MacPaw/OpenAI may not pass these through, requiring a thin wrapper.
- **Context:** Check if `MacPaw/OpenAI` configuration allows custom headers on requests. If not, subclass or wrap the client. 15-minute investigation.
- **Depends on:** Nothing. Do this first.
- **Added:** 2026-04-13 via /plan-eng-review

## Pre-Ship (before distributing to other users)

### [SECURITY] Migrate API key storage from UserDefaults to Keychain
- **Why:** `@AppStorage("openRouterAPIKey")` stores the key in an unencrypted plist readable by any process running as the same user. For a shipped product, this should use Keychain.
- **Context:** `SetupView.swift:5` uses `@AppStorage`. Replace with a Keychain wrapper (e.g., KeychainAccess package or native Security framework). Requires `com.apple.security.keychain-access-groups` entitlement if sandboxed.
- **Depends on:** Nothing. Do before first public release.
- **Added:** 2026-04-13 via /cso

## Layer 2

### Migrate SystemPrompts to structured PromptLibrary
- **Why:** Once the prompt engineering sprint finds what works, prompts should be structured with version tracking and substitution variables for A/B testing.
- **Context:** Layer 1 uses hardcoded strings in `SystemPrompts.swift` for fast iteration. Layer 2 migrates to a `PromptLibrary` with typed prompt templates and substitution.
- **Depends on:** Layer 1 prompt engineering sprint must complete first.
- **Added:** 2026-04-13 via /plan-eng-review

### Add OpenRouterService unit tests
- **Why:** Service layer testing was deferred from Layer 1. Tests catch regressions in API integration (header handling, error parsing, stream decoding).
- **Context:** Core tests (state machine + prompts) ship with Layer 1. Service tests expand coverage in Layer 2 using mocked API responses.
- **Depends on:** Layer 1 must ship first (need stable service interface).
- **Added:** 2026-04-13 via /plan-eng-review
