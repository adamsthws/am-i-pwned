# Security

## Reporting a problem with a check

Report these privately through [GitHub's private vulnerability reporting](https://github.com/adamsthws/am-i-pwned/security/advisories/new), not in a public issue:

- **A missed infection.** A check reports clean on a machine you know or suspect is compromised.
- **A false alarm.** A check flags a machine that is clean.
- **A problem with the scripts themselves.** For example, a check that changes something on the machine, or anything that could let someone tamper with what users download.

Include the check's name, your operating system, and the check's output with anything sensitive removed. Do not send malware samples or credentials.

New indicators from public reporting are not sensitive. Open a normal issue or pull request for those, linking the source.

## What you run

The one-line commands in the README download the latest tagged release, not the current `main`. Release archives are built by GitHub Actions from the tag, and `SHA256SUMS` is published alongside them. Every script is read-only and makes no network connections.
