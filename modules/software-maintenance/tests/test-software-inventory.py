import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

path = Path(__file__).resolve().parents[1] / 'bin/software-inventory.py'
spec = importlib.util.spec_from_file_location('software_inventory', path)
inventory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inventory)


class InventoryTests(unittest.TestCase):
    def test_private_container_metadata_is_not_published(self):
        secret = 'PRIVATE_ENDPOINT_AND_CREDENTIAL'
        container = {'Id': 'fixture', 'Name': secret, 'Config': {
            'Image': 'ghostroute/xui:3.11.0-xray26.11.9',
            'Env': ['PASSWORD=' + secret], 'Labels': {
                'com.docker.compose.project': 'stealth',
                'com.docker.compose.service': 'xray'}}}

        def output(args):
            if args == ['docker', 'ps', '-q']:
                return 'fixture'
            if args[:2] == ['docker', 'inspect']:
                return json.dumps([container])
            if args[:2] == ['docker', 'exec']:
                return 'Xray 26.11.9'
            return ''

        with patch.object(inventory, 'output', side_effect=output):
            result = inventory.collect('hermes_vps')
        self.assertNotIn(secret, json.dumps(result))
        self.assertEqual(result['routing']['xray'], '26.11.9')
        self.assertEqual(result['routing']['panel'], '3.11.0')

    def test_version_parser_does_not_guess_missing_versions(self):
        self.assertIsNone(inventory.version(None))
        self.assertIsNone(inventory.version('command not found'))


if __name__ == '__main__':
    unittest.main()
