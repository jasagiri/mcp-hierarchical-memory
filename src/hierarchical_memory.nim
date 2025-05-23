## Hierarchical Memory Library for AI Agents
## 
## High-performance memory management system with 3-tier hierarchy:
## - ShortTerm: Recent events and temporary information
## - MediumTerm: Information relevant for days to weeks 
## - LongTerm: Important information for long-term retention
##
## Features:
## - Tree-structured hierarchical organization
## - Tag-based categorization and search
## - Access tracking and usage analytics
## - JSON persistence
## - Thread-safe operations

import std/[tables, json, times, strutils, sequtils, os, options, locks, hashes, random, sets, strformat, algorithm]

when defined(js):
  import std/jsre
else:
  import std/re

type
  MemoryLevel* = enum
    ShortTerm = "short_term"
    MediumTerm = "medium_term"  
    LongTerm = "long_term"

  MemoryEntry* = object
    id*: string
    content*: string
    level*: MemoryLevel
    tags*: seq[string]
    createdAt*: DateTime
    lastAccessed*: DateTime
    accessCount*: uint32
    parentId*: Option[string]
    children*: seq[string]

  MemoryErrorKind* = enum
    ParentNotFound
    MemoryNotFound
    InvalidContent
    InvalidTags
    FileIOError
    JsonParseError
    CircularDependency
    
  MemoryError* = ref object of CatchableError
    kind*: MemoryErrorKind
    details*: string

  MemoryResult*[T] = object
    case success*: bool
    of true:
      value*: T
    else:
      error*: MemoryError

  HierarchicalMemory* = ref object
    memories: Table[string, MemoryEntry]
    dataDir*: string
    lock: Lock
    maxContentLength*: int
    maxTagLength*: int
    maxTagCount*: int

# Result type helpers
proc ok*[T](value: T): MemoryResult[T] =
  MemoryResult[T](success: true, value: value)

proc err*[T](kind: MemoryErrorKind, details: string = ""): MemoryResult[T] =
  let error = new(MemoryError)
  error.kind = kind
  error.details = details
  error.msg = $kind & ": " & details
  MemoryResult[T](success: false, error: error)

proc isOk*[T](memResult: MemoryResult[T]): bool = memResult.success
proc isErr*[T](memResult: MemoryResult[T]): bool = not memResult.success
proc get*[T](memResult: MemoryResult[T]): T = 
  if memResult.success: memResult.value
  else: raise memResult.error

proc getOrDefault*[T](memResult: MemoryResult[T], default: T): T =
  if memResult.success: memResult.value else: default

# Improved UUID-like ID generation
var 
  idCounter {.global.} = 0
  randomSeed {.global.} = false

proc generateUuid(): string =
  ## Generate a UUID-like identifier
  if not randomSeed:
    randomize()
    randomSeed = true
  
  inc idCounter
  let 
    timestamp = epochTime().int64
    randPart1 = rand(0xFFFF)
    randPart2 = rand(0xFFFF)
    randPart3 = rand(0xFFFF)
  
  result = format("$1-$2-$3-$4-$5", 
    toHex(timestamp and 0xFFFFFFFF, 8),
    toHex(randPart1, 4),
    toHex(randPart2, 4), 
    toHex(randPart3, 4),
    toHex(idCounter and 0xFFFFFFFF, 8))

# Validation functions
proc validateContent(content: string, maxLength: int): MemoryResult[bool] =
  if content.len == 0:
    return err[bool](InvalidContent, "Content cannot be empty")
  if content.len > maxLength:
    return err[bool](InvalidContent, "Content too long: " & $content.len & " > " & $maxLength)
  ok(true)

proc validateTags(tags: seq[string], maxTagLength: int, maxTagCount: int): MemoryResult[bool] =
  if tags.len > maxTagCount:
    return err[bool](InvalidTags, "Too many tags: " & $tags.len & " > " & $maxTagCount)
  
  for tag in tags:
    if tag.len == 0:
      return err[bool](InvalidTags, "Tag cannot be empty")
    if tag.len > maxTagLength:
      return err[bool](InvalidTags, "Tag too long: " & tag & " (" & $tag.len & " > " & $maxTagLength & ")")
    if not tag.allIt(it.isAlphaNumeric or it in ['_', '-']):
      return err[bool](InvalidTags, "Tag contains invalid characters: " & tag)
  
  ok(true)

proc validateLevel*(level: string): MemoryResult[MemoryLevel] =
  ## Validate and convert string to MemoryLevel
  case level.toLower:
    of "short_term", "short", "st": ok(ShortTerm)
    of "medium_term", "medium", "mt": ok(MediumTerm)
    of "long_term", "long", "lt": ok(LongTerm)
    else: err[MemoryLevel](InvalidContent, "Invalid memory level: " & level)

proc newMemoryEntry*(content: string, level: MemoryLevel, tags: seq[string] = @[], parentId: Option[string] = none(string)): MemoryEntry =
  ## Create a new memory entry with generated UUID
  let now = now()
  result = MemoryEntry(
    id: generateUuid(),
    content: content,
    level: level,
    tags: tags,
    createdAt: now,
    lastAccessed: now,
    accessCount: 0,
    parentId: parentId,
    children: @[]
  )

proc access*(entry: var MemoryEntry) =
  ## Update access tracking for a memory entry
  entry.lastAccessed = now()
  inc entry.accessCount

proc `$`*(entry: MemoryEntry): string =
  ## String representation of memory entry
  result = "MemoryEntry(id: " & entry.id & ", level: " & $entry.level & ", content: \"" & entry.content[0..min(49, entry.content.len-1)] & "...\")"

# JSON serialization
proc `%`*(level: MemoryLevel): JsonNode = newJString($level)
proc `%`*(dt: DateTime): JsonNode = newJString(dt.format("yyyy-MM-dd'T'HH:mm:ss'Z'"))
proc `%`*(opt: Option[string]): JsonNode = 
  if opt.isSome: newJString(opt.get) else: newJNull()

proc to*(node: JsonNode, T: typedesc[MemoryLevel]): MemoryLevel =
  case node.getStr:
    of "short_term": ShortTerm
    of "medium_term": MediumTerm  
    of "long_term": LongTerm
    else: raise newException(ValueError, "Invalid memory level: " & node.getStr)

proc to*(node: JsonNode, T: typedesc[DateTime]): DateTime =
  parse(node.getStr, "yyyy-MM-dd'T'HH:mm:ss'Z'")

proc to*(node: JsonNode, T: typedesc[Option[string]]): Option[string] =
  if node.kind == JNull: none(string) else: some(node.getStr)

proc `%`*(entry: MemoryEntry): JsonNode =
  result = %*{
    "id": entry.id,
    "content": entry.content,
    "level": entry.level,
    "tags": entry.tags,
    "created_at": entry.createdAt,
    "last_accessed": entry.lastAccessed,
    "access_count": entry.accessCount,
    "parent_id": entry.parentId,
    "children": entry.children
  }

proc to*(node: JsonNode, T: typedesc[MemoryEntry]): MemoryEntry =
  result = MemoryEntry(
    id: node["id"].getStr,
    content: node["content"].getStr,
    level: node["level"].to(MemoryLevel),
    tags: node["tags"].to(seq[string]),
    createdAt: node["created_at"].to(DateTime),
    lastAccessed: node["last_accessed"].to(DateTime),
    accessCount: node["access_count"].getInt.uint32,
    parentId: node["parent_id"].to(Option[string]),
    children: node["children"].to(seq[string])
  )

proc newHierarchicalMemoryWithConfig*(
  dataDir: string = "", 
  maxContentLength: int = 10000,
  maxTagLength: int = 50,
  maxTagCount: int = 20
): MemoryResult[HierarchicalMemory] =
  ## Create a new hierarchical memory instance with environment variable support
  let finalDataDir = 
    if dataDir.len > 0: dataDir
    else:
      try:
        getEnv("MEMORY_DATA_DIR", "./data")
      except:
        "./data"
  
  try:
    # Create data directory if it doesn't exist
    if not dirExists(finalDataDir):
      createDir(finalDataDir)
    
    var memory = HierarchicalMemory(
      memories: initTable[string, MemoryEntry](),
      dataDir: finalDataDir,
      maxContentLength: maxContentLength,
      maxTagLength: maxTagLength,
      maxTagCount: maxTagCount
    )
    initLock(memory.lock)
    
    # Load existing memories
    let memoryFile = finalDataDir / "memories.json"
    if fileExists(memoryFile):
      try:
        let content = readFile(memoryFile)
        if content.len > 0:
          let jsonData = parseJson(content)
          for id, entryJson in jsonData:
            memory.memories[id] = entryJson.to(MemoryEntry)
      except JsonParsingError as e:
        return err[HierarchicalMemory](JsonParseError, "Failed to parse memory file: " & e.msg)
      except Exception as e:
        return err[HierarchicalMemory](FileIOError, "Failed to load memories: " & e.msg)
    
    return ok(memory)
    
  except OSError as e:
    return err[HierarchicalMemory](FileIOError, "Failed to create data directory: " & e.msg)
  except Exception as e:
    return err[HierarchicalMemory](FileIOError, "Unexpected error: " & e.msg)

# Legacy wrapper for backward compatibility
proc newHierarchicalMemory*(dataDir: string = "./data"): HierarchicalMemory =
  let memResult = newHierarchicalMemoryWithConfig(dataDir, 10000, 50, 20)
  if memResult.isErr:
    raise memResult.error
  return memResult.get

proc save*(memory: HierarchicalMemory) =
  ## Save all memories to disk
  let memoryFile = memory.dataDir / "memories.json"
  let jsonData = newJObject()
  for id, entry in memory.memories:
    jsonData[id] = %entry
  
  try:
    writeFile(memoryFile, jsonData.pretty)
  except Exception as e:
    let error = new(MemoryError)
    error.kind = FileIOError
    error.details = "Failed to save memories: " & e.msg
    error.msg = error.details
    raise error

# Circular dependency detection
proc detectCircularDependency(memory: HierarchicalMemory, parentId: string, newChildId: string): bool =
  ## Check if adding newChildId as a child of parentId would create a cycle
  var visited = initHashSet[string]()
  var current = parentId
  
  while current.len > 0:
    if current == newChildId:
      return true
    if current in visited:
      return true
    visited.incl(current)
    
    if current in memory.memories:
      current = memory.memories[current].parentId.get("")
    else:
      break
  
  return false

proc addSafe*(memory: HierarchicalMemory, content: string, level: MemoryLevel, tags: seq[string] = @[], parentId: Option[string] = none(string)): MemoryResult[string] =
  ## Add a new memory entry with validation and return its ID
  withLock memory.lock:
    # Validate content
    let contentResult = validateContent(content, memory.maxContentLength)
    if contentResult.isErr:
      return err[string](contentResult.error.kind, contentResult.error.details)
    
    # Validate tags
    let tagsResult = validateTags(tags, memory.maxTagLength, memory.maxTagCount)
    if tagsResult.isErr:
      return err[string](tagsResult.error.kind, tagsResult.error.details)
    
    # Validate parent exists if specified
    if parentId.isSome:
      let pid = parentId.get
      if pid notin memory.memories:
        return err[string](ParentNotFound, "Parent memory not found: " & pid)
      
      # Check for circular dependency
      let entry = newMemoryEntry(content, level, tags, parentId)
      if memory.detectCircularDependency(pid, entry.id):
        return err[string](CircularDependency, "Adding this relationship would create a circular dependency")
    
    let entry = newMemoryEntry(content, level, tags, parentId)
    memory.memories[entry.id] = entry
    
    # Update parent's children list
    if parentId.isSome:
      memory.memories[parentId.get].children.add(entry.id)
    
    try:
      memory.save()
      return ok(entry.id)
    except Exception as e:
      # Rollback on save failure
      memory.memories.del(entry.id)
      if parentId.isSome:
        memory.memories[parentId.get].children.keepItIf(it != entry.id)
      return err[string](FileIOError, "Failed to save: " & e.msg)

# Legacy wrapper for backward compatibility
proc add*(memory: HierarchicalMemory, content: string, level: MemoryLevel, tags: seq[string] = @[], parentId: Option[string] = none(string)): string =
  let addResult = memory.addSafe(content, level, tags, parentId)
  if addResult.isErr:
    raise addResult.error
  return addResult.get

proc get*(memory: HierarchicalMemory, id: string): Option[MemoryEntry] =
  ## Get a memory entry by ID (updates access tracking)
  withLock memory.lock:
    if id in memory.memories:
      memory.memories[id].access()
      memory.save()
      return some(memory.memories[id])
    else:
      return none(MemoryEntry)

proc update*(memory: HierarchicalMemory, id: string, content: Option[string] = none(string), level: Option[MemoryLevel] = none(MemoryLevel), tags: Option[seq[string]] = none(seq[string])): bool =
  ## Update an existing memory entry
  withLock memory.lock:
    if id notin memory.memories:
      return false
    
    if content.isSome:
      memory.memories[id].content = content.get
    if level.isSome:
      memory.memories[id].level = level.get
    if tags.isSome:
      memory.memories[id].tags = tags.get
    
    memory.memories[id].access()
    memory.save()
    return true

proc delete*(memory: HierarchicalMemory, id: string): bool =
  ## Delete a memory entry and all its children recursively
  withLock memory.lock:
    if id notin memory.memories:
      return false
    
    let entry = memory.memories[id]
    
    # Recursively delete children
    for childId in entry.children:
      discard memory.delete(childId)
    
    # Remove from parent's children list
    if entry.parentId.isSome:
      let parentId = entry.parentId.get
      if parentId in memory.memories:
        memory.memories[parentId].children.keepItIf(it != id)
    
    # Remove the entry itself
    memory.memories.del(id)
    memory.save()
    return true

proc searchByTags*(memory: HierarchicalMemory, tags: seq[string]): seq[MemoryEntry] =
  ## Search memories containing all specified tags
  withLock memory.lock:
    result = @[]
    for entry in memory.memories.mvalues:
      if tags.allIt(it in entry.tags):
        entry.access()
        result.add(entry)
    memory.save()

proc searchByContent*(memory: HierarchicalMemory, query: string): seq[MemoryEntry] =
  ## Search memories by content (case-insensitive)
  withLock memory.lock:
    result = @[]
    let lowerQuery = query.toLower
    for entry in memory.memories.mvalues:
      if lowerQuery in entry.content.toLower:
        entry.access()
        result.add(entry)
    memory.save()

proc getByLevel*(memory: HierarchicalMemory, level: MemoryLevel): seq[MemoryEntry] =
  ## Get all memories of a specific level
  withLock memory.lock:
    result = @[]
    for entry in memory.memories.mvalues:
      if entry.level == level:
        entry.access()
        result.add(entry)
    memory.save()

proc getChildren*(memory: HierarchicalMemory, id: string): seq[MemoryEntry] =
  ## Get direct children of a memory entry
  withLock memory.lock:
    result = @[]
    if id in memory.memories:
      let parent = memory.memories[id]
      for childId in parent.children:
        if childId in memory.memories:
          memory.memories[childId].access()
          result.add(memory.memories[childId])
      memory.save()

proc getRoots*(memory: HierarchicalMemory): seq[MemoryEntry] =
  ## Get all root-level memories (no parent)
  withLock memory.lock:
    result = @[]
    for entry in memory.memories.mvalues:
      if entry.parentId.isNone:
        entry.access()
        result.add(entry)
    memory.save()

proc getAll*(memory: HierarchicalMemory): seq[MemoryEntry] =
  ## Get all memory entries
  withLock memory.lock:
    result = @[]
    for entry in memory.memories.mvalues:
      entry.access()
      result.add(entry)
    memory.save()

# Advanced search functions
proc searchByContentRegex*(memory: HierarchicalMemory, pattern: string): MemoryResult[seq[MemoryEntry]] =
  ## Search memories by content using regex pattern
  withLock memory.lock:
    try:
      when defined(js):
        let regex = newRegExp(pattern, "i")
      else:
        let regex = re(pattern, {reIgnoreCase})
      
      var results: seq[MemoryEntry]
      for entry in memory.memories.mvalues:
        when defined(js):
          if regex.test(entry.content):
            entry.access()
            results.add(entry)
        else:
          if entry.content.contains(regex):
            entry.access()
            results.add(entry)
      
      memory.save()
      return ok(results)
    except RegexError as e:
      return err[seq[MemoryEntry]](InvalidContent, "Invalid regex pattern: " & e.msg)
    except Exception as e:
      return err[seq[MemoryEntry]](FileIOError, "Search failed: " & e.msg)

proc searchByTagsOr*(memory: HierarchicalMemory, tags: seq[string]): seq[MemoryEntry] =
  ## Search memories containing any of the specified tags (OR operation)
  withLock memory.lock:
    result = @[]
    for entry in memory.memories.mvalues:
      if tags.anyIt(it in entry.tags):
        entry.access()
        result.add(entry)
    memory.save()

proc getMemoryStats*(memory: HierarchicalMemory): Table[string, int] =
  ## Get statistics about memory usage
  withLock memory.lock:
    result = initTable[string, int]()
    var shortCount, mediumCount, longCount = 0
    var totalAccess = 0
    
    for entry in memory.memories.values:
      case entry.level:
        of ShortTerm: inc shortCount
        of MediumTerm: inc mediumCount  
        of LongTerm: inc longCount
      totalAccess += entry.accessCount.int
    
    result["total"] = memory.memories.len
    result["short_term"] = shortCount
    result["medium_term"] = mediumCount
    result["long_term"] = longCount
    result["total_accesses"] = totalAccess
    result["roots"] = memory.getRoots().len

proc getMostAccessed*(memory: HierarchicalMemory, limit: int = 10): seq[MemoryEntry] =
  ## Get the most frequently accessed memories
  withLock memory.lock:
    result = memory.getAll().sortedByIt(-it.accessCount.int)
    if result.len > limit:
      result = result[0..<limit]

proc getRecentlyAccessed*(memory: HierarchicalMemory, limit: int = 10): seq[MemoryEntry] =
  ## Get the most recently accessed memories
  withLock memory.lock:
    result = memory.getAll().sortedByIt(-it.lastAccessed.toTime.toUnix)
    if result.len > limit:
      result = result[0..<limit]

proc getByDateRange*(memory: HierarchicalMemory, startDate: DateTime, endDate: DateTime): seq[MemoryEntry] =
  ## Get memories created within a date range
  withLock memory.lock:
    result = @[]
    for entry in memory.memories.mvalues:
      if entry.createdAt >= startDate and entry.createdAt <= endDate:
        entry.access()
        result.add(entry)
    memory.save()

proc getHierarchy*(memory: HierarchicalMemory): Table[string, seq[string]] =
  ## Get the complete parent-child hierarchy mapping
  withLock memory.lock:
    result = initTable[string, seq[string]]()
    for id, entry in memory.memories:
      result[id] = entry.children

proc len*(memory: HierarchicalMemory): int =
  ## Get the total number of memories
  memory.memories.len

proc contains*(memory: HierarchicalMemory, id: string): bool =
  ## Check if a memory ID exists
  id in memory.memories

when isMainModule:
  # Example usage
  let memory = newHierarchicalMemory("./test_data")
  
  # Add some memories
  let id1 = memory.add("Important project deadline next week", LongTerm, @["work", "deadline"])
  let id2 = memory.add("Buy groceries", ShortTerm, @["todo", "personal"], some(id1))
  let id3 = memory.add("Call mom", ShortTerm, @["personal", "family"])
  
  echo "Added memories: ", memory.len
  
  # Search by tags
  let workMemories = memory.searchByTags(@["work"])
  echo "Work memories: ", workMemories.len
  
  # Get hierarchy
  let hierarchy = memory.getHierarchy()
  echo "Hierarchy: ", hierarchy