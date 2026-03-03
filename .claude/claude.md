## xclaude-plugin: Why and When to Use These Tools

The xclaude-plugin provides 8 modular MCPs with 24 specialized iOS tools. **Always prefer these over raw `xcodebuild` or shell commands** for iOS development tasks. Here's why:

### Why These Tools Trump Raw Commands

| Task                 | Direct Bash                                                    | xclaude-plugin                   | Why Plugin Wins                                                           |
| -------------------- | -------------------------------------------------------------- | -------------------------------- | ------------------------------------------------------------------------- |
| Build + get errors   | `xcodebuild -scheme Foo 2>&1` (50+ lines of parsing)           | `xcode_build` tool               | Auto-extracts up to 10 errors, structured JSON, 87% fewer tokens          |
| Test suite execution | `xcodebuild test` + manual parsing                             | `xcode_test` tool                | Parses results, reports failures, timing, code coverage                   |
| Simulator screenshot | `xcrun simctl io booted screenshot /tmp/x.png` + file handling | `simulator_screenshot` tool      | Auto-saves, encoded output, accessible in response                        |
| UI automation        | Manual coordinate finding + shell taps                         | `idb_describe` + `idb_tap` tools | Queries accessibility tree (120ms), semantic element finding, 3-4x faster |
| App installation     | `xcrun simctl install booted App.app`                          | `simulator_install_app` tool     | Builds, finds app, installs, validates—one command                        |

### When to Use Each MCP

**Use `xc-build`** (~600 tokens) when:

- Building and fixing errors
- Need to clean build artifacts
- Discovering schemes/targets in project
- Build validation and configuration

**Use `xc-launch`** (~400 tokens) when:

- Installing and launching an app on the simulator

**Use `xc-interact`** (~900 tokens) when:

- Testing UI flows with app already built
- Automating screen validation without code changes
- Need accessibility-first element querying

**Use `xc-ai-assist`** (~1400 tokens) when:

- Iterating on UI with live feedback (code change → screenshot)
- Need visual validation of changes
- Combining code modification with testing

**Use `xc-testing`** (~1200 tokens) when:

- Running test suites and analyzing results
- Need both unit tests and UI automation
- Debugging test failures

**Use `xc-setup`** (~800 tokens) when:

- First-time environment validation
- Checking Xcode/simulator health
- Discovering project structure (schemes, targets)

**Use `xc-meta`** (~700 tokens) when:

- Maintenance tasks (clearing derived data, managing simulators)
- Non-coding iOS project operations
- Environment housekeeping

**Use `xc-all`** (~3500 tokens) when:

- Complex workflows requiring multiple tool categories
- Don't know which single MCP fits the task
- Need flexibility to pivot between workflows

### Critical: Prefer Plugin Tools Over Bash

When you encounter a task that could use either approach, **always choose the plugin tool**.

**Don't do this:**


# Manual build parsing
> `xcodebuild -scheme MyApp 2>&1 | grep -A5 "error:" | sed ...`


**Do this instead:** Use the `xcode_build` tool from `xc-build` MCP.

---

**Don't do this:**


# Manual screenshot saving
> `xcrun simctl io booted screenshot /tmp/screenshot.png`
> `cat /tmp/screenshot.png | base64`


**Do this instead:** Use the `simulator_screenshot` tool from `xc-interact` MCP.

---

**Don't do this:**


# Finding UI elements by trial and error
> `xcrun simctl spawn booted launchctl list | grep bundleid`


**Do this instead:** Use `idb_describe` tool to query accessibility tree, then `idb_tap` to interact.

### When Bash IS Still Appropriate

Use Bash for tasks outside iOS development:

- File operations: `mkdir`, `cp`, `rm`, `ls`
- Version control: `git status`, `git diff`, `git commit`
- General scripting: `jq`, `sed`, `awk`
- Environment setup: `npm install`, `brew install`

**Never use Bash for iOS-specific tasks** when a plugin tool exists.