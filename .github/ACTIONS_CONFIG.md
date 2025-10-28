# GitHub Actions Configuration Guide

## Required Secrets Configuration

Add the following secrets in GitHub repository settings:

### 1. Discord Notifications (Optional)
- `DISCORD_WEBHOOK`: Discord Webhook URL (for release notifications)

### 2. Code Coverage (Optional)
- `CODECOV_TOKEN`: Codecov access token

## Permission Settings

Enable the following permissions in repository settings:

### 1. Actions Permissions
- Allow Actions to create and approve pull requests
- Allow Actions to access repository content

### 2. Packages Permissions
- Allow Actions to publish packages

## Workflow Descriptions

### 1. CI/CD Pipeline (`ci.yml`)
- **Trigger**: Push to main/develop branches, PR, manual trigger
- **Features**: Code quality checks, build, test, security scan
- **Runtime**: ~8-12 minutes

### 2. PR Checks (`pr-checks.yml`)
- **Trigger**: Create/update PR
- **Features**: Code format checks, commit message checks, coverage tests, performance benchmarks
- **Runtime**: ~5-8 minutes

### 3. Release (`release.yml`)
- **Trigger**: Create version tag, manual trigger
- **Features**: Multi-platform binary builds, GitHub Release creation
- **Runtime**: ~10-15 minutes

## Usage Guide

### 1. Development Workflow
```bash
# Create feature branch
git checkout -b feature/new-feature

# Develop and commit (follow conventional commits)
git commit -m "feat: add new feature"

# Push and create PR
git push origin feature/new-feature
```

### 2. Release Workflow
```bash
# Create version tag
git tag v1.0.0
git push origin v1.0.0

# Or trigger release manually
# Go to GitHub Actions page -> "Release & Deploy" -> "Run workflow"
```

### 3. Monitoring and Debugging
- View Actions status: GitHub repository -> Actions tab
- View build logs: Click on specific workflow run
- View test coverage: Codecov integration
- View security scan results: GitHub Security tab

## Custom Configuration

### 1. Modify Go Version
Change `GO_VERSION` environment variable in workflow files:
```yaml
env:
  GO_VERSION: '1.24'  # Update to new version
```

### 2. Add New Tests
Add new test commands in the test job of `ci.yml`:
```yaml
- name: Run custom tests
  run: go test -v ./custom-tests/...
```

### 3. Modify Build Targets
Add new build targets in `release.yml`:
```yaml
# Add new architecture
- GOOS=linux GOARCH=arm go run build/ci.go install
```

## Troubleshooting

### 1. Build Failures
- Check Go version compatibility
- Verify dependencies are correct
- Check if tests pass

### 2. Release Failures
- Check version tag format
- Confirm sufficient permissions