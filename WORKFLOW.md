# GitHub Achievement Workflow

To maximize GitHub achievements, here's how to work with branches and PRs:

## For Pull Shark Achievement (Multiple Merged PRs)

1. Create a feature branch:
```bash
git checkout -b feature/your-feature-name
```

2. Make your changes and commit:
```bash
git add .
git commit -m "feat: your feature description"
```

3. Push the branch:
```bash
git push -u origin feature/your-feature-name
```

4. Create a PR on GitHub:
```bash
gh pr create --title "Add your feature" --body "Description of changes"
```

5. Merge it (this counts toward Pull Shark):
```bash
gh pr merge --merge
```

## Example Feature Ideas

- Add keyboard shortcuts
- Create a config wizard
- Add batch import from CSV
- Create a TUI (text user interface)
- Add Spotify integration
- Create playlist export
- Add genre statistics
- Create listening streak tracker

## Other Achievement Tips

**Starstruck** (16+ stars): Share your repo on Reddit, Hacker News, or social media
**Pair Extraordinaire**: Collaborate via co-authored commits
**Galaxy Brain**: Already unlocked (GitHub Actions)
**Arctic Code Vault**: Already unlocked (public repo)

Create branches, make PRs, merge them - each merge counts!
