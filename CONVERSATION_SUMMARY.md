# Consumer Group Association Issue - Complete Solution

**Date:** July 26, 2025  
**Issue:** Consumer-group associations get deleted when using select tags with distributed configurations

## Problem Description

When using `select_tags` with consumer-group configurations split across multiple files, decK incorrectly deletes consumer-group associations for consumers not included in the current sync operation.

### Example Scenario
```yaml
# Step 1: Create consumer group
deck gateway sync group.yaml

# Step 2: Add user1 with tag filtering
deck gateway sync user1.yaml  # select_tags: [user1]

# Step 3: Add user2 with tag filtering  
deck gateway sync user2.yaml  # select_tags: [user2]
# ❌ PROBLEM: This deletes user1's association with the consumer group
```

### Root Cause
1. Current state dump includes ALL consumer-group associations from Kong
2. Target state only includes associations for tag-filtered consumers
3. Diff engine sees existing associations as "to be deleted" since they're not in filtered target state
4. Results in unwanted deletion of consumer-group associations

## Solution Implemented

### New Flag: `--preserve-consumer-group-associations`

Added to `gateway sync`, `gateway diff`, and `gateway apply` commands.

**How it works:**
- Automatically enables `--skip-consumers-with-consumer-groups` during dump when used with select tags
- Changes what gets fetched from Kong to avoid the mismatch entirely  
- Only manages associations explicitly defined in your config files
- Preserves all other existing associations automatically

### Usage Examples

```bash
# Safe incremental consumer management
deck gateway sync user2.yaml --preserve-consumer-group-associations
deck gateway diff user2.yaml --preserve-consumer-group-associations
deck gateway apply user2.yaml --preserve-consumer-group-associations
```

### Files Modified

1. **`cmd/gateway_sync.go`**
   - Added `preserveConsumerGroupAssociations` variable
   - Added flag definition with comprehensive help text
   - Updated `executeSync()` to pass the flag to `syncMain()`

2. **`cmd/gateway_diff.go`**
   - Added the same flag for consistency
   - Updated `executeDiff()` function

3. **`cmd/gateway_apply.go`**
   - Added the same flag for consistency  
   - Updated `executeApply()` function

4. **`cmd/common.go`**
   - Updated `syncMain()` signature to accept the new parameter
   - Added logic to enable `SkipConsumersWithConsumerGroups` when preserving associations
   - Added helper functions (placeholders for future enhancements)

### Key Code Changes

#### syncMain() Function Enhancement
```go
func syncMain(ctx context.Context, filenames []string, dry bool, parallelism,
	delay int, workspace string, enableJSONOutput bool, applyType ApplyType, preserveConsumerGroupAssociations bool,
) error {
	// ...existing code...
	
	if preserveConsumerGroupAssociations && len(dumpConfig.SelectorTags) > 0 {
		// Enable skipping consumers with consumer groups during dump to avoid fetching
		// consumer-group associations that would be incorrectly marked for deletion
		dumpConfig.SkipConsumersWithConsumerGroups = true
	}
	
	// ...rest of function...
}
```

#### Flag Definition Example
```go
syncCmd.Flags().BoolVar(&preserveConsumerGroupAssociations, "preserve-consumer-group-associations",
	false, "preserve existing consumer-group associations when using select tags.\n"+
		"This automatically enables --skip-consumers-with-consumer-groups during sync\n"+
		"to prevent deletion of consumer-group-consumer associations for consumers\n"+
		"not included in the current sync operation due to tag filtering.\n"+
		"Use this when managing consumers incrementally across multiple files.")
```

## Testing

### Test Script Created
- `test_preserve_associations.sh` - Comprehensive test demonstrating the issue and fix
- Shows behavior with and without the flag
- Includes consumer group plugins to test complex scenarios

### Test Cases
1. ✅ Without flag: associations get deleted (demonstrates the problem)
2. ✅ With flag: associations are preserved (demonstrates the fix)
3. ✅ Consumer group plugins continue working correctly
4. ✅ Tag filtering still works as expected for other entities

## Documentation

### Files Created
1. **`docs/consumer-group-association-issue.md`** - Comprehensive documentation
2. **`test_preserve_associations.sh`** - Working test script
3. **This conversation summary** - Complete solution overview

### Alternative Solutions Documented
1. **Single file approach**: Keep all consumers in one file
2. **Workspace separation**: Use workspaces instead of tags  
3. **Separate management**: Manage groups and consumers independently
4. **Enhanced tagging**: Use consistent tagging strategies

## Benefits of This Solution

✅ **Safe incremental updates** across multiple files  
✅ **Backward compatible** - flag is optional and disabled by default  
✅ **Works with consumer group plugins** and advanced features  
✅ **Simple implementation** that changes dump behavior rather than complex filtering  
✅ **Clear user control** over the behavior  
✅ **Consistent across all relevant commands** (sync, diff, apply)  

## How to Use

For distributed consumer-group configurations with select tags:

```bash
# Instead of this (which causes deletions):
deck gateway sync user2.yaml

# Use this (which preserves existing associations):
deck gateway sync user2.yaml --preserve-consumer-group-associations
```

## Technical Notes

- The solution works by modifying the dump configuration rather than post-processing
- It leverages existing `--skip-consumers-with-consumer-groups` functionality
- No changes needed to the core go-database-reconciler package
- Maintains all existing functionality while fixing the edge case

## Future Enhancements

Potential improvements that could be made:
1. Enhanced tag filtering logic that understands entity relationships
2. Automatic detection of distributed consumer-group scenarios
3. Better warning messages when potential association conflicts are detected
4. Dry-run mode improvements to show association changes more clearly

---

**Summary:** This solution effectively resolves the consumer-group association deletion issue when using select tags with distributed configurations, providing users with a simple flag to preserve existing associations while managing consumers incrementally across multiple files.
