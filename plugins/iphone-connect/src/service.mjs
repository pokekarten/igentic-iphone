import { randomUUID, createHash } from 'node:crypto';
import { mkdir, open, readFile, unlink, chmod } from 'node:fs/promises';
import { join } from 'node:path';
import { PluginError } from './process.mjs';

const fingerprint = data => createHash('sha256').update(JSON.stringify(data)).digest('hex');
export class PhoneService {
  constructor({ backend, stateDir, now = Date.now, sessionMs = 300000, observationMs = 15000 }) {
    Object.assign(this, { backend, stateDir, now, sessionMs, observationMs });
    this.sessions = new Map(); this.results = new Map();
  }
  async list() { return { devices: await this.backend.list(), backend: this.backend.kind }; }
  capabilities() {
    const catalogOnly = this.backend.kind === 'catalog';
    return { backend: this.backend.kind,
      mode: catalogOnly ? 'business-catalog-only' : 'diagnostics-only',
      requiresMac: !catalogOnly,
      actions: catalogOnly ? [] : ['open-diagnostics', 'open-discovery'],
      observation: catalogOnly ? 'none' : 'fixed-markers-only',
      screenshots: false, personalAppControl: false, reminderWrites: false,
      connection: 'local-stdio', ready: catalogOnly ? 'unavailable' : 'notYetObserved' };
  }
  // Keep recent stopped-session receipts readable, but bound retained history.
  // The device lease (not this in-memory history) remains the exclusivity gate.
  pruneClosedSessions() {
    while (this.sessions.size >= 128) {
      const oldest = [...this.sessions.values()].find(s => s.stopped && !s.busy);
      if (!oldest) throw new PluginError('sessionLimitRestartClient');
      this.sessions.delete(oldest.id);
      for (const [proposalId, receipt] of this.results) {
        if (receipt.sessionId === oldest.id) this.results.delete(proposalId);
      }
    }
  }
  async start(device) {
    if (device !== 'iphone-1') throw new PluginError('unknownDevice');
    this.pruneClosedSessions();
    if (!(await this.backend.list()).some(d => d.id === device && d.available)) throw new PluginError('deviceUnavailable');
    await mkdir(this.stateDir, { recursive: true, mode: 0o700 });
    await chmod(this.stateDir, 0o700);
    // Cross-process lease. Never silently steal after crash; doctor explains recovery.
    const lock = join(this.stateDir, 'device.lease'); const id = randomUUID();
    let file;
    try { file = await open(lock, 'wx', 0o600); }
    catch (e) { if (e.code === 'EEXIST') throw new PluginError('deviceBusy'); throw e; }
    try { await file.writeFile(JSON.stringify({ pid: process.pid, session: id })); }
    finally { await file.close(); }
    const session = { id, device, expires: this.now() + this.sessionMs, lock,
      controller: new AbortController(), busy: false, stopped: false, uncertain: false };
    this.sessions.set(id, session);
    session.expiryTimer = setTimeout(() => { void this.stop(id).catch(() => {}); }, this.sessionMs);
    session.expiryTimer.unref?.();
    return { sessionId: id, expiresInSeconds: this.sessionMs / 1000, backend: this.backend.kind };
  }
  session(id) {
    const s = this.sessions.get(id);
    if (!s || s.stopped) throw new PluginError('invalidSession');
    if (s.expires <= this.now()) {
      s.controller.abort(); throw new PluginError('sessionExpired');
    }
    return s;
  }
  async within(id, work) {
    const s = this.session(id);
    if (s.busy) throw new PluginError('sessionBusy');
    s.busy = true;
    const timer = setTimeout(() => s.controller.abort(), Math.max(1, s.expires - this.now()));
    try {
      const result = await work(s);
      this.session(id);
      if (s.controller.signal.aborted) throw new PluginError('cancelled');
      return result;
    } finally {
      clearTimeout(timer); s.busy = false;
      if (s.stopped || s.expires <= this.now()) { s.stopped = true; await this.release(s); }
    }
  }
  record(s, data) {
    // Backend text and private identifiers never enter the result contract.
    const observation = { observationId: randomUUID(), backend: this.backend.kind,
      elementCount: data.elementCount, markers: data.markers };
    s.observation = { ...observation, at: this.now(), fingerprint: fingerprint(data) };
    return observation;
  }
  async observe(id) {
    return this.within(id, async s => this.record(s, await this.backend.observe(s.controller.signal)));
  }
  async open(id) {
    return this.within(id, async s => this.record(s, await this.backend.open(s.controller.signal)));
  }
  prepare(id, observationId, action) {
    const s = this.session(id);
    if (s.busy) throw new PluginError('sessionBusy');
    if (s.uncertain) throw new PluginError('reconciliationRequired');
    if (action !== 'open-discovery') throw new PluginError('unsupportedAction');
    const o = s.observation;
    if (!o || o.observationId !== observationId || this.now() - o.at > this.observationMs)
      throw new PluginError('staleObservation');
    if (!o.markers.includes('Open local discovery')) throw new PluginError('navigationTargetUnavailable');
    const proposalId = randomUUID();
    s.proposal = { proposalId, action, observationId, fingerprint: o.fingerprint, consumed: false };
    return { proposalId, action, persistentWrite: false, requiresApproval: false,
      summary: 'Open bundled discovery content in iGentic Diagnostics.' };
  }
  async execute(id, proposalId) {
    return this.within(id, async s => {
      const p = s.proposal;
      if (!p || p.proposalId !== proposalId || p.consumed) throw new PluginError('invalidProposal');
      if (s.uncertain) throw new PluginError('reconciliationRequired');
      if (this.now() - s.observation.at > this.observationMs) throw new PluginError('staleObservation');
      const signal = s.controller.signal;
      const current = await this.backend.observe(signal);
      this.session(id);
      if (signal.aborted) throw new PluginError('cancelled');
      if (fingerprint(current) !== p.fingerprint) throw new PluginError('screenChanged');
      p.consumed = true;
      const record = { proposalId, status: 'unknownOutcome', backend: this.backend.kind };
      this.results.set(proposalId, { sessionId: id, record });
      // Retain at most 128 receipts, including unknown outcomes. A result
      // evicted from this local bounded cache can never reauthorize an action.
      while (this.results.size > 128) {
        this.results.delete(this.results.keys().next().value);
      }
      // Persist the one-shot state in memory before dispatch. Across restart, no
      // executable proposals survive. A leftover lease requires local inspection.
      try {
        const after = await this.backend.discovery(signal);
        this.session(id);
        if (signal.aborted) throw new PluginError('cancelled');
        const verified = after.markers.includes('Explore') && !after.markers.includes('Open local discovery');
        Object.assign(record, { status: verified ? 'verified' : 'unknownOutcome' });
        s.uncertain = !verified;
        this.record(s, after);
      } catch {
        s.uncertain = true;
      }
      return { ...record };
    });
  }
  result(id, proposalId) {
    // Stopped/expired session may still read its bounded receipt, never execute.
    if (!this.sessions.has(id)) throw new PluginError('invalidSession');
    const r = this.results.get(proposalId);
    if (!r || r.sessionId !== id) throw new PluginError('unknownResult');
    return { ...r.record };
  }
  async stop(id) {
    const s = this.sessions.get(id);
    if (!s) throw new PluginError('invalidSession');
    s.stopped = true; clearTimeout(s.expiryTimer); s.controller.abort(); s.proposal = null;
    // Do not release while an aborted external command may still be completing.
    if (!s.busy) await this.release(s);
    return { stopped: true, pendingOperation: s.busy, undoPerformed: false };
  }
  async release(s) {
    try {
      const lease = JSON.parse(await readFile(s.lock, 'utf8'));
      if (lease.session === s.id) await unlink(s.lock);
    } catch (e) { if (e.code !== 'ENOENT') throw e; }
  }
  async close() {
    for (const s of this.sessions.values()) { s.stopped = true; clearTimeout(s.expiryTimer); s.controller.abort(); }
    for (const s of this.sessions.values()) if (!s.busy) await this.release(s);
  }
}
