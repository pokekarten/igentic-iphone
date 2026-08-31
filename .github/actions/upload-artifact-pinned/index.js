'use strict';

const childProcess = require('child_process');
const fs = require('fs');
const path = require('path');

const upstreamCommit = 'ea165f8d65b6e75b540449e92b4886f43607fa02';
const checkout = path.join(process.env.RUNNER_TEMP, `upload-artifact-${upstreamCommit.slice(0, 12)}`);

function run(command, args, options = {}) {
  return childProcess.execFileSync(command, args, {stdio: 'inherit', ...options});
}

fs.rmSync(checkout, {recursive: true, force: true});
run('git', ['init', checkout]);
run('git', ['-C', checkout, 'remote', 'add', 'origin', 'https://github.com/actions/upload-artifact.git']);
run('git', ['-C', checkout, 'fetch', '--no-tags', '--depth=1', 'origin', upstreamCommit]);
run('git', ['-C', checkout, 'checkout', '--detach', 'FETCH_HEAD']);
const observed = childProcess.execFileSync('git', ['-C', checkout, 'rev-parse', 'HEAD'], {encoding: 'utf8'}).trim();
if (observed !== upstreamCommit) {
  throw new Error(`upload-artifact revision mismatch: expected ${upstreamCommit}, got ${observed}`);
}
if (!process.env.ACTIONS_RUNTIME_TOKEN) {
  throw new Error('ACTIONS_RUNTIME_TOKEN is unavailable in local action context');
}
const entrypoint = path.join(checkout, 'dist', 'upload', 'index.js');
if (!fs.existsSync(entrypoint)) {
  throw new Error(`pinned upload-artifact entrypoint missing: ${entrypoint}`);
}
run(process.execPath, [entrypoint], {env: process.env});
