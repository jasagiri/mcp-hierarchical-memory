# Package

version       = "0.0.0"
author        = "jasagiri"
description   = "Fast hierarchical memory library for AI agents"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 1.6.0"

# Tasks

task test, "Run quick tests":
  exec "nim c --nimcache:./nimcache -r tests/test_quick.nim"

task testall, "Run all tests":
  exec "nim c --nimcache:./nimcache -r tests/test_hierarchical_memory.nim"

task testcomp, "Run comprehensive tests":
  exec "nim c --nimcache:./nimcache -r tests/test_comprehensive.nim"

task docs, "Generate documentation":
  exec "nim doc --project --index:on --out:docs src/hierarchical_memory.nim"

task example, "Run basic example":
  exec "nim c --nimcache:./nimcache -r examples/basic_usage.nim"

task benchmark, "Run performance benchmark":
  exec "nim c --nimcache:./nimcache -d:release -r examples/performance_test.nim"
