# Package

version       = "0.0.0"
author        = "jasagiri"
description   = "A2A Protocol SDK for Nim"
license       = "Apache-2.0"
srcDir        = "src"
installExt    = @["nim"]

# Dependencies

requires "nim >= 1.6.0"
requires "jester >= 0.5.0"  # HTTP server
requires "jsony >= 1.1.3"   # JSON serialization
requires "chronicles >= 0.10.0"  # Logging
requires "asynctools >= 0.1.1"  # Async utilities
requires "taskpools >= 0.0.3"   # Thread pools for task management

# Main Tests

task test, "Run the complete organized test suite":
  exec "nim c -r tests/test_runner.nim"

# Tests by Category

task test_core, "Run core functionality tests":
  exec "nim c -r tests/types/test_basic_types.nim"
  exec "nim c -r tests/types/test_json_serialization.nim"

task test_auth, "Run authentication tests":
  exec "nim c -r tests/auth/test_oauth_auth.nim"
  exec "nim c -r tests/auth/test_api_key_auth.nim"
  exec "nim c -r tests/auth/test_middleware.nim"

task test_client, "Run client tests":
  exec "nim c -r tests/client/test_client.nim"
  exec "nim c -r tests/client/test_a2a_client.nim"
  exec "nim c -r tests/client/test_http_client.nim"

task test_server, "Run server tests":
  exec "nim c -r tests/server/test_server.nim"
  exec "nim c -r tests/server/test_server_components.nim"

task test_file, "Run file handling tests":
  exec "nim c -r tests/test_file_handler.nim"
  exec "nim c -r tests/file_storage/test_storage.nim"

task test_performance, "Run performance tests":
  exec "nim c -r tests/performance/test_connection_pool.nim"
  exec "nim c -r tests/performance/test_object_pool.nim"

# Integration Tests

task test_integration, "Run integration tests":
  exec "nim c -r tests/integration/test_client_server.nim"

# Coverage Tests

task test_coverage, "Run comprehensive coverage verification":
  exec "nim c -r tests/coverage/test_comprehensive.nim"

# Development Utilities

task test_quick, "Run quick test subset for development":
  exec "nim c -r tests/types/test_basic_types.nim"
  exec "nim c -r tests/client/test_client.nim"

task test_debug, "Run tests with debug output":
  exec "nim c -d:debug --verbosity:2 -r tests/test_runner.nim"

task test_release, "Run tests in release mode":
  exec "nim c -d:release --opt:speed -r tests/test_runner.nim"

# Documentation and Maintenance

task docs, "Generate documentation":
  exec "nim doc --project --index:on --outdir:docs src/a2a.nim"

task format, "Format code using nimpretty":
  echo "Formatting source code..."
  exec "find src -name \"*.nim\" -exec nimpretty {} \\;"
  echo "Source code formatting completed."

task lint, "Lint code using nim check":
  echo "Linting source code..."
  exec "find src -name \"*.nim\" -exec nim check {} \\;"
  echo "Source code linting completed."

# Examples

task server_example, "Run the server example":
  exec "nim c -r examples/server/simple_server.nim"

task client_example, "Run the client example":
  exec "nim c -r examples/client/simple_client.nim"

task all_examples, "Run all examples":
  echo "Running all examples..."
  exec "nimble server_example"
  exec "nimble client_example"
  echo "All examples completed."
