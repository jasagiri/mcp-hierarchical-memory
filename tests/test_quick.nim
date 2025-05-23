import unittest, options, os
import ../src/hierarchical_memory

suite "Quick Hierarchical Memory Tests":
  let testDataDir = "./quick_test_data"
  
  setup:
    if dirExists(testDataDir):
      removeDir(testDataDir)

  teardown:
    if dirExists(testDataDir):
      removeDir(testDataDir)

  test "Basic operations":
    let memory = newHierarchicalMemory(testDataDir)
    
    # Add memory
    let id = memory.add("Test content", ShortTerm, @["test"])
    check memory.len == 1
    
    # Retrieve memory
    let retrieved = memory.get(id)
    check retrieved.isSome
    check retrieved.get.content == "Test content"
    
    # Update memory
    let updated = memory.update(id, content = some("Updated content"))
    check updated == true
    
    # Delete memory
    let deleted = memory.delete(id)
    check deleted == true
    check memory.len == 0

  test "Search operations":
    let memory = newHierarchicalMemory(testDataDir)
    
    discard memory.add("Work task", ShortTerm, @["work"])
    discard memory.add("Personal task", MediumTerm, @["personal"])
    
    let workResults = memory.searchByTags(@["work"])
    check workResults.len == 1
    
    let contentResults = memory.searchByContent("task")
    check contentResults.len == 2

  test "Hierarchy":
    let memory = newHierarchicalMemory(testDataDir)
    
    let parentId = memory.add("Parent", LongTerm)
    let childId = memory.add("Child", ShortTerm, parentId = some(parentId))
    
    let children = memory.getChildren(parentId)
    check children.len == 1
    check children[0].id == childId
    
    echo "All tests passed!"