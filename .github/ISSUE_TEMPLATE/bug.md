---
name: Bug report
about: Something is broken or behaves incorrectly
title: "[bug] "
labels: bug
---

## Description

What's broken? Be specific.

## Expected behaviour

What should happen?

## Actual behaviour

What happens instead? Include exact error messages.

## Reproduction

Minimum steps to reproduce. Use placeholders for any sensitive values.

```bash
# Example
./modules/secrets-management/bin/secret-scan
ansible-playbook --syntax-check ansible/playbooks/<playbook>.yml
```

## Environment

- PraefectusAI commit: `git rev-parse --short HEAD`
- OS / control machine: macOS 14 / Ubuntu 24.04 / ...
- Ansible version: `ansible --version`
- Docker version on VPS: `docker --version`

## Additional context

Logs, stack traces, screenshots. **Sanitise** any real IPs, hostnames, or tokens before posting.
