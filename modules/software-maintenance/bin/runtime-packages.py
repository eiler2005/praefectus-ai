#!/usr/bin/env python3
"""Reviewed Docker package maintenance; application definitions remain owned by apps."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

PACKAGES = ('docker-ce', 'docker-ce-cli', 'containerd.io', 'docker-buildx-plugin', 'docker-compose-plugin')
TARGETS = {'docker-ce':'29.9.3', 'docker-ce-cli':'29.9.3', 'containerd.io':'2.4.2'}


def run(args, private_log=None, **kwargs):
    p = subprocess.run(args, capture_output=True, text=True, timeout=kwargs.pop('timeout', 180), **kwargs)
    if private_log is not None:
        private_log.write_text(p.stdout + '\n' + p.stderr)
    if p.returncode:
        raise RuntimeError('Maintenance command failed: ' + args[0])
    return p.stdout


def merge_daemon(text):
    value = json.loads(text or '{}')
    if not isinstance(value, dict):
        raise ValueError('Docker configuration must be an object')
    return dict(value, **{'live-restore': True})


def package_version(text, label):
    match = re.search(r'^\s*' + label + r':\s*(\S+)', text, re.M)
    if not match or match[1] == '(none)':
        raise ValueError('Missing installed/candidate package')
    return match[1]


def reviewed_target(name, candidate):
    if not re.fullmatch(r'[A-Za-z0-9.+:~_-]+', candidate) or re.search(r'(?i)(alpha|beta|rc[0-9])', candidate):
        raise ValueError('Unreviewed package version')
    if name in TARGETS and not re.match(r'^(?:[0-9]+:)?' + re.escape(TARGETS[name]) + r'(?:[-+~]|$)', candidate):
        raise ValueError('Candidate differs from reviewed stable target')


def plan():
    result = {}
    for name in PACKAGES:
        policy = run(['apt-cache', 'policy', name])
        installed = package_version(policy, 'Installed')
        candidate = package_version(policy, 'Candidate')
        reviewed_target(name, candidate)
        if 'download.docker.com' not in policy:
            raise ValueError('Expected official Docker package repository')
        result[name] = {'installed':installed, 'candidate':candidate}
    args = [name + '=' + value['candidate'] for name, value in result.items()]
    simulation = run(['apt-get', '--simulate', '--no-remove', '--only-upgrade', 'install'] + args)
    if re.search(r'^Remv\s', simulation, re.M):
        raise ValueError('Package removal is not allowed')
    return {'packages':result, 'simulation':simulation}


def apply(directory, restart_approved=False):
    if not restart_approved:
        raise ValueError('Explicit service restart approval required')
    os.umask(0o077)
    if directory.exists():
        raise ValueError('Use a fresh backup directory; existing rollback material is immutable')
    directory.mkdir(parents=True, mode=0o700)
    reviewed = plan()
    (directory / 'plan.json').write_text(json.dumps(reviewed, indent=2))
    ids = run(['docker', 'ps', '-q']).split()
    before = json.loads(run(['docker', 'inspect'] + ids)) if ids else []
    (directory / 'containers.before.private.json').write_text(json.dumps(before))
    guard = Path('/etc/systemd/system/docker.service')
    guard_hash = hashlib.sha256(guard.read_bytes()).digest() if guard.exists() else None
    daemon = Path('/etc/docker/daemon.json')
    previous = daemon.read_bytes() if daemon.exists() else None
    (directory / 'daemon.before.json').write_bytes(previous or b'{}')
    rollback = directory / 'packages'
    rollback.mkdir(mode=0o700)
    for name, value in reviewed['packages'].items():
        run(['apt-get', 'download', name + '=' + value['installed']], cwd=rollback, timeout=300)
    if len(list(rollback.glob('*.deb'))) != len(PACKAGES):
        raise ValueError('Incomplete rollback package set')
    next_config = directory / 'daemon.next.json'
    next_config.write_text(json.dumps(merge_daemon((previous or b'{}').decode()), indent=2))
    run(['dockerd', '--validate', '--config-file', str(next_config)])
    daemon.parent.mkdir(exist_ok=True)
    shutil.copy2(next_config, daemon)
    reload_result = subprocess.run(['systemctl', 'reload', 'docker'], capture_output=True)
    if reload_result.returncode:
        run(['systemctl', 'kill', '--kill-who=main', '--signal=HUP', 'docker'])
    if run(['docker', 'info', '--format', '{{.LiveRestoreEnabled}}']).strip() != 'true':
        raise ValueError('Live restore was not enabled')
    env = dict(os.environ, DEBIAN_FRONTEND='noninteractive', NEEDRESTART_MODE='l')
    args = [name + '=' + value['candidate'] for name, value in reviewed['packages'].items()]
    run(['apt-get', '-y', '--no-remove', '--only-upgrade', '-o', 'Dpkg::Options::=--force-confold', 'install'] + args, env=env, timeout=900, private_log=directory / 'apt.private.log')
    run(['systemctl', 'is-active', 'docker', 'containerd'])
    after = json.loads(run(['docker', 'inspect'] + ids)) if ids else []
    stopped = [item['Id'] for item in after if not item['State']['Running']]
    if stopped:
        raise RuntimeError('Previously running containers stopped; inspect private snapshot before recovery')
    if guard_hash is not None and hashlib.sha256(guard.read_bytes()).digest() != guard_hash:
        raise RuntimeError('Routing-owned systemd guard changed')
    (directory / 'containers.after.private.json').write_text(json.dumps(after))
    result = {'docker':run(['docker', 'version', '--format', '{{.Server.Version}}']).strip(),
              'containers_preserved':len(ids), 'same_processes':all(a['State']['Pid']==b['State']['Pid'] for a,b in zip(before,after)),
              'live_restore':True, 'reboot_performed':False}
    if result['docker'] != TARGETS['docker-ce']:
        raise RuntimeError('New Docker daemon is not running')
    (directory / 'result.json').write_text(json.dumps(result, indent=2))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--restart-approved', action='store_true')
    parser.add_argument('--backup-dir', type=Path, default=Path('/var/lib/praefectus/software-maintenance'))
    args = parser.parse_args()
    print(json.dumps(apply(args.backup_dir, args.restart_approved) if args.apply else plan(), indent=2))
