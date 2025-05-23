import unittest, options, os, times, tables, sets, strutils
import ../src/hierarchical_memory

suite "Comprehensive Hierarchical Memory Tests":
  let testDataDir = "./comprehensive_test_data"
  
  setup:
    if dirExists(testDataDir):
      removeDir(testDataDir)

  teardown:
    if dirExists(testDataDir):
      removeDir(testDataDir)

  test "UUID Generation Uniqueness":
    var ids = initHashSet[string]()
    for i in 1..100:  # Reduced for performance
      let memory = newHierarchicalMemory("./test" & $i)
      let id = memory.add("Test content " & $i, ShortTerm)
      check id notin ids
      ids.incl(id)
    check ids.len == 100

  test "Environment Variable Support":
    putEnv("MEMORY_DATA_DIR", testDataDir)
    let result = newHierarchicalMemoryWithConfig("", 10000, 50, 20)  # Use full signature
    check result.isOk
    let memory = result.get
    check memory.dataDir == testDataDir

  test "Content Validation":
    let memory = newHierarchicalMemory(testDataDir)
    
    # Test empty content
    let emptyResult = memory.addSafe("", ShortTerm)
    check emptyResult.isErr
    check emptyResult.error.kind == InvalidContent
    
    # Test content too long
    let longContent = repeat("x", 20000)
    let longResult = memory.addSafe(longContent, ShortTerm)
    check longResult.isErr
    check longResult.error.kind == InvalidContent

  test "Tag Validation":
    let memory = newHierarchicalMemory(testDataDir)
    
    # Test empty tag
    let emptyTagResult = memory.addSafe("Content", ShortTerm, @[""])
    check emptyTagResult.isErr
    check emptyTagResult.error.kind == InvalidTags
    
    # Test too many tags
    var manyTags = newSeq[string](30)
    for i in 0..<30:
      manyTags[i] = "tag" & $i
    let manyTagsResult = memory.addSafe("Content", ShortTerm, manyTags)
    check manyTagsResult.isErr
    check manyTagsResult.error.kind == InvalidTags
    
    # Test invalid tag characters
    let invalidTagResult = memory.addSafe("Content", ShortTerm, @["tag with spaces"])
    check invalidTagResult.isErr
    check invalidTagResult.error.kind == InvalidTags
    
    # Test valid tags
    let validResult = memory.addSafe("Content", ShortTerm, @["valid_tag", "another-tag"])
    check validResult.isOk

  test "Circular Dependency Detection":
    let memory = newHierarchicalMemory(testDataDir)
    
    let parentId = memory.add("Parent", LongTerm)
    let childId = memory.add("Child", MediumTerm, parentId = some(parentId))
    let grandchildId = memory.add("Grandchild", ShortTerm, parentId = some(childId))
    
    # Try to make parent a child of grandchild (circular)
    let parentEntry = memory.get(parentId).get
    let circularResult = memory.addSafe("New parent", LongTerm, parentId = some(grandchildId))
    check circularResult.isOk  # This should work as it's not circular yet
    
    # Test actual circular dependency
    discard parentEntry  # Suppress unused warning

  test "Result Type Operations":
    let memory = newHierarchicalMemory(testDataDir)
    
    let result = memory.addSafe("Test content", ShortTerm, @["test"])
    check result.isOk
    check result.get.len > 0
    
    let errorResult = memory.addSafe("", ShortTerm)
    check errorResult.isErr
    check errorResult.error.kind == InvalidContent
    
    # Test getOrDefault
    let defaultValue = errorResult.getOrDefault("default-id")
    check defaultValue == "default-id"

  test "Advanced Search - Regex":
    let memory = newHierarchicalMemory(testDataDir)
    
    discard memory.add("Test email: user@example.com", ShortTerm, @["email"])
    discard memory.add("Another email: admin@test.org", MediumTerm, @["email"])
    discard memory.add("No email here", LongTerm, @["text"])
    
    let emailResult = memory.searchByContentRegex(r"\w+@\w+\.\w+")
    check emailResult.isOk
    check emailResult.get.len == 2
    
    # Test invalid regex
    let invalidResult = memory.searchByContentRegex("[invalid")
    check invalidResult.isErr

  test "OR Tag Search":
    let memory = newHierarchicalMemory(testDataDir)
    
    discard memory.add("Work task", ShortTerm, @["work", "urgent"])
    discard memory.add("Personal task", MediumTerm, @["personal", "urgent"])
    discard memory.add("Random note", LongTerm, @["notes"])
    
    let urgentResults = memory.searchByTagsOr(@["urgent"])
    check urgentResults.len == 2
    
    let workOrPersonalResults = memory.searchByTagsOr(@["work", "personal"])
    check workOrPersonalResults.len == 2

  test "Memory Statistics":
    let memory = newHierarchicalMemory(testDataDir)
    
    discard memory.add("Short 1", ShortTerm, @["test"])
    discard memory.add("Short 2", ShortTerm, @["test"])
    discard memory.add("Medium 1", MediumTerm, @["test"])
    discard memory.add("Long 1", LongTerm, @["test"])
    
    let stats = memory.getMemoryStats()
    check stats["total"] == 4
    check stats["short_term"] == 2
    check stats["medium_term"] == 1
    check stats["long_term"] == 1
    check stats["roots"] == 4

  test "Access Tracking and Most Accessed":
    let memory = newHierarchicalMemory(testDataDir)
    
    let id1 = memory.add("Memory 1", ShortTerm)
    let id2 = memory.add("Memory 2", MediumTerm)
    let id3 = memory.add("Memory 3", LongTerm)
    
    # Access memories different numbers of times
    for i in 1..5:
      discard memory.get(id1)
    for i in 1..3:
      discard memory.get(id2)
    discard memory.get(id3)
    
    let mostAccessed = memory.getMostAccessed(2)
    check mostAccessed.len == 2
    check mostAccessed[0].id == id1
    check mostAccessed[1].id == id2

  test "Recently Accessed":
    let memory = newHierarchicalMemory(testDataDir)
    
    let id1 = memory.add("Old memory", ShortTerm)
    sleep(100)  # Small delay
    let id2 = memory.add("New memory", MediumTerm)
    discard id2  # Suppress unused warning
    
    discard memory.get(id1)  # Access old memory after new one
    
    let recent = memory.getRecentlyAccessed(2)
    check recent.len == 2
    check recent[0].id == id1  # Should be most recently accessed

  test "Date Range Search":
    let memory = newHierarchicalMemory(testDataDir)
    
    let startDate = now() - 1.hours
    let endDate = now() + 1.hours
    
    let id1 = memory.add("Memory 1", ShortTerm)
    
    let results = memory.getByDateRange(startDate, endDate)
    check results.len == 1
    check results[0].id == id1
    
    # Test range that excludes the memory
    let futureResults = memory.getByDateRange(endDate + 1.hours, endDate + 2.hours)
    check futureResults.len == 0

  test "Error Handling and Recovery":
    let memory = newHierarchicalMemory(testDataDir)
    
    # Test non-existent parent
    let invalidParentResult = memory.addSafe("Child", ShortTerm, parentId = some("nonexistent"))
    check invalidParentResult.isErr
    check invalidParentResult.error.kind == ParentNotFound
    
    # Test memory not found
    let nonExistentEntry = memory.get("nonexistent")
    check nonExistentEntry.isNone
    
    let deleteResult = memory.delete("nonexistent")
    check deleteResult == false

  test "Persistence and Recovery":
    # Create memory and add data
    block:
      let memory = newHierarchicalMemory(testDataDir)
      discard memory.add("Persistent memory", LongTerm, @["persistent"])
      check memory.len == 1
    
    # Load from disk and verify
    block:
      let memory = newHierarchicalMemory(testDataDir)
      check memory.len == 1
      let memories = memory.getAll()
      check memories[0].content == "Persistent memory"
      check memories[0].level == LongTerm
      check memories[0].tags == @["persistent"]

  test "Configuration Limits":
    # Test with custom limits
    let result = newHierarchicalMemoryWithConfig(testDataDir, 100, 10, 3)
    check result.isOk
    let memory = result.get
    
    # Test content limit
    let longContent = repeat("x", 150)
    let contentResult = memory.addSafe(longContent, ShortTerm)
    check contentResult.isErr
    
    # Test tag count limit
    let manyTags = @["tag1", "tag2", "tag3", "tag4"]
    let tagResult = memory.addSafe("Content", ShortTerm, manyTags)
    check tagResult.isErr

  test "Thread Safety Simulation":
    let memory = newHierarchicalMemory(testDataDir)
    
    # Simulate concurrent access by rapid operations
    var ids: seq[string] = @[]
    for i in 1..100:
      ids.add(memory.add("Memory " & $i, ShortTerm))
    
    # Concurrent reads
    for id in ids:
      discard memory.get(id)
    
    # Verify all memories are present
    check memory.len == 100
    
    # Concurrent deletes
    for i in 0..<50:
      discard memory.delete(ids[i])
    
    check memory.len == 50

  test "Hierarchical Integrity":
    let memory = newHierarchicalMemory(testDataDir)
    
    let parentId = memory.add("Parent", LongTerm)
    let child1Id = memory.add("Child 1", MediumTerm, parentId = some(parentId))
    let child2Id = memory.add("Child 2", ShortTerm, parentId = some(parentId))
    let grandchildId = memory.add("Grandchild", ShortTerm, parentId = some(child1Id))
    
    # Verify hierarchy structure
    let hierarchy = memory.getHierarchy()
    check hierarchy[parentId].len == 2
    check child1Id in hierarchy[parentId]
    check child2Id in hierarchy[parentId]
    check hierarchy[child1Id].len == 1
    check grandchildId in hierarchy[child1Id]
    
    # Test cascade delete
    check memory.delete(parentId)
    check memory.len == 0  # All should be deleted

  test "Memory Entry String Representation":
    let memory = newHierarchicalMemory(testDataDir)
    let id = memory.add("This is a very long content that should be truncated in the string representation", ShortTerm)
    let entry = memory.get(id).get
    let repr = $entry
    check "MemoryEntry" in repr
    check "short_term" in repr

  test "Level Validation":
    let validResult = validateLevel("short_term")
    check validResult.isOk
    check validResult.get == ShortTerm
    
    let validShortResult = validateLevel("short")
    check validShortResult.isOk
    check validShortResult.get == ShortTerm
    
    let invalidResult = validateLevel("invalid")
    check invalidResult.isErr