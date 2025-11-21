# Registration Instructions for OLSPlots.jl

This document provides step-by-step instructions for registering OLSPlots.jl with the Julia General Registry.

## Pre-Registration Checklist

Before registering, ensure the following are complete:

- [x] Package has a valid `Project.toml` with proper metadata
- [x] Package has a unique UUID
- [x] Package has proper version number (0.1.0 for initial registration)
- [x] Package has a LICENSE file (MIT)
- [x] Package has a README.md with installation and usage instructions
- [x] Package has tests (test/runtests.jl)
- [x] Package has GitHub Actions workflows (CI, TagBot, CompatHelper)
- [x] All compat entries are specified in Project.toml
- [x] Code is pushed to GitHub
- [ ] Tests pass on CI (after fixing Julia version compatibility)
- [ ] Documentation builds successfully

## Known Issues

### Julia Version Compatibility

There is currently a compatibility issue with CairoMakie v0.13.5 and Julia 1.12.0. The package works with Julia 1.6-1.11.

**Recommendation**: Update dependencies to support Julia 1.12, or explicitly limit Julia compatibility to `julia = "1.6, 1.11"` in Project.toml until CairoMakie releases a compatible version.

To resolve dependencies for Julia 1.11:
```bash
julia +1.11 --project=. -e 'using Pkg; Pkg.resolve(); Pkg.test()'
```

## Registration Steps

### 1. Commit and Push All Changes

```bash
cd /Users/technocrat/projects/OLSPlots.jl
git add .
git commit -m "Prepare package for registration

- Add CI, TagBot, and CompatHelper workflows
- Fix Project.toml compat entries
- Update documentation
"
git push origin main
```

### 2. Create a Git Tag (Optional but Recommended)

```bash
git tag -a v0.1.0 -m "Release version 0.1.0"
git push origin v0.1.0
```

### 3. Register with JuliaRegistrator

There are two ways to register:

#### Option A: Via GitHub Comment (Recommended)

1. Go to your repository: https://github.com/technocrat/OLSPlots.jl
2. Create a new issue or comment on an existing one
3. Post the following comment:

```
@JuliaRegistrator register
```

JuliaRegistrator will:
- Validate your package
- Create a pull request to the General registry
- Notify you of any issues

#### Option B: Via GitHub Web Interface

1. Go to https://github.com/JuliaRegistries/Registrator.jl
2. Click "Use this template" or follow the web registration instructions
3. Enter your repository URL: `https://github.com/technocrat/OLSPlots.jl`
4. Submit the registration request

### 4. Wait for Automated Checks

JuliaRegistrator will automatically:
- Check package structure
- Verify Project.toml validity
- Run AutoMerge checks
- Test package installation

### 5. Address Any Issues

If JuliaRegistrator finds issues, it will comment on your pull request with details. Common issues:

- **Compat entries missing**: Ensure all dependencies have compat bounds in Project.toml
- **Tests failing**: Fix any test failures indicated by CI
- **Name conflicts**: Choose a different package name if needed
- **Version issues**: Ensure version number follows SemVer

### 6. Approval and Merging

- If all checks pass, your PR will be automatically merged (usually within 20 minutes)
- If manual review is needed, a Julia ecosystem member will review
- Once merged, your package will be available in the General registry

## Post-Registration

### 1. Verify Registration

After merge, verify your package is registered:

```julia
using Pkg
Pkg.add("OLSPlots")
using OLSPlots
```

### 2. Update Documentation

If you have documentation hosted elsewhere, update links to reference the registered package name.

### 3. Announce Release

Consider announcing your release:
- Julia Discourse: https://discourse.julialang.org/
- Julia Slack/Zulip
- Social media with #JuliaLang hashtag

## Subsequent Releases

For future releases:

1. Update version number in `Project.toml`
2. Create and push a git tag: `git tag v0.1.1 && git push origin v0.1.1`
3. TagBot will automatically create a GitHub release
4. Comment `@JuliaRegistrator register` to register the new version

## Troubleshooting

### Registration Fails

- Check CI status on GitHub
- Review JuliaRegistrator comments for specific issues
- Consult the Julia package registration documentation: https://github.com/JuliaRegistries/Registrator.jl

### Tests Pass Locally But Fail on CI

- Ensure all dependencies are properly specified in `Project.toml`
- Check for platform-specific issues
- Review CI logs for detailed error messages

### CompatHelper PRs

- CompatHelper will create PRs to update dependency bounds
- Review and merge these PRs regularly
- Run tests locally before merging

## Resources

- Julia Package Registration: https://github.com/JuliaRegistries/Registrator.jl
- Julia Package Development: https://pkgdocs.julialang.org/
- Julia Discourse: https://discourse.julialang.org/
- General Registry: https://github.com/JuliaRegistries/General

## Contact

For questions or issues:
- Open an issue on the repository
- Ask on Julia Discourse
- Contact package author via issue tracker
