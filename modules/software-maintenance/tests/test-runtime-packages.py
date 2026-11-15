import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

PATH = Path(__file__).resolve().parents[1] / 'bin/runtime-packages.py'
spec = importlib.util.spec_from_file_location('runtime_packages', PATH)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PackageTests(unittest.TestCase):
    def test_daemon_merge_preserves_owner_settings(self):
        self.assertEqual(module.merge_daemon('{"log-driver":"local","bip":"192.0.2.1/24"}'), {'log-driver':'local','bip':'192.0.2.1/24','live-restore':True})

    def test_non_object_rejected(self):
        with self.assertRaises(ValueError):module.merge_daemon('[]')

    def test_exact_target_and_epoch(self):
        module.reviewed_target('docker-ce', '5:29.9.3-1~ubuntu.24.04~noble')

    def test_unreviewed_major_rejected(self):
        with self.assertRaises(ValueError):module.reviewed_target('docker-ce', '30.0.0-1')

    def test_prerelease_rejected(self):
        with self.assertRaises(ValueError):module.reviewed_target('docker-ce', '29.9.3-rc1')

    def test_missing_package_rejected(self):
        with self.assertRaises(ValueError):module.package_version('Candidate: (none)', 'Candidate')

    def test_failed_command_keeps_diagnostics_private(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / 'failure.private.log'
            failed = subprocess.CompletedProcess(['apt-get'], 1, 'private stdout', 'private stderr')
            with patch.object(module.subprocess, 'run', return_value=failed):
                with self.assertRaisesRegex(RuntimeError, '^Maintenance command failed: apt-get$'):
                    module.run(['apt-get'], private_log=log)
            self.assertIn('private stderr', log.read_text())


if __name__ == '__main__':unittest.main()
