# Hierarchical Memory Library for Nim

A high-performance hierarchical memory management library for AI agents, implemented in Nim. This library provides a 3-tier memory system with tree-structured organization, tag-based search, and persistent storage.

## Features

### Core Functionality
- **3-Tier Memory Hierarchy**: ShortTerm, MediumTerm, and LongTerm memory levels
- **Tree Structure**: Parent-child relationships for hierarchical organization
- **Access Tracking**: Automatic usage analytics and timestamps
- **Thread-Safe**: Lock-based concurrency protection
- **JSON Persistence**: Automatic save/load from disk
- **Fast Operations**: Optimized for speed with Table-based storage

### Advanced Search
- **Tag-based Search**: Both AND and OR operations for flexible categorization
- **Content Search**: Case-insensitive text search and regex pattern matching
- **Date Range Filtering**: Search memories by creation date
- **Usage Analytics**: Find most accessed and recently accessed memories
- **Level Filtering**: Filter by memory hierarchy level

### Enhanced Safety
- **Result Types**: Safe error handling with `MemoryResult[T]`
- **Input Validation**: Content length, tag validation, and character restrictions
- **Circular Dependency Prevention**: Automatic detection of hierarchy cycles
- **Rollback Support**: Automatic rollback on save failures
- **Comprehensive Error Handling**: Detailed error messages and recovery

### Configuration & Environment
- **Configurable Limits**: Content length, tag count, and tag length limits
- **Environment Variables**: Support for `MEMORY_DATA_DIR` configuration
- **UUID Generation**: Unique identifiers with collision prevention

## Installation

Clone and install locally:
```bash
git clone <repository>
cd hierarchical-memory
nimble install
```

Or add to your `.nimble` file:
```nimble
requires "https://github.com/yourusername/hierarchical-memory"
```

## Quick Start

```nim
import hierarchical_memory

# Create memory instance
let memory = newHierarchicalMemory("./data")

# Add memories
let projectId = memory.add("Important project", LongTerm, @["work", "project"])
let taskId = memory.add("Daily standup", ShortTerm, @["work", "meeting"], some(projectId))

# Retrieve memory
let retrieved = memory.get(projectId)
if retrieved.isSome:
  echo retrieved.get.content

# Search by tags
let workMemories = memory.searchByTags(@["work"])

# Search by content
let meetings = memory.searchByContent("meeting")

# Get children
let children = memory.getChildren(projectId)
```

## API Reference

### Types

```nim
type
  MemoryLevel = enum
    ShortTerm = "short_term"
    MediumTerm = "medium_term"  
    LongTerm = "long_term"

  MemoryEntry = object
    id: string              # UUID identifier
    content: string         # Memory content
    level: MemoryLevel      # Memory tier
    tags: seq[string]       # Category tags
    createdAt: DateTime     # Creation timestamp
    lastAccessed: DateTime  # Last access time
    accessCount: uint32     # Access frequency
    parentId: Option[string] # Parent memory ID
    children: seq[string]   # Child memory IDs
```

### Core Operations

#### Creation
```nim
proc newHierarchicalMemory(dataDir: string = "./data"): HierarchicalMemory
```

#### Memory Management
```nim
proc add(memory: HierarchicalMemory, content: string, level: MemoryLevel, 
         tags: seq[string] = @[], parentId: Option[string] = none(string)): string

proc get(memory: HierarchicalMemory, id: string): Option[MemoryEntry]

proc update(memory: HierarchicalMemory, id: string, 
           content: Option[string] = none(string),
           level: Option[MemoryLevel] = none(MemoryLevel),
           tags: Option[seq[string]] = none(seq[string])): bool

proc delete(memory: HierarchicalMemory, id: string): bool
```

#### Search Operations
```nim
proc searchByTags(memory: HierarchicalMemory, tags: seq[string]): seq[MemoryEntry]
proc searchByTagsOr(memory: HierarchicalMemory, tags: seq[string]): seq[MemoryEntry]
proc searchByContent(memory: HierarchicalMemory, query: string): seq[MemoryEntry]
proc searchByContentRegex(memory: HierarchicalMemory, pattern: string): MemoryResult[seq[MemoryEntry]]
proc getByLevel(memory: HierarchicalMemory, level: MemoryLevel): seq[MemoryEntry]
proc getByDateRange(memory: HierarchicalMemory, startDate: DateTime, endDate: DateTime): seq[MemoryEntry]
```

#### Analytics Operations
```nim
proc getMostAccessed(memory: HierarchicalMemory, limit: int = 10): seq[MemoryEntry]
proc getRecentlyAccessed(memory: HierarchicalMemory, limit: int = 10): seq[MemoryEntry]
proc getMemoryStats(memory: HierarchicalMemory): Table[string, int]
```

#### Safe Operations (with Result types)
```nim
proc newHierarchicalMemoryWithConfig(dataDir: string = "", maxContentLength: int = 10000, 
                                   maxTagLength: int = 50, maxTagCount: int = 20): MemoryResult[HierarchicalMemory]
proc addSafe(memory: HierarchicalMemory, content: string, level: MemoryLevel, 
           tags: seq[string] = @[], parentId: Option[string] = none(string)): MemoryResult[string]
```

#### Hierarchical Navigation
```nim
proc getChildren(memory: HierarchicalMemory, id: string): seq[MemoryEntry]
proc getRoots(memory: HierarchicalMemory): seq[MemoryEntry]
proc getHierarchy(memory: HierarchicalMemory): Table[string, seq[string]]
proc getAll(memory: HierarchicalMemory): seq[MemoryEntry]
```

#### Utilities
```nim
proc len(memory: HierarchicalMemory): int
proc contains(memory: HierarchicalMemory, id: string): bool
proc save(memory: HierarchicalMemory)
```

## Memory Levels

- **ShortTerm**: Recent events, temporary information, immediate tasks
- **MediumTerm**: Information relevant for days to weeks, ongoing projects
- **LongTerm**: Important knowledge for long-term retention, core concepts

## Performance

- **O(1) Access**: Hash table-based storage for fast retrieval
- **Automatic Persistence**: Changes saved immediately to disk
- **Access Tracking**: Every retrieval updates usage statistics
- **Thread Safety**: All operations are protected by locks
- **Memory Efficient**: Only active data kept in RAM

## Examples

### Basic Usage
```nim
import hierarchical_memory

let memory = newHierarchicalMemory()

# Add hierarchical memories
let projectId = memory.add("Q1 Launch Project", LongTerm, @["work", "project"])
let meetingId = memory.add("Team standup", ShortTerm, @["work", "daily"], some(projectId))

# Search and filter
let workItems = memory.searchByTags(@["work"])
let shortTerm = memory.getByLevel(ShortTerm)
let projectChildren = memory.getChildren(projectId)
```

### Advanced Search
```nim
# Combine searches for complex queries
let urgentWork = memory.searchByTags(@["work", "urgent"])
let meetings = memory.searchByContent("meeting")

# Navigate hierarchy
let roots = memory.getRoots()
for root in roots:
  echo "Root: ", root.content
  for child in memory.getChildren(root.id):
    echo "  Child: ", child.content
```

### Access Patterns
```nim
# Track usage
let entry = memory.get(id).get
echo "Accessed ", entry.accessCount, " times"
echo "Last accessed: ", entry.lastAccessed

# Update tracking
memory.update(id, content = some("Updated content"))
```

## Thread Safety

All operations are thread-safe through internal locking. Multiple goroutines can safely:
- Read from different memory entries
- Perform searches simultaneously
- Add/update/delete memories concurrently

## Persistence

- **Automatic Saves**: All modifications trigger disk persistence
- **JSON Format**: Human-readable storage format
- **Crash Recovery**: Data survives application restarts
- **Configurable Location**: Set data directory via constructor

## Error Handling

The library uses Nim's exception system:
- `MemoryError`: Raised for persistence and validation errors
- Option types for safe retrieval operations
- Boolean returns for update/delete operations

## Testing

Run tests using nimble:
```bash
# Quick tests (recommended)
nimble test

# All comprehensive tests with advanced features
nimble testcomp

# Legacy compatibility tests
nimble testall

# Run examples
nimble example

# Performance benchmark
nimble benchmark
```

Or run tests directly:
```bash
nim c -r tests/test_quick.nim
nim c -r tests/test_hierarchical_memory.nim
```

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request