# Consumer Group Association Issue with Select Tags

## Problem Description

When using `select_tags` with consumer-group associations, decK incorrectly deletes consumer-group-consumer associations for consumers that are not included in the current sync operation due to tag filtering.

### Root Cause

The issue occurs because:

1. **Tag-based filtering is applied to consumer-group-consumer associations**
2. **When syncing with `select_tags`**, only consumers with matching tags are considered in the target state
3. **However, the current state from Kong includes ALL consumer-group associations** (regardless of consumer tags)
4. **This creates a mismatch**: associations that exist in Kong but aren't in the filtered target state get marked for deletion

### Example Scenario

```yaml
# Step 1: Create consumer group
# group.yaml
_format_version: "3.0"
consumer_groups:
- name: foo
  tags:
  - foo

# Step 2: Add user1 with tag user1
# user1.yaml
_format_version: "3.0"
_info:
  default_lookup_tags:
    consumer_groups:
      - foo  
  select_tags:
  - user1
consumers:
- custom_id: user1
  username: user1
  groups:
  - name: foo
    tags:
    - foo

# Step 3: Add user2 with tag user2 (PROBLEM HERE)
# user2.yaml
_format_version: "3.0"
_info:
  default_lookup_tags:
    consumer_groups:
      - foo  
  select_tags:
  - user2
consumers:
- custom_id: user2
  username: user2
  groups:
  - name: foo
    tags:
    - foo
```

When syncing `user2.yaml`, decK:
1. Fetches current state (includes user1 → foo association)
2. Processes target state with `select_tags: [user2]` (only includes user2 → foo association)
3. Sees user1 → foo association in current state but not in target state
4. **Incorrectly deletes the user1 → foo association**

## Solutions

### Solution 1: Use the new `--preserve-consumer-group-associations` flag

```bash
deck gateway sync user2.yaml --preserve-consumer-group-associations
```

This flag works by automatically enabling `--skip-consumers-with-consumer-groups` during the dump phase when using select tags. This prevents decK from fetching consumer-group associations from Kong that would be incorrectly marked for deletion due to tag filtering.

**How it works:**
1. When `--preserve-consumer-group-associations` is used with `select_tags`
2. decK automatically enables `--skip-consumers-with-consumer-groups` during dump
3. This prevents fetching existing consumer-group associations that aren't part of the current operation
4. Only consumer-group associations explicitly defined in your config files are managed
5. Existing associations for other consumers remain untouched

### Solution 2: Avoid distributed consumer-group configurations

Instead of having separate files for each consumer, use a single file that includes all consumers for a consumer group:

```yaml
_format_version: "3.0"
_info:
  default_lookup_tags:
    consumer_groups:
      - foo  
  select_tags:
  - user1
  - user2
consumers:
- custom_id: user1
  username: user1
  groups:
  - name: foo
- custom_id: user2
  username: user2
  groups:
  - name: foo
```

### Solution 3: Use workspace-level tags instead of entity-level tags

Organize consumers by workspaces instead of tags to avoid the filtering issue entirely.

### Solution 4: Use separate consumer-group management

Manage consumer-group definitions separately from consumer definitions:

```yaml
# consumer-groups.yaml
_format_version: "3.0"
consumer_groups:
- name: foo
  consumers:
  - username: user1
  - username: user2

# consumers.yaml (without groups section)
_format_version: "3.0"
_info:
  select_tags:
  - user1
consumers:
- custom_id: user1
  username: user1
```

## Implementation Details

The fix adds a new flag `--preserve-consumer-group-associations` to the sync, diff, and apply commands that:

1. **Automatically enables `--skip-consumers-with-consumer-groups`** when used with select tags
2. **Prevents fetching consumer-group associations** during the dump phase that aren't part of the current operation
3. **Only manages explicitly defined associations** in your configuration files
4. **Preserves existing associations** for consumers not being managed in the current operation
5. **Works with consumer group plugins** and other advanced features

**Key insight:** The solution works by changing what gets dumped from Kong, rather than trying to filter after the fact. This is much cleaner and more reliable.

### Technical Details

When `--preserve-consumer-group-associations` is used:

```go
if preserveConsumerGroupAssociations && len(dumpConfig.SelectorTags) > 0 {
    // Enable skipping consumers with consumer groups during dump to avoid fetching
    // consumer-group associations that would be incorrectly marked for deletion
    dumpConfig.SkipConsumersWithConsumerGroups = true
}
```

This prevents the dump operation from fetching consumer-group associations that exist in Kong but aren't part of the current tag-filtered operation.

## Best Practices

1. **Use consistent tagging strategies** across consumer and consumer-group configurations
2. **Test configurations** with `deck gateway diff` before applying
3. **Use the preserve flag** when working with distributed consumer configurations
4. **Consider using lookup tags** for complex scenarios involving multiple files
5. **Monitor associations** after sync operations to ensure expected state

## Future Improvements

1. **Enhanced tag filtering logic** that understands entity relationships
2. **Automatic detection** of distributed consumer-group scenarios
3. **Better warning messages** when potential association conflicts are detected
4. **Dry-run mode improvements** to show association changes more clearly
