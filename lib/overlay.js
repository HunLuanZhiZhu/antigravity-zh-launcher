/* Shared, runtime-only UI overlay. No application files or user text are changed. */
(function (locale) {
  'use strict';
  if (typeof window === 'undefined' || typeof document === 'undefined') return;
  const fingerprint = window.__antigravityZhPatchRequestedFingerprint || locale.code;
  if (window.__antigravityZhPatchInstalled && window.__observedDocument === document &&
      window.__antigravityZhPatchFingerprint === fingerprint) return;
  // Interoperate with the legacy Chinese overlay before installing another locale.
  // Restoring the Chinese overlay must not persist an English preference.
  let previousPreference;
  try { previousPreference = window.localStorage?.getItem('antigravityHansLang'); } catch (_) {}
  window.__antigravityZhSetLang?.('en');
  try {
    if (previousPreference == null) window.localStorage?.removeItem('antigravityHansLang');
    else window.localStorage?.setItem('antigravityHansLang', previousPreference);
  } catch (_) {}
  window.__antigravityZhPatchCleanup?.();
  const phrases = new Map(Object.entries(locale.phrases).flatMap(([key, value]) => [[key, value], [key.toLowerCase(), value]]));
  const texts = new Map(), attrs = new Map(), nlsChanges = [];
  let observer, active = true, scheduled = false;
  const originalLang = document.documentElement.lang;
  const rtf = new Intl.RelativeTimeFormat(locale.code, { numeric: 'auto' });
  const greetingPatterns = [
    /^Hi ([\s\S]+?), what can we get done today\?$/,
    /^Hey (?!there,)([\s\S]+?), what should we build today\?$/,
    /^Hey there, what should we build today\?$/,
    /^Welcome back\. Where should we pick up\?$/,
    /^Welcome back, ([\s\S]+?)\. Where should we pick up\?$/,
    /^Good to see you\. What's next\?$/,
    /^Good to see you, ([\s\S]+?)\. What's next\?$/
  ];
  function translate(value) {
    const source = value.trim();
    let result = phrases.get(source) ?? phrases.get(source.toLowerCase());
    if (result === undefined) {
      for (let i = 0; i < greetingPatterns.length; i++) {
        const match = source.match(greetingPatterns[i]);
        if (match) {
          result = locale.greetings[i].replace('{name}', () => match[1] || '');
          break;
        }
      }
    }
    if (result === undefined) {
      const match = source.match(/^(\d+)\s*(s|m|h|d|w|mo|y|seconds?|minutes?|hours?|days?|weeks?|months?|years?)\s+ago$/i);
      if (match) {
        const units = { s: 'second', m: 'minute', h: 'hour', d: 'day', w: 'week', mo: 'month', y: 'year' };
        const raw = match[2].toLowerCase();
        result = rtf.format(-Number(match[1]), units[raw] || raw.replace(/s$/, ''));
      } else if (/^(just now|now)$/i.test(source)) result = rtf.format(0, 'second');
    }
    if (result === undefined) {
      const match = source.match(/^See all\s*\((\d+)\)$/i);
      if (match && phrases.get('see all')) result = `${phrases.get('see all')} (${match[1]})`;
    }
    if (result === undefined) {
      const match = source.match(/^(Analyzed|Analyzing|Editing|Edited|Creating|Created|Updating|Updated|Deleting|Deleted|Reading|Writing|Wrote|Listing|Listed|Checking|Checked|Viewing|Viewed|Exploring|Invoking|Invoked|Starting|Started|Running)\s+(Task Logs?|[^\r\n]+?\.[a-z0-9]{1,8}(?:\s+#L\d+(?:-\d+)?)?)$/i);
      if (match) result = `${phrases.get(match[1].toLowerCase())} ${phrases.get(match[2].toLowerCase()) || match[2]}`;
    }
    if (result === undefined) return value;
    return value.replace(source, () => result);
  }
  function skip(element) {
    if (!element) return true;
    if (element.closest('script, style, pre, code, textarea, input, [contenteditable="true"], .monaco-editor, .xterm, [data-testid="user-message-bubble"], [data-testid="user-message-content"], .agy-user-bubble, .agy-user-bubble-frame')) return true;
    // Conversation titles are user content, not UI labels.
    if (element.closest('[data-testid^="conversation-row-"], [data-testid="side-question-row"], [data-testid="breadcrumb-segment"], [data-testid="subagent-node"]') && !element.closest('button, [role="button"]')) return true;
    const user = element.closest('[data-testid="user-input-step"], [aria-label="User message"]');
    if (user && !element.closest('[data-testid="user-message-actions"], button, [role="button"], time')) return true;
    const response = element.closest('[aria-label="Agent response"], [data-testid="agent-response"]');
    if (response && !element.closest('button, [role="button"], [data-testid="cascade-system-message-toolbar"], [data-testid="cleared-step-notice"], .files-changed-header, [data-screenshot-volatile]')) return true;
    return false;
  }
  function patchText(node) {
    if (skip(node.parentElement)) return;
    const record = texts.get(node);
    const source = record && node.nodeValue === record.value ? record.source : node.nodeValue;
    const value = translate(source || '');
    if (value !== node.nodeValue) {
      texts.set(node, { source, value });
      node.nodeValue = value;
    }
  }
  function patchAttrs(element) {
    if (skip(element)) return;
    for (const name of ['title', 'aria-label', 'placeholder', 'data-tooltip-content']) {
      if (!element.hasAttribute(name)) continue;
      let records = attrs.get(element);
      const record = records?.get(name);
      const current = element.getAttribute(name);
      const source = record && current === record.value ? record.source : current;
      const value = translate(source);
      if (value !== current) {
        if (!records) attrs.set(element, (records = new Map()));
        records.set(name, { source, value });
        element.setAttribute(name, value);
      }
    }
  }
  function patchNls() {
    // Match original messages, never version-dependent numeric indexes.
    const messages = window._VSCODE_NLS_MESSAGES;
    if (!Array.isArray(messages)) return;
    for (let i = 0; i < messages.length; i++) {
      if (typeof messages[i] !== 'string') continue;
      const value = translate(messages[i]);
      if (value !== messages[i]) {
        nlsChanges.push([messages, i, messages[i], value]);
        messages[i] = value;
      }
    }
  }
  function sweep() {
    scheduled = false;
    if (!active) return;
    patchNls();
    const walker = document.createTreeWalker(document, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT);
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      if (node.nodeType === Node.TEXT_NODE) patchText(node);
      else patchAttrs(node);
    }
    // Release detached nodes; the overlay can run throughout a long IDE session.
    for (const node of texts.keys()) if (!node.isConnected) texts.delete(node);
    for (const node of attrs.keys()) if (!node.isConnected) attrs.delete(node);
  }
  function cleanup() {
    active = false;
    observer?.disconnect();
    window.removeEventListener('DOMContentLoaded', run);
    for (const [node, record] of texts) if (node.nodeValue === record.value) node.nodeValue = record.source;
    for (const [element, records] of attrs) {
      for (const [name, record] of records) if (element.getAttribute(name) === record.value) element.setAttribute(name, record.source);
    }
    for (let i = nlsChanges.length - 1; i >= 0; i--) {
      const [messages, index, source, value] = nlsChanges[i];
      if (messages[index] === value) messages[index] = source;
    }
    document.documentElement.lang = originalLang;
    texts.clear(); attrs.clear();
    window.__antigravityZhPatchInstalled = false;
    delete window.__antigravityZhSetLang;
  }
  function run() {
    if (!active) return;
    document.documentElement.lang = locale.code;
    sweep();
    observer = new MutationObserver(() => {
      if (!scheduled && active) {
        scheduled = true;
        queueMicrotask(sweep);
      }
    });
    observer.observe(document, { subtree: true, childList: true, characterData: true, attributes: true,
      attributeFilter: ['title', 'aria-label', 'placeholder', 'data-tooltip-content'] });
  }
  window.__antigravityZhPatchInstalled = true;
  window.__observedDocument = document;
  window.__antigravityZhPatchFingerprint = fingerprint;
  window.__antigravityZhPatchCleanup = cleanup;
  window.__antigravityZhSetLang = value => { if (value === 'en') cleanup(); };
  if (document.readyState === 'loading') window.addEventListener('DOMContentLoaded', run, { once: true });
  else run();
})(/*__AGY_LOCALE__*/);
