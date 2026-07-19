# Git Flow for Project Context Tool

## Branch model

- `main` stores stable release-ready history.
- `develop` is the main integration branch.
- `feature/*` branches start from `develop`.
- `release/*` branches prepare a versioned release from `develop`.
- `hotfix/*` branches start from `main` to repair production issues.

## Feature workflow

1. Create a feature branch from `develop`.
2. Commit changes to the feature branch.
3. Push the branch to origin.
4. Open a pull request into `develop`.
5. Merge after review and passing CI.

## Release workflow

1. Create `release/x.y.z` from `develop`.
2. Freeze release content and run validation.
3. Merge release into `main`.
4. Tag the release.
5. Merge release back into `develop`.

## Hotfix workflow

1. Create `hotfix/x.y.z` from `main`.
2. Apply the production fix.
3. Merge into `main`.
4. Merge the same hotfix into `develop`.

## CI rules

- Every push to `main`, `develop`, `feature/*`, `release/*`, and `hotfix/*` runs CI.
- Every pull request into `main` or `develop` runs CI.
- Pester is the default test framework for repository automation and script validation.
