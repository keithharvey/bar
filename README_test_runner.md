# BAR Standalone Test Runner

A command-line test runner for BAR's unit tests that can execute tests without starting the game or Spring engine.

## Installation

Ensure you have Lua 5.1 installed:
```bash
sudo apt install lua5.1
```

## Usage

Run the test runner from the BAR repository root directory:

```bash
# Run all unit tests
lua5.1 test_runner.lua

# Run all unit tests (explicit pattern)
lua5.1 test_runner.lua unit/

# Run specific test file
lua5.1 test_runner.lua unit/test_policy_builder
lua5.1 test_runner.lua unit/test_predicates
lua5.1 test_runner.lua unit/test_resource_tax_calculations
lua5.1 test_runner.lua unit/test_unit_sharing_logic
lua5.1 test_runner.lua test_ally_assist

# Run tests matching a pattern
lua5.1 test_runner.lua predicates
lua5.1 test_runner.lua policy
```

## Features

- **Standalone Execution**: No need to start BAR or Spring engine
- **Fast Feedback**: Quick test execution for tight development loops
- **Colored Output**: Green for pass, red for fail, magenta for errors
- **Timing Information**: Shows execution time for each test
- **Pattern Matching**: Run specific tests or test groups
- **Exit Codes**: Returns 0 for success, 1 for failures (CI-friendly)

## Test Structure

Unit tests are located in `luaui/Tests/team_transfer/unit/` and follow this structure:

```lua
function setup()
    -- Test setup code (mocking, initialization)
end

function cleanup()
    -- Test cleanup code
end

function test()
    -- Test assertions and logic
end
```

## Mocking

The test runner provides mocking capabilities through BAR's testing utilities:

- `Test.mock(parent, target, fn)` - Mock a function
- `Test.spy(parent, target)` - Spy on function calls
- `VFS.Include(path)` - Mock VFS system for loading modules

## Output Example

```
BAR Standalone Test Runner
==========================
PASS: test_policy_builder.lua [2 ms]
PASS: test_predicates.lua [1 ms]
PASS: test_resource_tax_calculations.lua [3 ms]
PASS: test_unit_sharing_logic.lua [2 ms]
PASS: test_ally_assist.lua [1 ms]

Results: 6/6 tests passed
All tests passed! ✓
```

## Integration with CI

The test runner returns appropriate exit codes for CI integration:
- Exit code 0: All tests passed
- Exit code 1: One or more tests failed

## Troubleshooting

### "lua: command not found"
Install Lua 5.1: `sudo apt install lua5.1`

### "Could not open file"
Ensure you're running the command from the BAR repository root directory.

### Test failures
Check the error messages in the output. Common issues:
- Missing mock setup in test files
- Incorrect assertions
- Missing dependencies in test environment
