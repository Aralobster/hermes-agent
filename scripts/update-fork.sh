#!/bin/bash
# Syncs fix/docker-matrix-update with upstream/main, keeping custom commits on top.
# Detects which custom changes are already present upstream by inspecting Dockerfile content.
# Usage: ./update-fork.sh

set -e

BRANCH="fix/docker-matrix-update"
UPSTREAM="upstream"
ORIGIN="aralobster"

echo "=== Updating $BRANCH from $UPSTREAM/main ==="

# Make sure we're on the right branch
git checkout "$BRANCH"

# Fetch latest upstream
git fetch "$UPSTREAM" main

# Check if playwright is already properly installed in upstream's Dockerfile
# (the single-stage approach uses: npx playwright install --with-deps chromium)
UPSTREAM_DOCKERFILE=$(git show "${UPSTREAM}/main:Dockerfile" 2>/dev/null)
if echo "$UPSTREAM_DOCKERFILE" | grep -q "playwright install"; then
    PLAYWRIGHT_IN_UPSTREAM=true
    echo "✓ playwright: already in upstream"
else
    PLAYWRIGHT_IN_UPSTREAM=false
    echo "✗ playwright: NOT in upstream (will add)"
fi

# Check if markdown is installed with --break-system-packages (required for single-stage Dockerfile)
# The old two-stage had "markdown" but without --break-system-packages in the runtime stage
if echo "$UPSTREAM_DOCKERFILE" | grep -q "pip install.*markdown.*--break-system-packages"; then
    MARKDOWN_IN_UPSTREAM=true
    echo "✓ markdown: already in upstream with --break-system-packages"
elif echo "$UPSTREAM_DOCKERFILE" | grep -q "pip install.*markdown"; then
    # Present but without --break-system-packages — still needs fixing
    MARKDOWN_IN_UPSTREAM=false
    echo "✗ markdown: present but missing --break-system-packages (will fix)"
else
    MARKDOWN_IN_UPSTREAM=false
    echo "✗ markdown: NOT in upstream (will add)"
fi

# Check if matrix extras are installed (matrix-nio[e2e] for Matrix messaging platform)
# Matrix can be either in the main pip install (.[all,matrix]) or a separate pip install line
if echo "$UPSTREAM_DOCKERFILE" | grep -q 'matrix-nio\|"\[all,matrix\]\|"' 2>/dev/null; then
    MATRIX_IN_UPSTREAM=true
    echo "✓ matrix: already in upstream"
else
    MATRIX_IN_UPSTREAM=false
    echo "✗ matrix: NOT in upstream (will add)"
fi

# Check if uv is installed (needed for MCP uvx command)
if echo "$UPSTREAM_DOCKERFILE" | grep -q "uv$"; then
    UV_IN_UPSTREAM=true
    echo "✓ uv: already in upstream"
else
    UV_IN_UPSTREAM=false
    echo "✗ uv: NOT in upstream (will add)"
fi

# Reset to upstream/main
git reset --hard "${UPSTREAM}/main"

# Apply playwright if missing
if [ "$PLAYWRIGHT_IN_UPSTREAM" = false ]; then
    echo "Adding playwright..."
    # Add after the main pip install line (any variant of it)
    sed -i '/pip install -e ".*" --break-system-packages/a\RUN npm install\nRUN npx playwright install --with-deps chromium' Dockerfile
fi

# Apply markdown if missing or incomplete
if [ "$MARKDOWN_IN_UPSTREAM" = false ]; then
    echo "Adding markdown..."
    # Add markdown pip install after the main pip install line
    sed -i '/pip install -e ".*" --break-system-packages/a\RUN pip install --no-cache-dir --break-system-packages markdown' Dockerfile
fi

# Apply matrix if missing
if [ "$MATRIX_IN_UPSTREAM" = false ]; then
    echo "Adding matrix..."
    # Upgrade existing [all] or [all,matrix] if matrix not present
    # Try to add matrix to the extras list
    if grep -q 'pip install -e "\.\[all\]"' Dockerfile; then
        sed -i 's/pip install -e "\.\[all\]"/pip install -e ".[all,matrix]"/' Dockerfile
    elif ! grep -q 'matrix-nio' Dockerfile; then
        # No [all] line found and no matrix-nio — add a separate line
        sed -i '/pip install -e ".*" --break-system-packages/a\RUN pip install --no-cache-dir --break-system-packages "matrix-nio[e2e]"' Dockerfile
    fi
fi

# Apply uv if missing (needed for MCP uvx command)
if [ "$UV_IN_UPSTREAM" = false ]; then
    echo "Adding uv..."
    sed -i '/pip install -e ".*" --break-system-packages/a\RUN pip install --no-cache-dir --break-system-packages uv' Dockerfile
fi

# Commit changes if any were made
if ! git diff --quiet; then
    git add Dockerfile
    git commit -m "fix(docker): add missing dependencies for single-stage Dockerfile"
fi

# Force push to origin
echo ""
echo "=== Force-pushing to $ORIGIN/$BRANCH ==="
git push --force "$ORIGIN" "$BRANCH"

echo ""
echo "Done. $BRANCH is now at:"
git log --oneline -1 HEAD
