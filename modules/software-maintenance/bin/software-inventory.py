#!/usr/bin/env python3
"""Read-only version facts without endpoints, container names or credentials."""
import argparse
import json
from pathlib import Path
import re
import subprocess


def output(args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=30)
        return result.stdout.strip() if result.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def version(text):
    match = re.search(r'\b(v?\d+\.\d+\.\d+)\b', text or '')
    return match[1].lstrip('v') if match else None


def collect(role):
    facts = {'schema_version':1, 'role':role, 'docker':output(['docker','version','--format','{{.Server.Version}}']),
             'compose':version(output(['docker','compose','version','--short'])),
             'containerd':version(output(['containerd','--version'])),
             'reboot_required':Path('/var/run/reboot-required').exists(),
             'live_restore':output(['docker','info','--format','{{.LiveRestoreEnabled}}']) == 'true',
             'host_caddy':version(output(['caddy','version'])), 'routing':{}, 'other_caddy_versions':[]}
    packages = output(['dpkg-query','-W','-f=${Package}\t${Version}\n','openssl','python3','docker-ce','containerd.io'])
    facts['distribution_packages'] = dict(line.split('\t',1) for line in (packages or '').splitlines() if '\t' in line)
    ids = (output(['docker','ps','-q']) or '').split()
    containers = json.loads(output(['docker','inspect']+ids) or '[]') if ids else []
    for item in containers:
        labels = item['Config'].get('Labels') or {}
        owned = labels.get('com.docker.compose.project') == 'stealth'
        image = item['Config']['Image']
        cid = item['Id']
        if 'caddy' in image.lower():
            found = version(output(['docker','exec',cid,'caddy','version']))
            if owned:facts['routing']['caddy'] = found
            elif found:facts['other_caddy_versions'].append(found)
        if owned and labels.get('com.docker.compose.service') == 'xray':
            facts['routing']['xray'] = version(output(['docker','exec',cid,'/app/bin/xray-linux-amd64','version']))
            panel = re.search(r'(?:xui:|3x-ui:v)(\d+\.\d+\.\d+)',image)
            facts['routing']['panel'] = panel[1] if panel else None
        if image.startswith('ghcr.io/xtls/xray-core:'):
            facts['routing']['xhttp_xray'] = version(output(['docker','exec',cid,'/usr/local/bin/xray','version']))
        if image.startswith('moby/buildkit:'):
            facts['buildkit'] = version(output(['docker','exec',cid,'buildkitd','--version']))
    facts['other_caddy_versions'] = sorted(set(facts['other_caddy_versions']))
    return facts


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--role', choices=['primary_vps','hermes_vps'], required=True)
    args = parser.parse_args()
    print(json.dumps(collect(args.role), indent=2))
