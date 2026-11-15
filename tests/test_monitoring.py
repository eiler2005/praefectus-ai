"""Render the production template and exercise health decisions without a VPS."""
import copy
import json
import pathlib
import types
import unittest
from unittest.mock import patch

import jinja2
import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / "ansible/roles/monitoring/templates/vps-monitor.py.j2"


def render(**variables):
    module = types.ModuleType("monitor")
    code = jinja2.Environment().from_string(TEMPLATE.read_text()).render(
        inventory_hostname="test-host", **variables
    )
    exec(compile(code, str(TEMPLATE), "exec"), module.__dict__)
    return module


class MonitorTests(unittest.TestCase):
    def setUp(self):
        self.monitor = render(expected_containers=[{"name": "app"}])
        self.metrics = dict(disk_pct=30, mem_avail_mb=2000, swap_pct=0,
                            load_5min=0.2, docker_active=True,
                            running_containers=["app", "builder"], inspect_ok=True,
                            boot_id="boot", containers={"app": dict(
                                id="container", restarts=4, health="healthy")})
        self.state = dict(restart_boot_id="boot", restart_baseline=copy.deepcopy(
            self.metrics["containers"]))

    def issues(self, state=None):
        return self.monitor.evaluate(self.metrics, self.state if state is None else state)

    def test_old_maintenance_counter_is_healthy(self):
        self.assertEqual(self.issues(), [])

    def test_initial_observation_baselines_history(self):
        self.assertEqual(self.issues({}), [])

    def test_new_restart_warns(self):
        self.metrics["containers"]["app"]["restarts"] += 1
        self.assertEqual(self.issues()[0][:2], ("warn", "restarts:app"))

    def test_ten_new_restarts_are_critical(self):
        self.metrics["containers"]["app"]["restarts"] += 10
        self.assertEqual(self.issues()[0][0], "crit")

    def test_recreate_and_counter_reset(self):
        for field, value in [("id", "replacement"), ("restarts", 0)]:
            with self.subTest(field=field):
                self.metrics["containers"]["app"][field] = value
                self.assertEqual(self.issues(), [])

    def test_reboot_baselines_history(self):
        self.metrics["boot_id"] = "new-boot"
        self.metrics["containers"]["app"]["restarts"] += 10
        self.assertEqual(self.issues(), [])

    def test_absent_healthcheck_is_supported(self):
        self.metrics["containers"]["app"]["health"] = None
        self.assertEqual(self.issues(), [])

    def test_unhealthy_and_starting(self):
        for status, level in [("unhealthy", "crit"), ("starting", "warn")]:
            self.metrics["containers"]["app"]["health"] = status
            self.assertEqual(self.issues()[0][:2], (level, "health:app"))

    def test_missing_expected_container(self):
        self.metrics["running_containers"] = ["builder"]
        self.assertEqual(self.issues()[0][:2], ("crit", "container:app"))

    def test_inspection_failure_is_not_healthy(self):
        self.metrics["inspect_ok"] = False
        self.assertEqual(self.issues()[0][:2], ("crit", "docker_inspect"))

    def test_cycle_signal_sources(self):
        for key in ["docker_boot_ordering_cycle", "docker_resolver_cycle"]:
            metrics = dict(self.metrics, **{key: True})
            self.assertEqual(self.monitor.evaluate(metrics, {})[0][1],
                             "docker_boot_ordering_cycle")

    def test_manager_journal_excludes_monitor_feedback(self):
        with patch.object(self.monitor, "shell", return_value="") as shell:
            self.monitor.collect()
        commands = [call.args[0] for call in shell.call_args_list]
        self.assertTrue(any("journalctl -b _PID=1" in cmd for cmd in commands))

    def test_inspect_parsing_and_current_cycle(self):
        def shell(command):
            if command.startswith("docker ps -aq"):
                return json.dumps(dict(Name="/app", Id="container", RestartCount=0,
                                       State={"Health": {"Status": "unhealthy"}}))
            return {
                "systemctl show docker.service -p After --value": "nss-lookup.target",
                "systemctl show nss-lookup.target -p After --value": "resolver.service",
                "systemctl show resolver.service -p After --value": "docker.service",
            }.get(command, "")
        with patch.object(self.monitor, "shell", side_effect=shell):
            metrics = self.monitor.collect()
        self.assertTrue(metrics["inspect_ok"])
        self.assertTrue(metrics["docker_resolver_cycle"])
        self.assertEqual(metrics["containers"]["app"]["health"], "unhealthy")

    def test_failed_alert_test_returns_nonzero(self):
        with patch.object(self.monitor, "send_telegram", return_value=False), \
             patch.object(self.monitor, "log"):
            self.assertEqual(self.monitor.run_once(test_alert=True), 3)

    def test_maintenance_ack_keeps_health_checks_and_saves_baseline(self):
        self.metrics["containers"]["app"]["restarts"] += 1
        self.metrics["disk_pct"] = 95
        with patch.object(self.monitor, "collect", return_value=self.metrics), \
             patch.object(self.monitor, "load_state", return_value=self.state), \
             patch.object(self.monitor, "save_state") as save, \
             patch.object(self.monitor, "alert") as alert, \
             patch.object(self.monitor, "maybe_send_heartbeat"), \
             patch.object(self.monitor, "log"):
            self.assertEqual(self.monitor.run_once(baseline_restarts=True), 2)
        self.assertEqual(alert.call_args.args[0], "disk")
        self.assertEqual(save.call_args.args[0]["restart_baseline"], self.metrics["containers"])

    def test_inventory_render_scope_and_disabled(self):
        data = yaml.safe_load((ROOT / "ansible/inventory/production.yml").read_text())
        hosts = data["all"]["children"]["vps_targets"]["children"]["vps"]["hosts"]
        for host, count in [("vps-hetzner-prod", 5), ("vps-hostkey-hermes", 25)]:
            variables = dict(hosts[host])
            variables["monitoring_expected_containers"] = variables["expected_containers"]
            variables["monitoring_disabled_containers"] = variables.get("disabled_containers", [])
            self.assertEqual(len(render(**variables).EXPECTED_CONTAINERS), count)
            self.assertEqual(render(**variables).LOAD_WARN, 2 if count == 5 else 8)
        self.assertEqual(render(expected_containers=["app", "retired"],
                                monitoring_disabled_containers=["retired"]).EXPECTED_CONTAINERS,
                         ["app"])


if __name__ == "__main__":
    unittest.main()
