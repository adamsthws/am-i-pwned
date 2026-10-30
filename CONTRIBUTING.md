# Contributing

Each vulnerability check lives in its own directory with its own README. Keep it concise: the upstream source carries the detail, we carry a short summary and a quick detection tool.

## Layout

```
<Product name and version>/
  README.md
  check-<slug>.sh      # Linux / macOS
  check-<slug>.ps1     # Windows
  test-<slug>.sh       # detection tests for check-<slug>.sh
  test-<slug>.ps1      # detection tests for check-<slug>.ps1
```

Name the directory after the affected product and version (for example `Claude Code 2.1.313`). See that directory for a complete example.

Each check is exactly one script per platform, run with a single command. The root `run-all.sh` and `run-all.ps1` pick up every `*/check-*.sh` and `*\check-*.ps1` automatically, so a new check needs no registration beyond its directory and a row in the root README's table.

## README

Keep each section to a few lines.

1. **Title and summary.** What was compromised, the affected versions, the date, and what the malicious code does.
2. **Run it.** The single command to run this check on its own, one for Linux/macOS and one for Windows, and the exit codes. Do not ask for elevation in the README.
3. **What it checks.** A short list or table of what the script looks for, per platform.
4. **If it finds something.** The immediate remediation steps. Link out for anything longer.
5. **Indicators.** Hashes, fingerprints, domains, IPs and file paths the script uses.
6. **Sources.** Links to the article or advisory where the information was released, and to any technical write-up. Readers should be able to follow the news from here. Every indicator in the script must trace back to one of these links. Use the vendor's advisory or a reputable security write-up, not social media posts alone, because a wrong indicator gives false alarms or false reassurance.

## Scripts

- One script per platform, named `check-<slug>.sh` and `check-<slug>.ps1`, runnable with a single command and no arguments.
- Read-only. A check must never modify, delete or quarantine anything.
- No network access. A check must never download, upload or contact anything.
- No dependencies beyond what the platform ships with.
- Write shell scripts in POSIX `sh` or bash, and keep them clean under `shellcheck` if you have it. Target Windows PowerShell 5.1, which ships with Windows, and keep scripts working in PowerShell 7.
- Exit `0` when nothing is found and `1` when indicators are found.
- Must work unelevated. If root or Administrator would let a check look further, detect that at runtime and print a hint saying what it adds, rather than asking for it in the README.
- Print a clear per-check result, and state which paths or logs could not be read rather than silently skipping them.
- Put the source links and indicators in a comment at the top of the script.

## Tests

Every check ships a test script per platform that proves detection works, not just that a clean machine reports clean. See the Claude Code 2.1.313 tests for a template. Each test:

- builds a fake home folder (`HOME` and `TMPDIR` on Linux and macOS, `USERPROFILE`, `APPDATA` and `TEMP` on Windows) in a temporary folder, and removes it afterwards,
- runs the check against a clean fake home and expects exit `0`,
- plants every file-based indicator in a second fake home, expects exit `1`, and expects each indicator to be reported as a finding (`[!]` line),
- needs nothing installed and touches nothing outside its temporary folder.

Run them with `bash tools/run-tests.sh`, or `powershell -ExecutionPolicy Bypass -File .\tools\run-tests.ps1` on Windows. Before relying on a new test, break the check on purpose, for example by turning one finding into an `ok`, and confirm the test fails.

## Development environment

Never install anything onto your machine for work on this repository: no global or user-level `pip`, `npm`, `Install-Module`, package manager or similar installs. Put tooling in a virtual environment inside the repository (`.venv/`, which git ignores) or run it in a throwaway container (`docker run --rm`). Removing the repository or the container should leave the machine exactly as it was, as the checks themselves do.

The one exception is the local PowerShell image built from `tools/pwsh/Dockerfile` for the hooks below. Remove it with `docker image ls -q am-i-pwned-pwsh | xargs -r docker image rm`.

## Linting and checks

CI runs these on every pull request. Set them up locally, inside `.venv/`, with:

```bash
bash tools/dev-setup.sh                                                  # once; hooks then run on every commit
PRE_COMMIT_HOME=.venv/pre-commit .venv/bin/pre-commit run --all-files    # on demand
```

Undo the setup with `rm -rf .venv .git/hooks/pre-commit`.

- **Repository layout** (`tools/check-repo.sh`): each check has a README, one matching `check-*.sh` and `check-*.ps1`, matching `test-*.sh` and `test-*.ps1`, a row in the root README's table, and no download commands.
- **Secrets scan**: `gitleaks`.
- **Shell**: `shellcheck`. If a warning is deliberate, disable it on that line with a comment saying why.
- **PowerShell**: a parse and PSScriptAnalyzer. Locally the hook uses `pwsh` if you have it (saving the module under `.venv/`), otherwise the image built from `tools/pwsh/Dockerfile`, and skips if you have neither. CI also parses in Windows PowerShell 5.1.
- **Detection tests**: locally, a hook runs `tools/run-tests.sh`. CI runs the tests on Linux, macOS and Windows, under both Windows PowerShell 5.1 and PowerShell 7.
- **Smoke test**: locally, a hook runs `run-all.ps1` in that image and expects exit `0`. Windows-only cmdlets are missing on Linux, so this catches crashes and wiring, not detection. CI runs `run-all` on Linux, macOS and Windows and expects exit `0`.

To run PowerShell by hand without installing it, use `bash tools/pwsh.sh`, for example `bash tools/pwsh.sh -File run-all.ps1`. The PowerShell tests need real Windows paths, so they only run on Windows.

GitHub Actions, the Docker base image and the pre-commit hooks are pinned to exact commit hashes or digests. Dependabot proposes updates for the first two. Update the hooks with `PRE_COMMIT_HOME=.venv/pre-commit .venv/bin/pre-commit autoupdate --freeze`.

## Commits

- Each commit is self-contained: one cohesive change that builds and runs on its own.
- Write the subject line in the imperative, such as "Add check for Foo 1.2.3", in about 72 characters or fewer. Use the body to explain why.
- Reviewers may read commits one at a time, so keep them clean even though the PR is squashed when it merges.
- Keep history clean. Squash fix-ups, typo corrections and review tweaks into the commit they belong to rather than stacking "fix", "oops" or "address review" commits on top.
- Rebase onto `main` instead of merging it into your branch, so the branch has no merge commits and lands as a fast-forward.
- Rewriting commits on your own unmerged branch is expected; never rewrite anything that has already landed on `main`.

## Submitting

Keep each pull request to one issue or topic, such as a single check or a single fix. Split unrelated features, fixes or additions into separate PRs. A PR with multiple commits is squashed into one when it is merged, so its title and description should read as that one commit's message.

When adding a check, add it to the table in the root README. Say in the description which source each indicator came from, and on which platforms you ran the script and `run-all`.

Before submitting, make sure the check's tests pass and that the check runs unelevated without errors.

## Updating a check

When an advisory adds new indicators or corrects old ones, update the existing check rather than adding a new one. Add a dated note to its README saying what changed and link the new source. If an advisory is withdrawn, say so in the README and remove the indicators it supplied.

## Releases

Maintainers release by pushing a signed tag such as `v1.2.0` from `main`. The release workflow runs the tests and publishes `am-i-pwned.tar.gz`, `am-i-pwned.zip` and `SHA256SUMS`. The README's one-line commands always fetch the latest release, so a change reaches users only once it is tagged. Release a new tag soon after adding or updating a check.

## Reporting a compromise

If you find a compromise that is not public yet, do not open a public issue or PR. Report it to the affected vendor first, then tell us privately as described in [SECURITY.md](SECURITY.md). Use the same route for a check that misses an infection or flags a clean machine.

## Use of AI assistants
That's fine, and you don't need to say so or add co-authorship: as with the Linux kernel, whoever submits a change answers for it - its correctness, its tests and its licence - however it was written.

## Licence

Contributions are made under the repository's licence, the GNU Affero General Public License v3. See [LICENSE](LICENSE).
