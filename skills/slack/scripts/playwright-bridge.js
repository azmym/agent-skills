#!/usr/bin/env node
// Playwright bridge for Slack browser automation.
// Usage: node playwright-bridge.js --function <fn> --session <id|new> --input '<json>'
//
// Functions: open, execute, interact, snapshot, screenshot, close

const { chromium } = require("playwright-chromium");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const os = require("os");

const SESSIONS_DIR = path.join(
  os.homedir(),
  ".agents",
  "config",
  "slack",
  "sessions"
);

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------
function parseArgs() {
  const args = process.argv.slice(2);
  const parsed = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--function" && args[i + 1]) parsed.fn = args[++i];
    else if (args[i] === "--session" && args[i + 1]) parsed.session = args[++i];
    else if (args[i] === "--input" && args[i + 1]) parsed.input = args[++i];
    else if (args[i] === "--headed") parsed.headed = true;
  }
  return parsed;
}

// ---------------------------------------------------------------------------
// Session helpers
// ---------------------------------------------------------------------------
function sessionDir(id) {
  return path.join(SESSIONS_DIR, id);
}

function storagePath(id) {
  return path.join(sessionDir(id), "storageState.json");
}

function refsPath(id) {
  return path.join(sessionDir(id), "refs.json");
}

function ensureSessionDir(id) {
  const dir = sessionDir(id);
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

// ---------------------------------------------------------------------------
// Browser launch helper
// ---------------------------------------------------------------------------
async function launchBrowser(sessionId, opts = {}) {
  const headless = !opts.headed;
  const browser = await chromium.launch({ headless });
  const contextOpts = {};
  const stPath = storagePath(sessionId);
  if (fs.existsSync(stPath)) {
    contextOpts.storageState = stPath;
  }
  const context = await browser.newContext(contextOpts);
  const page = await context.newPage();
  return { browser, context, page };
}

async function saveState(context, sessionId) {
  const stPath = storagePath(sessionId);
  ensureSessionDir(sessionId);
  const state = await context.storageState();
  fs.writeFileSync(stPath, JSON.stringify(state, null, 2));
}

// ---------------------------------------------------------------------------
// Functions
// ---------------------------------------------------------------------------

async function fnOpen(sessionId, input) {
  const id = sessionId === "new" ? crypto.randomUUID() : sessionId;
  ensureSessionDir(id);

  const url = input.url || "https://app.slack.com";
  const headed = input.headed || false;
  const { browser, context, page } = await launchBrowser(id, { headed });

  try {
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 });
    await saveState(context, id);
    return { session_id: id };
  } finally {
    if (!headed) {
      await browser.close();
    }
  }
}

async function fnExecute(sessionId, input) {
  const { browser, context, page } = await launchBrowser(sessionId);
  try {
    const url = input.url || "https://app.slack.com";
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 });

    const code = input.code || input.script || "";
    const result = await page.evaluate(code);
    await saveState(context, sessionId);
    return { result: result };
  } finally {
    await browser.close();
  }
}

async function fnInteract(sessionId, input) {
  const { browser, context, page } = await launchBrowser(sessionId);
  try {
    const url = input.url || "https://app.slack.com";
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 });

    const action = input.action;
    if (!action) throw new Error("interact requires an 'action' field");

    switch (action) {
      case "wait":
        await page.waitForTimeout(input.ms || 1000);
        break;
      case "fill":
        await page.fill(input.selector, input.value || "");
        break;
      case "press":
        await page.press(input.selector || "body", input.key);
        break;
      case "click":
        if (input.selector) {
          await page.click(input.selector);
        } else if (input.ref) {
          // Use ref from snapshot
          const refs = loadRefs(sessionId);
          const sel = refs[input.ref];
          if (!sel) throw new Error(`Unknown ref: ${input.ref}`);
          await page.click(sel);
        }
        break;
      case "goto":
        await page.goto(input.url || url, {
          waitUntil: "domcontentloaded",
          timeout: 30000,
        });
        break;
      default:
        throw new Error(`Unknown action: ${action}`);
    }

    await saveState(context, sessionId);
    return { ok: true, action: action };
  } finally {
    await browser.close();
  }
}

function loadRefs(sessionId) {
  const rPath = refsPath(sessionId);
  if (fs.existsSync(rPath)) {
    return JSON.parse(fs.readFileSync(rPath, "utf8"));
  }
  return {};
}

async function fnSnapshot(sessionId, input) {
  const { browser, context, page } = await launchBrowser(sessionId);
  try {
    const url = input.url || "https://app.slack.com";
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 });

    // Enumerate interactive elements and assign @eN refs
    const elements = await page.evaluate(() => {
      const selectors = [
        "a[href]",
        "button",
        'input:not([type="hidden"])',
        "textarea",
        "select",
        '[role="button"]',
        '[role="link"]',
        '[role="textbox"]',
        '[contenteditable="true"]',
      ];
      const results = [];
      const seen = new Set();
      for (const sel of selectors) {
        for (const el of document.querySelectorAll(sel)) {
          if (seen.has(el)) continue;
          seen.add(el);
          const tag = el.tagName.toLowerCase();
          const type = el.getAttribute("type") || "";
          const role = el.getAttribute("role") || "";
          const text = (
            el.textContent ||
            el.getAttribute("aria-label") ||
            el.getAttribute("placeholder") ||
            ""
          )
            .trim()
            .slice(0, 80);
          const id = el.id || "";
          const name = el.getAttribute("name") || "";

          // Build a unique CSS selector for this element
          let cssSel = tag;
          if (id) cssSel = `#${CSS.escape(id)}`;
          else if (name) cssSel = `${tag}[name="${CSS.escape(name)}"]`;
          else if (type) cssSel = `${tag}[type="${type}"]`;
          else if (role) cssSel = `[role="${role}"]`;

          results.push({ tag, type, role, text, cssSel, id, name });
        }
      }
      return results;
    });

    // Assign refs
    const refs = {};
    const output = [];
    elements.forEach((el, i) => {
      const ref = `@e${i + 1}`;
      refs[ref] = el.cssSel;
      const desc = [el.tag];
      if (el.type) desc.push(`type=${el.type}`);
      if (el.role) desc.push(`role=${el.role}`);
      if (el.text) desc.push(`"${el.text}"`);
      output.push(`${ref}: ${desc.join(" ")}`);
    });

    // Save refs
    ensureSessionDir(sessionId);
    fs.writeFileSync(refsPath(sessionId), JSON.stringify(refs, null, 2));
    await saveState(context, sessionId);

    return { elements: output, count: output.length };
  } finally {
    await browser.close();
  }
}

async function fnScreenshot(sessionId, input) {
  const { browser, context, page } = await launchBrowser(sessionId);
  try {
    const url = input.url || "https://app.slack.com";
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 });

    const tmpFile = path.join(
      os.tmpdir(),
      `slack-screenshot-${Date.now()}.png`
    );
    await page.screenshot({ path: tmpFile, fullPage: false });
    await saveState(context, sessionId);

    return { screenshot: tmpFile };
  } finally {
    await browser.close();
  }
}

async function fnClose(sessionId) {
  const dir = sessionDir(sessionId);
  if (fs.existsSync(dir)) {
    fs.rmSync(dir, { recursive: true, force: true });
  }
  return { ok: true, closed: sessionId };
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
  const args = parseArgs();
  if (!args.fn) {
    console.error(
      "Usage: node playwright-bridge.js --function <fn> --session <id|new> --input '<json>'"
    );
    process.exit(1);
  }

  const sessionId = args.session || "default";
  let input = {};
  if (args.input) {
    try {
      input = JSON.parse(args.input);
    } catch (e) {
      console.error(`Invalid JSON input: ${e.message}`);
      process.exit(1);
    }
  }
  if (args.headed) {
    input.headed = true;
  }

  let result;
  switch (args.fn) {
    case "open":
      result = await fnOpen(sessionId, input);
      break;
    case "execute":
      result = await fnExecute(sessionId, input);
      break;
    case "interact":
      result = await fnInteract(sessionId, input);
      break;
    case "snapshot":
      result = await fnSnapshot(sessionId, input);
      break;
    case "screenshot":
      result = await fnScreenshot(sessionId, input);
      break;
    case "close":
      result = await fnClose(sessionId);
      break;
    default:
      console.error(`Unknown function: ${args.fn}`);
      process.exit(1);
  }

  console.log(JSON.stringify(result));
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
