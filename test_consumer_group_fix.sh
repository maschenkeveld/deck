#!/bin/bash

# Test script to demonstrate the consumer-group association issue and fix

set -e

echo "=== Consumer Group Association Issue Test ==="
echo

# Setup test files
mkdir -p test_data

# Create consumer group
cat > test_data/group.yaml << 'EOF'
_format_version: "3.0"
consumer_groups:
- name: foo
  tags:
  - foo
EOF

# Create user1 configuration
cat > test_data/user1.yaml << 'EOF'
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
  tags:
  - user1
  groups:
  - name: foo
EOF

# Create user2 configuration
cat > test_data/user2.yaml << 'EOF'
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
  tags:
  - user2
  groups:
  - name: foo
EOF

echo "1. Creating consumer group..."
deck gateway sync test_data/group.yaml

echo "2. Adding user1..."
deck gateway sync test_data/user1.yaml

echo "3. Adding user2 WITHOUT preserve flag (will delete user1 association)..."
echo "Expected: deleting consumer-group-consumer user1"
deck gateway sync test_data/user2.yaml

echo "4. Re-adding user1..."
deck gateway sync test_data/user1.yaml

echo "5. Adding user2 WITH preserve flag (should NOT delete user1 association)..."
echo "Expected: No deletions"
deck gateway sync test_data/user2.yaml --preserve-consumer-group-associations

echo "6. Cleanup..."
deck gateway reset --yes

rm -rf test_data

echo "=== Test Complete ==="
echo
echo "The --preserve-consumer-group-associations flag prevents deletion of"
echo "consumer-group associations when using select tags with distributed configs."
