import unittest, options, os, times, tables
import ../src/hierarchical_memory

suite "Hierarchical Memory Tests":
  let testDataDir = "./test_data_" & $epochTime().int
  
  setup:
    if dirExists(testDataDir):
      removeDir(testDataDir)

  teardown:
    if dirExists(testDataDir):
      removeDir(testDataDir)

  test "Create new memory instance":
    let memory = newHierarchicalMemory(testDataDir)
    check memory.len == 0
    check dirExists(testDataDir)

  test "Add and retrieve memory entries":
    let memory = newHierarchicalMemory(testDataDir)
    let id = memory.add("Test content", ShortTerm, @["test"])
    
    check memory.len == 1
    check memory.contains(id)
    
    let retrieved = memory.get(id)
    check retrieved.isSome
    check retrieved.get.content == "Test content"
    check retrieved.get.level == ShortTerm
    check retrieved.get.tags == @["test"]
    check retrieved.get.accessCount == 1  # Access tracking

  test "Hierarchical relationships":
    let memory = newHierarchicalMemory(testDataDir)
    let parentId = memory.add("Parent memory", LongTerm, @["parent"])
    let childId = memory.add("Child memory", ShortTerm, @["child"], some(parentId))
    
    let parent = memory.get(parentId).get
    let child = memory.get(childId).get
    
    check child.parentId.isSome
    check child.parentId.get == parentId
    check childId in parent.children
    
    # Test getChildren
    let children = memory.getChildren(parentId)
    check children.len == 1
    check children[0].id == childId

  test "Update memory entry":
    let memory = newHierarchicalMemory(testDataDir)
    let id = memory.add("Original content", ShortTerm)
    
    let updated = memory.update(id, content = some("Updated content"), level = some(LongTerm))
    check updated == true
    
    let retrieved = memory.get(id).get
    check retrieved.content == "Updated content"
    check retrieved.level == LongTerm

  test "Delete memory with children":
    let memory = newHierarchicalMemory(testDataDir)
    let parentId = memory.add("Parent", LongTerm)
    let childId = memory.add("Child", ShortTerm, parentId = some(parentId))
    let grandchildId = memory.add("Grandchild", ShortTerm, parentId = some(childId))
    
    check memory.len == 3
    
    # Delete parent should delete all children
    let deleted = memory.delete(parentId)
    check deleted == true
    check memory.len == 0

  test "Search by tags":
    let memory = newHierarchicalMemory(testDataDir)
    discard memory.add("Work task 1", ShortTerm, @["work", "urgent"])
    discard memory.add("Work task 2", MediumTerm, @["work", "planning"])
    discard memory.add("Personal task", ShortTerm, @["personal"])
    
    let workMemories = memory.searchByTags(@["work"])
    check workMemories.len == 2
    
    let urgentMemories = memory.searchByTags(@["work", "urgent"])
    check urgentMemories.len == 1

  test "Search by content":
    let memory = newHierarchicalMemory(testDataDir)
    discard memory.add("Important meeting tomorrow", ShortTerm)
    discard memory.add("Schedule important call", MediumTerm)
    discard memory.add("Regular task", ShortTerm)
    
    let results = memory.searchByContent("important")
    check results.len == 2

  test "Filter by level":
    let memory = newHierarchicalMemory(testDataDir)
    discard memory.add("Short term task", ShortTerm)
    discard memory.add("Medium term goal", MediumTerm)
    discard memory.add("Long term vision", LongTerm)
    discard memory.add("Another short task", ShortTerm)
    
    let shortTerm = memory.getByLevel(ShortTerm)
    check shortTerm.len == 2
    
    let longTerm = memory.getByLevel(LongTerm)
    check longTerm.len == 1

  test "Get root memories":
    let memory = newHierarchicalMemory(testDataDir)
    let root1 = memory.add("Root 1", LongTerm)
    let root2 = memory.add("Root 2", MediumTerm)
    discard memory.add("Child", ShortTerm, parentId = some(root1))
    
    let roots = memory.getRoots()
    check roots.len == 2

  test "Persistence across instances":
    # Create first instance and add memories
    block:
      let memory1 = newHierarchicalMemory(testDataDir)
      discard memory1.add("Persistent memory", LongTerm, @["test"])
      check memory1.len == 1
    
    # Create second instance and verify data persisted
    block:
      let memory2 = newHierarchicalMemory(testDataDir)
      check memory2.len == 1
      
      let memories = memory2.getAll()
      check memories[0].content == "Persistent memory"
      check memories[0].level == LongTerm
      check memories[0].tags == @["test"]

  test "Access tracking":
    let memory = newHierarchicalMemory(testDataDir)
    let id = memory.add("Test memory", ShortTerm)
    
    # Initial access count should be 0
    let initial = memory.get(id).get
    check initial.accessCount == 1  # get() increments count
    
    # Multiple accesses should increment count
    discard memory.get(id)
    discard memory.get(id)
    let accessed = memory.get(id).get
    check accessed.accessCount == 4

  test "Error handling":
    let memory = newHierarchicalMemory(testDataDir)
    
    # Try to get non-existent memory
    let result = memory.get("non-existent-id")
    check result.isNone
    
    # Try to update non-existent memory
    let updated = memory.update("non-existent-id", content = some("new content"))
    check updated == false
    
    # Try to delete non-existent memory
    let deleted = memory.delete("non-existent-id")
    check deleted == false
    
    # Try to add child with non-existent parent
    expect(MemoryError):
      discard memory.add("Child", ShortTerm, parentId = some("non-existent-parent"))

  test "Get hierarchy mapping":
    let memory = newHierarchicalMemory(testDataDir)
    let parent = memory.add("Parent", LongTerm)
    let child1 = memory.add("Child 1", ShortTerm, parentId = some(parent))
    let child2 = memory.add("Child 2", ShortTerm, parentId = some(parent))
    
    let hierarchy = memory.getHierarchy()
    check hierarchy.hasKey(parent)
    check hierarchy[parent].len == 2
    check child1 in hierarchy[parent]
    check child2 in hierarchy[parent]