---
name: gg-review
description: Writes the blog posts of the ticket, opens the pull requests with `gg do review` and reviews the changes. Use when the user says "/gg-review" or asks to review the current ticket.
---

# Review

Each repo documents its change first, so the documentation lands in the
pull requests and is reviewed with the code. Every commit after
`gg do review` voids the review.

## 1. Document the change in every repo

Look for `doc/guides/blog-guide.md` in every repo of the ticket, the
project management repo included. It comes from the `dna_blog` layer.

- Run `/blog` in each repo that has it; skip the others
- `/blog` stops by itself when the post already exists

Update `index.jsonc` and `README.md` of each repo the ticket changed.

Let the user review the changes, then run `/gg-commit` and `/gg-push`.

## 2. Open the pull requests

Let the user confirm that the review phase is started. From the ticket
folder:

```bash
gg do review
```

gg creates a pull request for each repo and prints the URLs to the
terminal.

## 3. Review the changes

Load the `/review-light` skill and execute it.

A fix goes through `/gg-commit` and `/gg-push`, then run `gg do review`
again. Update the blog post of the repo when the fix changes what it
describes.

## Important

- Never write a blog post in a repo without `doc/guides/blog-guide.md`.
- Never start `gg do review` without the user's confirmation.
