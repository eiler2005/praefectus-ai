# Monitoring regression tests

Run with the Python environment that provides Ansible (Jinja2 and PyYAML):

```bash
python -m unittest discover -s tests -v
```

The tests render the production monitor template without credentials and cover
fleet inventory, healthchecks, missing services, failed inspection, restart
baselines across maintenance/reboots/recreation, restart severity and the
systemd journal source. They run without SSH, Docker or Telegram delivery.

Deployment validation is separate: review `20-monitoring.yml --check --diff`,
apply with operator approval, run the monitor twice, inspect timer/service
results and run `./verify.sh`. A WARN returns 1 and a CRIT returns 2; examine
the issue rather than equating every systemd failure with a script crash.
