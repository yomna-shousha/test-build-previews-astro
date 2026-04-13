#!/bin/bash
# Smart deploy script: checks if the current merge came from a gradual branch.
# If yes: only upload a version (deployer workflow handles gradual rollout).
# If no: normal wrangler deploy to 100%.

set -e

# Get the merge commit message (Builds sets this via git)
COMMIT_MSG=$(git log -1 --pretty=%B 2>/dev/null || echo "")

echo "Commit message: $COMMIT_MSG"

# Check if this merge came from a gradual branch
SHOULD_GRADUAL="false"

if [ -f rollout.json ]; then
  PATTERNS=$(jq -r '.gradual_branches[]' rollout.json 2>/dev/null || echo "")

  for PATTERN in $PATTERNS; do
    # Convert glob to regex
    REGEX="$(echo "$PATTERN" | sed 's/\*/[^ ]*/g')"

    # Check if the commit message references a branch matching the pattern
    # Merge commits look like: "Merge pull request #N from user/gradual-test-rollout"
    if echo "$COMMIT_MSG" | grep -qiE "$REGEX"; then
      SHOULD_GRADUAL="true"
      echo "Matched gradual pattern '$PATTERN' in commit message."
      break
    fi
  done
fi

if [ "$SHOULD_GRADUAL" = "true" ]; then
  echo "Gradual branch detected. Uploading version only (GitHub Actions deployer handles rollout)."
  npx wrangler versions upload --message "gradual: $COMMIT_MSG"
else
  echo "Normal branch. Deploying to 100%."
  npx wrangler deploy
fi
