---
name: update-skillable-instructions
description: 'Create and maintain the Skillable lab instruction files in instructions/skillable/ using Skillable Markdown syntax, validated against https://docs.skillable.com/docs/creating-instructions-with-markdown-syntax. Use when: adding, editing, reordering, or reviewing the core-N and more-N Skillable page files; regenerating skillable-copy.md with generate-skillable-copy.sh; checking Skillable syntax (page breaks, blocks, copyable text, tokens, images).'
---

# Update Skillable instructions

Maintain `instructions/skillable/`: one authored page file per lab, a generator script, and the generated `skillable-copy.md` that the owner pastes into Skillable Studio (or builds as `[!include]` lines that pull each page from GitHub).

The syntax reference is the Skillable authoring guide. Use it to validate every page. Append `.md` to the URL for plain Markdown.
- https://docs.skillable.com/docs/creating-instructions-with-markdown-syntax (syntax, the source of truth)
- https://docs.skillable.com/docs/instructions-writing-best-practices
- https://docs.skillable.com/docs/github-instructions-source

## How Skillable consumes this folder

- A lab profile uses exactly one Markdown file, pasted into Studio or synced from the repo. Here that file is `skillable-copy.md`.
- `[!include [label](raw-github-url)]` pulls a page live from GitHub. It needs a public repo and pins to a branch.
- GitHub previews do not render Skillable-only syntax (blocks, checkboxes, copy text). Check the rendering in Skillable.
- Repo size limit is 500 MB. Keep videos out of the repo.

## Folder layout

```text
instructions/skillable/
  README.md                    maintainer and lab guide: labs, prerequisites, setup, validation
  core-0-setup-environment.md  one file per core lab; the number sets the order
  core-1-<slug>.md ...
  more-0-<slug>.md ...         one file per More lab, after the core
  generate-skillable-copy.sh   joins the pages into skillable-copy.md
  skillable-copy.md            generated; never edit by hand
  media/                       images used by the pages, if any
```

Each page file holds one lab. Split it into Skillable pages with a line containing only `===`.

## Workflow

1. Read `README.md` and the existing `core-*.md` and `more-*.md` files to learn the current list and order.
2. Create, edit, rename, or delete page files as requested. Keep numbers contiguous within `core-` and `more-`, and slugs lowercase with hyphens.
3. Keep each page in step with the matching self-paced lab in `instructions/self-paced/core/` or `instructions/self-paced/more/`: same commands, same expected output.
4. Update the lab tables in `README.md`, then run `./instructions/skillable/generate-skillable-copy.sh` (or `MODE=include` for the GitHub include form).
5. Run the checklist below and fix failures before finishing.

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

> [!Note] **Success:** state the visible result, for example the new score.
```

Rules:
- Start each Skillable page with a `# ` heading, 40 characters or fewer, sentence case, no period. It labels the Next button. More pages start with `More N: `.
- One sentence per step. Order each step as where, what, why.
- Numbered steps use `1.` for every item. Add `[]` for a progress checkbox on actions the attendee performs.
- Indent blocks that sit between steps to the same level as the step before them.
- Attendee-facing, simple, conversational language. No fabricated results, links, or scores.
- Never give away the fix in the main text of the break step. Put help in hint blocks.
- Every Skillable page ends with a `>[!Note] **Success:**` line stating the visible win.
- Use `-nocopy` on code blocks that show expected output.

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

- Every `core-*.md` and `more-*.md` file is listed in the lab tables in `README.md`, and the tables match the files on disk and their `# ` page titles.
- `skillable-copy.md` was regenerated after the last page change.
- Each Skillable page starts with a valid `# ` heading of 40 characters or fewer and ends with a success note.
- Commands and expected output match the matching self-paced lab.
- Images referenced exist under `media/` and use relative paths without a leading slash.
- No secrets, hardcoded per-attendee values, or placeholder text.
- Syntax matches the Skillable authoring guide; blocks inside lists are indented.
- Links to repo files from outside `skillable/` are relative and exist.
