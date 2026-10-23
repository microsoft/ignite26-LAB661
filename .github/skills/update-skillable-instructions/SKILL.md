---
name: update-skillable-instructions
description: 'Create and maintain the Skillable lab instruction files in instructions/skillable/ using Skillable Markdown syntax. Use when: adding, editing, reordering, or reviewing Skillable lab modules; rebuilding the README.md manual that gets pasted into Skillable or synced from GitHub; checking Skillable syntax (page breaks, blocks, copyable text, tokens, images).'
---

# Update Skillable instructions

Maintain `instructions/skillable/`: authored module files and one assembled `README.md`. The owner copies `README.md` into Skillable Studio (or points the GitHub instructions source at it) to get the paged manual.

Reference docs (only fetch when syntax is in doubt; append `.md` for plain Markdown):
- https://docs.skillable.com/docs/creating-instructions-with-markdown-syntax
- https://docs.skillable.com/docs/instructions-writing-best-practices
- https://docs.skillable.com/docs/github-instructions-source

## How Skillable consumes this folder

- A lab profile uses exactly one Markdown file, either pasted into Studio or synced from the repo's default branch. Other files are imported but not managed. Here that file is `README.md`.
- Any commit to the default branch triggers a sync. Studio is read-only unless "Edit Locally" is on.
- Images must sit next to that file or in a folder beside it. Use `media/`.
- GitHub previews do not render Skillable-only syntax (blocks, tokens, copyable text). Check the rendering in Skillable, not GitHub.
- Repo size limit is 500 MB. Keep videos out of the repo.

## Folder layout

```text
instructions/skillable/
  README.md        generated manual: the one file pasted into Skillable or synced from GitHub
  00-intro.md      authored modules, one per lab page group, numeric prefix sets order
  01-<slug>.md
  media/           images used by the modules
```

Modules are the source of truth. Never edit `README.md` by hand.

## Workflow

1. Read the module list in the header comment of `README.md` and the existing `NN-*.md` files to learn the current list and order.
2. Create, edit, rename, or delete module files as requested. Keep prefixes contiguous (`00`, `01`, ...) and slugs lowercase with hyphens.
3. Rebuild `README.md`: concatenate modules in numeric order, with a line containing only `===` between modules.
4. Start `README.md` with an HTML comment that says it is generated, lists the module files in order (one per line, with title and estimated minutes), and tells the owner to copy everything below the comment into Skillable. Skillable ignores HTML comments, so copying the whole file is safe.
5. Run the checklist below and fix failures before finishing.

Skillable has no include for relative paths. If a module must stay a separate synced source, use `[!include [label](raw-github-url)]` instead and confirm with the owner first, because it pins to a branch and the repo must be public.

## Module shape

Each module is one page group and follows the lab pedagogy: try, break, fix, aha.

```markdown
# Fix the retrieval step

One sentence stating the outcome the attendee will see.

## Make the change

1. [] In the terminal, run the command that applies the change.
1. [] Run ++python src/eval.py++ and note the score.

## Watch it break

1. [] Run the second command and compare the score.

> [+Hint] Look at the trace for the failing case.
>
> Open the span named `retrieve` and compare its input to the expected one.

## Fix it and see why

1. [] Apply the fix and rerun the evaluation.

> [!Knowledge] Why this happened: one or two sentences giving the aha.

> [!Note] Win: state the visible result, for example the new score.
```

Rules:
- Start each module with `# ` heading, 40 characters or fewer, verb first, sentence case, no period. It labels the Next button.
- One sentence per step. Order each step as where, what, why.
- Numbered steps use `1.` for every item. Add `[]` for a progress checkbox on actions the attendee performs.
- Indent blocks that sit between steps to the same level as the step before them.
- Attendee-facing, simple, conversational language. No fabricated results, links, or scores.
- Never give away the fix in the main text of the break step. Put help in hint blocks.
- Every module ends with a visible win.

## Syntax quick reference

| Need | Syntax |
|------|--------|
| Page break | `===` on its own line |
| Copy to clipboard | `++text++` |
| Type into a VM | `+++text+++` |
| Code block modifiers | fence language plus `-nocolor`, `-notab`, `-nocode`, `-nocopy`, `-wrap`, `-linenums` |
| Blocks | `> [!Knowledge]`, `> [!Alert]`, `> [!Hint]`, `> [!Help]`, `> [!Note]` |
| Expandable blocks | `> [+Hint]`, `> [+Help]`, `> [+Alert]`, `> [+Note]`; continue with a `>` line then more `> ` text |
| Image | `![alt text](media/file.png "title"){width}` |
| Dialog link | `^[text](url)` |
| Portal link | `<[text](url)` |
| Section by variable | `:::name(variable=value)` ... `:::` |
| Per-attendee values | `@lab.User.Email`, `@lab.CloudPortal.Link`, `@lab.CloudCredential(Pool).Username` |
| Attendee input | `@lab.TextBox(name)` to set, `@lab.Variable(name)` to recall, `@lab.MaskedTextBox(name)` for secrets |
| Activities | add in Studio, then paste the token such as `@lab.Activity(Question1)` |

Use `@lab` tokens for any per-attendee value. Never hardcode credentials, subscription IDs, or emails.

## Checklist

- Every `NN-*.md` is listed in the `README.md` header comment, and the list matches the files on disk.
- `README.md` contains every module in order, separated by `===`, and matches the modules exactly.
- Each module starts with a valid `# ` heading and ends with a win.
- Images referenced exist under `media/` and use relative paths without a leading slash.
- No secrets, hardcoded per-attendee values, or placeholder text.
- Syntax matches the table above; blocks inside lists are indented.
- Links to repo files from outside `skillable/` are relative and exist.
