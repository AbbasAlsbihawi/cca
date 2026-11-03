// General page: settings for every account and for this app, in the style of System Settings.
import { runLogged, showBanner, showActivity } from './output.js';
import { el, button, row, group, toggle, value, gearSymbol, snapshotLabel, confirmNative } from './ui.js';

// ctx: { data, info, refresh }
export function renderGeneral(root, ctx) {
  root.replaceChildren();
  const page = el('div', 'page');
  root.appendChild(page);
  const data = ctx.data || {};
  const snaps = Array.isArray(data.snapshots) ? data.snapshots : [];
  const latest = snaps.length ? snaps[snaps.length - 1] : '';

  const head = el('div', 'page-head');
  const who = el('div', 'who');
  who.append(el('h2', null, 'General'), el('div', 'meta', 'Settings for all accounts and for this app.'));
  head.append(gearSymbol(true), who);
  page.appendChild(head);

  const setting = (verb, on) => runLogged([verb, on ? 'on' : 'off']).then(ctx.refresh);

  page.appendChild(group('Backups', [
    row('Back up every day', 'Every day at 13:00.', toggle('Back up every day', data.autobackup, (on) => setting('autobackup', on))),
    row('Back up now', latest ? 'Latest backup: ' + snapshotLabel(latest) : 'No backups yet.', button('Back Up Now', async () => {
      const r = await runLogged(['backup']);
      if (r.code === 0) showBanner('Backup saved.', 'ok');
    }, '', ctx.refresh)),
  ]));

  // Only cca.zsh reports autoupdate and has `cca update`: Windows and an older cca have neither.
  if (typeof data.autoupdate === 'boolean') {
    page.appendChild(group('Claude app', [
      row('Restart Claude after it updates', 'Reopens the open Claude copies on the new version.',
        toggle('Restart Claude after it updates', data.autoupdate, (on) => setting('autoupdate', on))),
      row('Restart all open copies', 'Each copy then runs the installed version and has its MCP servers.', button('Restart Claude…', async () => {
        const ok = await confirmNative({
          message: 'Quit and reopen every open Claude copy?',
          detail: 'If work is running in one, Claude may ask first.',
          confirm: 'Restart',
        });
        if (!ok) return;
        const r = await runLogged(['update']);
        if (r.code === 0) showBanner('Claude copies restarted.', 'ok');
      }, '', ctx.refresh)),
    ]));
  }

  // The update text and bar are filled in by app.js, which hears the updater.
  const bar = el('progress', 'gen-update-bar');
  bar.id = 'gen-update-bar';
  bar.max = 100;
  bar.hidden = true;
  const status = el('small', null, '');
  status.id = 'gen-update-text';
  // Development builds have no updater, so no button there.
  let checkBtn = null;
  if (ctx.info && ctx.info.updates) {
    checkBtn = el('button', '', 'Check Now');
    checkBtn.type = 'button';
    checkBtn.id = 'gen-update-check';
    checkBtn.addEventListener('click', () => ctx.checkUpdates());
  }
  const updateRow = row('Software update', null, bar, checkBtn);
  updateRow.querySelector('.k').appendChild(status);
  page.appendChild(group('Claude Accounts', [
    row('Version', null, value(ctx.info && ctx.info.version ? ctx.info.version : '')),
    updateRow,
  ]));

  page.appendChild(group('Activity', [
    row('Command output', 'Every command this window ran, with its output.', button('Show Activity', async () => showActivity())),
  ]));
}
