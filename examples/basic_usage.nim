## Basic usage example of the Hierarchical Memory library

import ../src/hierarchical_memory
import std/[options, strformat, tables]

proc main() =
  echo "=== Hierarchical Memory Library Example ==="
  
  # Create memory instance
  let memory = newHierarchicalMemory("./example_data")
  echo fmt"Initialized memory system. Current entries: {memory.len}"
  
  # Add some memories
  echo "\n--- Adding Memories ---"
  let projectId = memory.add(
    "Q1 Product Launch Project", 
    LongTerm, 
    @["work", "project", "important"]
  )
  echo fmt"Added project memory: {projectId}"
  
  let meetingId = memory.add(
    "Team standup meeting at 9 AM",
    ShortTerm,
    @["work", "meeting", "daily"],
    some(projectId)  # Child of project
  )
  echo fmt"Added meeting memory: {meetingId}"
  
  let taskId = memory.add(
    "Review product specifications",
    MediumTerm,
    @["work", "review", "specs"],
    some(projectId)  # Another child of project
  )
  echo fmt"Added task memory: {taskId}"
  
  let personalId = memory.add(
    "Call dentist for appointment",
    ShortTerm,
    @["personal", "health", "todo"]
  )
  echo fmt"Added personal memory: {personalId}"
  
  echo fmt"Total memories: {memory.len}"
  
  # Demonstrate retrieval and access tracking
  echo "\n--- Retrieving Memories ---"
  let retrieved = memory.get(projectId)
  if retrieved.isSome:
    let entry = retrieved.get
    echo fmt"Retrieved: {entry.content}"
    echo fmt"Level: {entry.level}, Tags: {entry.tags}"
    echo fmt"Access count: {entry.accessCount}, Created: {entry.createdAt}"
  
  # Search by tags
  echo "\n--- Search by Tags ---"
  let workMemories = memory.searchByTags(@["work"])
  echo fmt"Found {workMemories.len} work-related memories:"
  for mem in workMemories:
    echo fmt"  - {mem.content} ({mem.level})"
  
  # Search by content
  echo "\n--- Search by Content ---"
  let meetingResults = memory.searchByContent("meeting")
  echo fmt"Found {meetingResults.len} memories containing 'meeting':"
  for mem in meetingResults:
    echo fmt"  - {mem.content}"
  
  # Get memories by level
  echo "\n--- Memories by Level ---"
  let shortTermMemories = memory.getByLevel(ShortTerm)
  echo fmt"Short-term memories ({shortTermMemories.len}):"
  for mem in shortTermMemories:
    echo fmt"  - {mem.content}"
  
  # Demonstrate hierarchical navigation
  echo "\n--- Hierarchical Navigation ---"
  let children = memory.getChildren(projectId)
  echo fmt"Children of project ({children.len}):"
  for child in children:
    echo fmt"  - {child.content} ({child.level})"
  
  let roots = memory.getRoots()
  echo fmt"Root-level memories ({roots.len}):"
  for root in roots:
    echo fmt"  - {root.content}"
  
  # Update a memory
  echo "\n--- Updating Memory ---"
  let updated = memory.update(
    taskId, 
    content = some("Review and approve product specifications"),
    level = some(LongTerm)
  )
  if updated:
    echo "Successfully updated task memory"
    let updatedEntry = memory.get(taskId).get
    echo fmt"New content: {updatedEntry.content}"
    echo fmt"New level: {updatedEntry.level}"
  
  # Show hierarchy structure
  echo "\n--- Hierarchy Structure ---"
  let hierarchy = memory.getHierarchy()
  for parentId, childIds in hierarchy.pairs:
    if childIds.len > 0:
      let parent = memory.get(parentId)
      if parent.isSome:
        echo fmt"{parent.get.content}:"
        for childId in childIds:
          let child = memory.get(childId)
          if child.isSome:
            echo fmt"  └─ {child.get.content}"
  
  # Demonstrate deletion
  echo "\n--- Deletion Example ---"
  echo fmt"Before deletion: {memory.len} memories"
  let deleted = memory.delete(personalId)
  if deleted:
    echo fmt"Deleted personal memory. After deletion: {memory.len} memories"
  
  echo "\n=== Example Complete ==="

when isMainModule:
  main()