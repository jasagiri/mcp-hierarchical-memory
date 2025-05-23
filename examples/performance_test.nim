## Performance testing for the Hierarchical Memory library

import ../src/hierarchical_memory
import std/[options, strformat, times, sequtils]

proc performanceTest() =
  echo "=== Hierarchical Memory Performance Test ==="
  
  let memory = newHierarchicalMemory("./perf_data")
  
  # Test batch insertion performance
  echo "\n--- Batch Insertion Test ---"
  let insertStart = epochTime()
  
  for i in 1..1000:
    let level = case i mod 3:
      of 0: ShortTerm
      of 1: MediumTerm
      else: LongTerm
    
    discard memory.add(
      fmt"Memory entry {i}",
      level,
      @[fmt"tag{i mod 10}", "batch", "test"]
    )
  
  let insertEnd = epochTime()
  let insertTime = insertEnd - insertStart
  echo fmt"Inserted 1000 memories in {insertTime:.3f} seconds"
  echo fmt"Rate: {1000.0 / insertTime:.1f} insertions/second"
  
  # Test retrieval performance
  echo "\n--- Retrieval Test ---"
  let retrievalStart = epochTime()
  
  var totalAccesses = 0
  for i in 1..1000:
    let allMemories = memory.getAll()
    for mem in allMemories:
      if mem.accessCount > 0:
        inc totalAccesses
  
  let retrievalEnd = epochTime()
  let retrievalTime = retrievalEnd - retrievalStart
  echo fmt"Retrieved all memories 1000 times in {retrievalTime:.3f} seconds"
  echo fmt"Total access tracking updates: {totalAccesses}"
  
  # Test search performance
  echo "\n--- Search Performance Test ---"
  let searchStart = epochTime()
  
  for i in 1..100:
    discard memory.searchByTags(@["batch"])
    discard memory.searchByContent("Memory")
    discard memory.getByLevel(LongTerm)
  
  let searchEnd = epochTime()
  let searchTime = searchEnd - searchStart
  echo fmt"Performed 300 searches in {searchTime:.3f} seconds"
  echo fmt"Rate: {300.0 / searchTime:.1f} searches/second"
  
  # Test hierarchical operations
  echo "\n--- Hierarchical Operations Test ---"
  let hierStart = epochTime()
  
  # Create parent-child relationships
  let parentId = memory.add("Parent node", LongTerm, @["parent"])
  for i in 1..100:
    discard memory.add(fmt"Child {i}", ShortTerm, @["child"], some(parentId))
  
  # Test hierarchy navigation
  for i in 1..50:
    discard memory.getChildren(parentId)
    discard memory.getRoots()
    discard memory.getHierarchy()
  
  let hierEnd = epochTime()
  let hierTime = hierEnd - hierStart
  echo fmt"Created 100 children and performed 150 hierarchy operations in {hierTime:.3f} seconds"
  
  # Final statistics
  echo "\n--- Final Statistics ---"
  echo fmt"Total memories: {memory.len}"
  
  let allMemories = memory.getAll()
  let shortTerm = allMemories.filterIt(it.level == ShortTerm).len
  let mediumTerm = allMemories.filterIt(it.level == MediumTerm).len
  let longTerm = allMemories.filterIt(it.level == LongTerm).len
  
  echo fmt"  Short-term: {shortTerm}"
  echo fmt"  Medium-term: {mediumTerm}"
  echo fmt"  Long-term: {longTerm}"
  
  let totalTime = epochTime() - insertStart
  echo fmt"Total test time: {totalTime:.3f} seconds"
  
  echo "\n=== Performance Test Complete ==="

when isMainModule:
  performanceTest()