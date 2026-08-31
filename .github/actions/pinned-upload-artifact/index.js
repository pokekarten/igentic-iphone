'use strict';
const cp = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PIN = 'ea165f8d65b6e75b540449e92b4886f43607fa02';
const root = fs.mkdtempSync(path.join(process.env.RUNNER_TEMP || os.tmpdir(), 'pinned-upload-artifact-'));
const repo = path.join(root, 'src');
cp.execFileSync('git', ['clone', '--quiet', 'https://github.com/actions/upload-artifact.git', repo], {stdio: 'inherit'});
cp.execFileSync('git', ['-C', repo, 'checkout', '--quiet', PIN], {stdio: 'inherit'});
const observed = cp.execFileSync('git', ['-C', repo, 'rev-parse', 'HEAD'], {encoding: 'utf8'}).trim();
if (observed !== PIN) throw new Error(`upload-artifact pin mismatch: ${observed}`);
const entry = path.join(repo, 'dist', 'upload', 'index.js');
if (!fs.existsSync(entry)) throw new Error(`missing pinned upload-artifact entrypoint: ${entry}`);
require(entry);
