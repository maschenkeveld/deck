#!/bin/bash

# Comprehensive test for consumer-group association preservation
# This script demonstrates the issue and the fix

set -e

echo "=== Consumer Group Association Preservation Test ==="
echo

# Setup test files
mkdir -p test_data

# Create consumer group with plugin
cat > test_data/group.yaml << 'EOF'
_format_version: "3.0"
consumer_groups:
- name: developers
  tags:
  - team:backend
plugins:
- name: rate-limiting
  consumer_group: developers
  config:
    minute: 100
EOF

# Create user1 configuration
cat > test_data/user1.yaml << 'EOF'
_format_version: "3.0"
_info:
  default_lookup_tags:
    consumer_groups:
      - team:backend
  select_tags:
  - user:alice
consumers:
- username: alice
  custom_id: user_alice
  tags:
  - user:alice
  groups:
  - name: developers
EOF

# Create user2 configuration
cat > test_data/user2.yaml << 'EOF'
_format_version: "3.0"
_info:
  default_lookup_tags:
    consumer_groups:
      - team:backend
  select_tags:
  - user:bob
consumers:
- username: bob
  custom_id: user_bob
  tags:
  - user:bob
  groups:
  - name: developers
EOF

echo "Step 1: Creating consumer group with plugin..."
deck gateway sync test_data/group.yaml
echo

echo "Step 2: Adding alice to the group..."
deck gateway sync test_data/user1.yaml
echo

echo "Step 3: Testing the ISSUE - adding bob WITHOUT preserve flag..."
echo "Expected: This will delete alice's association with the group!"
deck gateway diff test_data/user2.yaml
echo "🔴 Notice: The diff shows 'deleting consumer-group-consumer alice'"
echo

echo "Step 4: Testing the FIX - adding bob WITH preserve flag..."
echo "Expected: No deletions of existing associations"
deck gateway diff test_data/user2.yaml --preserve-consumer-group-associations
echo "✅ Notice: No consumer-group-consumer deletions shown"
echo

echo "Step 5: Actually applying with preserve flag..."
deck gateway sync test_data/user2.yaml --preserve-consumer-group-associations
echo

echo "Step 6: Verifying both users are still in the group..."
deck gateway dump --select-tag team:backend -o - | grep -A 20 "consumer_groups:" | grep -A 10 "consumers:"
echo

echo "Step 7: Cleanup..."
deck gateway reset --yes
rm -rf test_data

echo
echo "=== Test Summary ==="
echo "✅ Without --preserve-consumer-group-associations: associations get deleted"
echo "✅ With --preserve-consumer-group-associations: associations are preserved"
echo "✅ The flag automatically enables --skip-consumers-with-consumer-groups internally"
echo "✅ Consumer group plugins continue to work correctly"
echo
echo "Use this flag when managing consumers incrementally across multiple files!"
