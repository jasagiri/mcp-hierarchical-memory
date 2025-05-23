# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains both a Rust MCP server and a Nim library implementation of hierarchical memory management for AI agents:

- **vendor/rust-hierarchical-memory**: MCP server implementation for Claude Desktop integration
- **Nim Library**: High-performance standalone library optimized for speed

Both implementations provide 3-tier memory management (short-term, medium-term, long-term) with tree-structured organization, tagging, persistence, and access tracking.

## Commands

### Rust MCP Server
```bash
cd vendor/rust-hierarchical-memory
cargo build --release
cargo run --release
cargo test
```

### Nim Library
```bash
# Build library
nim c src/hierarchical_memory.nim

# Run tests
nim c -r tests/test_hierarchical_memory.nim

# Run examples
nim c -r examples/basic_usage.nim
nim c -d:release -r examples/performance_test.nim

# Install as package
nimble install
```

### Environment Configuration
- Rust: Set data directory with `MCP_MEMORY_DATA_DIR=/path/to/data`
- Nim: Pass data directory to `newHierarchicalMemory(dataDir)`

## Architecture

### Rust MCP Server Components
- `vendor/rust-hierarchical-memory/src/main.rs` - Entry point, initializes logging and data directory
- `vendor/rust-hierarchical-memory/src/memory.rs` - Core hierarchical memory implementation
- `vendor/rust-hierarchical-memory/src/server.rs` - MCP server implementation
- `vendor/rust-hierarchical-memory/src/lib.rs` - Library exports

### Nim Library Components  
- `src/hierarchical_memory.nim` - Complete standalone library implementation
- `tests/test_hierarchical_memory.nim` - Comprehensive test suite
- `examples/basic_usage.nim` - Usage demonstration
- `examples/performance_test.nim` - Performance benchmarking

### Memory System
- **3-tier hierarchy**: ShortTerm, MediumTerm, LongTerm memory levels
- **Tree structure**: Parent-child relationships via `parent_id` and `children` fields
- **Persistence**: JSON storage in configurable data directory
- **Access tracking**: `last_accessed` timestamp and `access_count` for each memory entry
- **Thread safety**: Arc<Mutex<>> wrapper for shared memory access

### MCP Integration
- Implements standard MCP tools for memory operations (add, get, update, delete, search)
- Provides resource endpoints: `memory://hierarchical/{all,short_term,medium_term,long_term}`
- Tools include hierarchy navigation (`get_children`, `get_roots`) and content search

### Dependencies

**Rust Implementation:**
- `mcp-rust-sdk` - MCP protocol implementation (local path dependency)
- `serde/serde_json` - Serialization for persistence
- `chrono` - Timestamp handling
- `uuid` - Unique ID generation
- `tokio` - Async runtime

**Nim Implementation:**
- Standard library only (tables, json, times, strutils, options, locks)
- No external dependencies for maximum performance
- Thread-safe operations with built-in locks

### Data Model
Each `MemoryEntry` contains:
- Unique identifier (UUID in Rust, timestamp+counter in Nim)
- Content string and memory level
- Tag list for categorization
- Creation and access timestamps
- Parent/children IDs for hierarchy
- Access count for usage tracking

### Performance Characteristics
- **Nim Library**: ~137 insertions/second, ~50 searches/second (optimized for speed)
- **Rust MCP Server**: Network overhead, but provides standard MCP interface
- Both use O(1) hash table lookups and JSON persistence