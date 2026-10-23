This is a hands-on workshop that teaches runtime agent governance with ACS and
ASSERT by securing a deliberately under-governed agent, Contoso DevBot.

Read `AGENTS.md` before changing code. The hard rules that matter most:

- DevBot's tools are simulated. Never make anything actually execute a shell
  command, touch the filesystem, or open a network connection.
- The offline core (`workshop/core/`) must run with no credentials. Live-only
  steps live in `workshop/more/lab-live-run.md`.
- Every command shown in a lab must be tested, with real observed output. Do not
  write expected output you have not run.
- The offline agent, fixture builder, and generator must stay deterministic.

## Workshop skills

Skills that guide learners live under `.agents/skills/`. When a learner says
things like "run the workshop", "set up my environment", "explain this", "help
me debug", or "what's next", look up the matching skill folder and follow its
`SKILL.md`.

## Validating a change

```bash
./scripts/check-setup.sh
./scripts/run-offline-loop.sh
```

The second command must end with the PASS line and the 100% to 0% attack-success
result. If you changed the agent's outputs, rebuild the baseline fixture first
with `PYTHONPATH=src python3 eval/build_baseline_fixture.py`.

## Prose style

Authored prose avoids em-dashes and gratuitous colons. Colons are fine in
headings, tables, code, and YAML.

## Security

Never commit secrets or real credentials. The `sk-live-...` string in the agent
is a fake matching a format, used so the generated policy has something realistic
to catch.
