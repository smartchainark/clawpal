#!/usr/bin/env node

/**
 * Clawpal v2 — AI Character Installer for OpenClaw
 *
 * 3-step wizard: pick character → enter API key → done
 *
 * npx clawpal@latest
 */

const fs = require("fs");
const path = require("path");
const readline = require("readline");
const { execSync } = require("child_process");
const os = require("os");

// ── Colors ──────────────────────────────────────────────────────────────────

const colors = {
  reset: "\x1b[0m",
  bright: "\x1b[1m",
  dim: "\x1b[2m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  magenta: "\x1b[35m",
  cyan: "\x1b[36m",
};

const c = (color, text) => `${colors[color]}${text}${colors.reset}`;

// ── Paths ───────────────────────────────────────────────────────────────────

const HOME = os.homedir();
const OPENCLAW_DIR = path.join(HOME, ".openclaw");
const OPENCLAW_CONFIG = path.join(OPENCLAW_DIR, "openclaw.json");
const OPENCLAW_SKILLS_DIR = path.join(OPENCLAW_DIR, "skills");
const OPENCLAW_WORKSPACE = path.join(OPENCLAW_DIR, "workspace");
const SOUL_MD = path.join(OPENCLAW_WORKSPACE, "SOUL.md");
const IDENTITY_MD = path.join(OPENCLAW_WORKSPACE, "IDENTITY.md");
const SKILL_NAME = "clawpal";
const SKILL_DEST = path.join(OPENCLAW_SKILLS_DIR, SKILL_NAME);
const PACKAGE_ROOT = path.resolve(__dirname, "..");

// ── Helpers ─────────────────────────────────────────────────────────────────

function log(msg) {
  console.log(msg);
}
function logSuccess(msg) {
  console.log(`  ${c("green", "\u2713")} ${msg}`);
}
function logError(msg) {
  console.log(`  ${c("red", "\u2717")} ${msg}`);
}
function logInfo(msg) {
  console.log(`  ${c("blue", "\u2192")} ${msg}`);
}
function logWarn(msg) {
  console.log(`  ${c("yellow", "!")} ${msg}`);
}

function createPrompt() {
  return readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
}

function ask(rl, question) {
  return new Promise((resolve) => {
    rl.question(question, (answer) => resolve(answer.trim()));
  });
}

function commandExists(cmd) {
  try {
    execSync(`which ${cmd}`, { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

function readJsonFile(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return null;
  }
}

function writeJsonFile(filePath, data) {
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + "\n");
}

function deepMerge(target, source) {
  const result = { ...target };
  for (const key in source) {
    if (
      source[key] &&
      typeof source[key] === "object" &&
      !Array.isArray(source[key])
    ) {
      result[key] = deepMerge(result[key] || {}, source[key]);
    } else {
      result[key] = source[key];
    }
  }
  return result;
}

function copyDir(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDir(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

// ── Lightweight YAML parser ─────────────────────────────────────────────────
// Handles: simple key-value, quoted strings, nested objects (indent-based),
// multiline | blocks, and - item arrays. Sufficient for character YAML files.

function parseYaml(text) {
  const result = {};
  const lines = text.split("\n");
  let i = 0;

  function getIndent(line) {
    const m = line.match(/^(\s*)/);
    return m ? m[1].length : 0;
  }

  function parseValue(raw) {
    raw = raw.trim();
    if (raw === "" || raw === "~" || raw === "null") return "";
    // Strip surrounding quotes
    if (
      (raw.startsWith('"') && raw.endsWith('"')) ||
      (raw.startsWith("'") && raw.endsWith("'"))
    ) {
      raw = raw.slice(1, -1);
    }
    // Handle unicode escapes like \U0001F499
    raw = raw.replace(/\\U([0-9A-Fa-f]{8})/g, (_, hex) =>
      String.fromCodePoint(parseInt(hex, 16))
    );
    raw = raw.replace(/\\u([0-9A-Fa-f]{4})/g, (_, hex) =>
      String.fromCodePoint(parseInt(hex, 16))
    );
    return raw;
  }

  function parseBlock(baseIndent) {
    const obj = {};

    while (i < lines.length) {
      const line = lines[i];

      // Skip empty lines and comments
      if (line.trim() === "" || line.trim().startsWith("#")) {
        i++;
        continue;
      }

      const indent = getIndent(line);
      if (indent < baseIndent) break;
      if (indent > baseIndent) {
        i++;
        continue;
      } // skip unexpected deeper lines

      const trimmed = line.trim();

      // Key: value
      const kvMatch = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)/);
      if (!kvMatch) {
        i++;
        continue;
      }

      const key = kvMatch[1];
      let val = kvMatch[2].trim();
      i++;

      if (val === "|") {
        // Multiline block scalar
        let block = "";
        while (i < lines.length) {
          const bline = lines[i];
          if (bline.trim() === "") {
            block += "\n";
            i++;
            continue;
          }
          if (getIndent(bline) <= baseIndent) break;
          block += (block && !block.endsWith("\n") ? "\n" : "") + bline.replace(/^ {2,}/, "").trimStart();
          i++;
        }
        obj[key] = block.replace(/\n+$/, "\n");
      } else if (val === "") {
        // Could be a nested object or array
        if (i < lines.length && lines[i] && getIndent(lines[i]) > baseIndent) {
          // Check if next non-empty line starts with "- "
          let nextIdx = i;
          while (nextIdx < lines.length && lines[nextIdx].trim() === "")
            nextIdx++;
          if (nextIdx < lines.length && lines[nextIdx].trim().startsWith("- ")) {
            // Array
            const arr = [];
            const arrIndent = getIndent(lines[nextIdx]);
            while (i < lines.length) {
              if (lines[i].trim() === "") {
                i++;
                continue;
              }
              if (getIndent(lines[i]) < arrIndent) break;
              const item = lines[i].trim();
              if (item.startsWith("- ")) {
                arr.push(parseValue(item.slice(2)));
              }
              i++;
            }
            obj[key] = arr;
          } else {
            // Nested object
            obj[key] = parseBlock(getIndent(lines[nextIdx]));
          }
        } else {
          obj[key] = "";
        }
      } else {
        obj[key] = parseValue(val);
      }
    }

    return obj;
  }

  i = 0;
  return parseBlock(0);
}

// ── Template renderer ───────────────────────────────────────────────────────

function renderTemplate(template, data) {
  return template.replace(/\{\{(\w+(?:\.\w+)*)\}\}/g, (_, key) => {
    const val = key.split(".").reduce((obj, k) => obj?.[k], data);
    if (Array.isArray(val)) return val.join(", ");
    return val ?? "";
  });
}

// ── Character loading ───────────────────────────────────────────────────────

function loadCharacters() {
  const charDir = path.join(PACKAGE_ROOT, "characters");
  const chars = [];

  if (!fs.existsSync(charDir)) return chars;

  for (const file of fs.readdirSync(charDir)) {
    if (!file.endsWith(".yaml")) continue;
    const content = fs.readFileSync(path.join(charDir, file), "utf8");
    const data = parseYaml(content);
    data._file = file;
    chars.push(data);
  }

  return chars;
}

// ── Main installer ──────────────────────────────────────────────────────────

async function main() {
  const rl = createPrompt();

  try {
    // Banner
    console.log(`
${c("magenta", "\u250C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510")}
${c("magenta", "\u2502")}  ${c("bright", "Clawpal v2")} - Character Installer       ${c("magenta", "\u2502")}
${c("magenta", "\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518")}
`);

    // Check prerequisites
    if (!commandExists("openclaw")) {
      logError("OpenClaw CLI not found!");
      logInfo("Install with: npm install -g openclaw");
      rl.close();
      process.exit(1);
    }

    // Ensure directories
    fs.mkdirSync(OPENCLAW_SKILLS_DIR, { recursive: true });
    fs.mkdirSync(OPENCLAW_WORKSPACE, { recursive: true });

    // Check for existing installation
    if (fs.existsSync(SKILL_DEST)) {
      logWarn("Clawpal is already installed!");
      logInfo(`Location: ${SKILL_DEST}`);
      const reinstall = await ask(rl, "\n  Reinstall/update? (y/N): ");
      if (reinstall.toLowerCase() !== "y") {
        log("\n  No changes made. Goodbye!");
        rl.close();
        process.exit(0);
      }
      fs.rmSync(SKILL_DEST, { recursive: true, force: true });
      logInfo("Removed existing installation");
      log("");
    }

    // ── Step 1: Choose character ──────────────────────────────────────────

    log(c("cyan", "  Step 1/3: Choose your character\n"));

    const characters = loadCharacters();
    if (characters.length === 0) {
      logError("No character templates found!");
      rl.close();
      process.exit(1);
    }

    for (let i = 0; i < characters.length; i++) {
      const ch = characters[i];
      const emoji = ch.emoji || "";
      const vibe = ch.personality?.vibe || "";
      log(
        `    ${c("cyan", `${i + 1})`)} ${emoji} ${c("bright", ch.name)} \u2014 ${ch.tagline || vibe}`
      );
    }

    log("");
    const charChoice = await ask(rl, "  > ");
    const charIdx = parseInt(charChoice, 10) - 1;

    if (isNaN(charIdx) || charIdx < 0 || charIdx >= characters.length) {
      logError("Invalid choice");
      rl.close();
      process.exit(1);
    }

    const chosen = characters[charIdx];
    log("");
    logSuccess(`Selected: ${chosen.emoji || ""} ${chosen.name}`);

    // Check reference image
    let referenceImage = chosen.appearance?.reference_image || "";

    if (!referenceImage) {
      log("");
      logWarn(`${chosen.name} has no reference image configured.`);
      logInfo("A reference image is needed for selfies and videos.");
      const imgUrl = await ask(
        rl,
        `  Paste a reference image URL for ${chosen.name} (or Enter to skip): `
      );
      if (imgUrl) {
        referenceImage = imgUrl;
        chosen.appearance = chosen.appearance || {};
        chosen.appearance.reference_image = imgUrl;
        logSuccess("Reference image set");
      } else {
        logInfo("Skipped — selfie will be disabled, voice + video still work");
      }
    }

    // ── Step 2: API key ───────────────────────────────────────────────────

    log(`\n${c("cyan", "  Step 2/3: Set up API keys\n")}`);

    log(`    Replicate token (for selfie + video):`);
    log(
      `    ${c("dim", "Get from: https://replicate.com/account/api-tokens")}`
    );
    const replicateKey = await ask(rl, "    > ");

    let falKey = "";
    if (!replicateKey) {
      log(`\n    fal.ai key (for selfie only — no video):`);
      log(`    ${c("dim", "Get from: https://fal.ai/dashboard/keys")}`);
      falKey = await ask(rl, "    > ");
    }

    if (!replicateKey && !falKey) {
      logWarn("No API key entered — selfie and video will not work.");
      logInfo("Voice messages still work (Edge TTS is free).");
      logInfo("You can add keys later in ~/.openclaw/openclaw.json");
    }

    log(`\n    ${c("dim", "Voice is free via Edge TTS \u2014 no key needed!")}`);

    // ── Step 3: Install ───────────────────────────────────────────────────

    log(`\n${c("cyan", "  Step 3/3: Installing...\n")}`);

    // 3a. Copy skill files
    const skillSrc = path.join(PACKAGE_ROOT, "skill");
    if (fs.existsSync(skillSrc)) {
      copyDir(skillSrc, SKILL_DEST);
    } else {
      // Dev mode: assemble from source
      fs.mkdirSync(SKILL_DEST, { recursive: true });
      const devFiles = [
        { src: "SKILL.md", dest: "SKILL.md" },
      ];
      for (const { src, dest } of devFiles) {
        const srcPath = path.join(PACKAGE_ROOT, src);
        if (fs.existsSync(srcPath)) {
          fs.copyFileSync(srcPath, path.join(SKILL_DEST, dest));
        }
      }
      const devDirs = ["scripts", "assets"];
      for (const dir of devDirs) {
        const srcDir = path.join(PACKAGE_ROOT, dir);
        if (fs.existsSync(srcDir)) {
          copyDir(srcDir, path.join(SKILL_DEST, dir));
        }
      }
    }
    logSuccess("Skill files installed");

    // 3b. Write character.yaml to skill dir
    const charSrcPath = path.join(PACKAGE_ROOT, "characters", chosen._file);
    let charContent = fs.readFileSync(charSrcPath, "utf8");

    // Patch reference_image if user provided one
    if (
      referenceImage &&
      referenceImage !== (chosen.appearance?.reference_image || "")
    ) {
      // Replace in YAML content — find the reference_image line
      charContent = charContent.replace(
        /reference_image:\s*".*"/,
        `reference_image: "${referenceImage}"`
      );
    } else if (referenceImage && !charContent.includes("reference_image:")) {
      // This shouldn't happen with our templates, but just in case
    }

    fs.writeFileSync(path.join(SKILL_DEST, "character.yaml"), charContent);
    logSuccess("character.yaml written");

    // 3c. Check edge-tts
    if (commandExists("edge-tts") || commandExists("python3")) {
      logSuccess("Edge TTS ready");
    } else {
      logWarn("edge-tts will be auto-installed on first voice message");
    }

    // 3d. Update OpenClaw config
    let config = readJsonFile(OPENCLAW_CONFIG) || {};

    const env = {};
    if (replicateKey) env.REPLICATE_API_TOKEN = replicateKey;
    if (falKey) env.FAL_KEY = falKey;

    const skillConfig = {
      skills: {
        entries: {
          [SKILL_NAME]: {
            enabled: true,
            ...(Object.keys(env).length > 0 ? { env } : {}),
          },
        },
      },
    };

    config = deepMerge(config, skillConfig);

    if (!config.skills.load) config.skills.load = {};
    if (!config.skills.load.extraDirs) config.skills.load.extraDirs = [];
    if (!config.skills.load.extraDirs.includes(OPENCLAW_SKILLS_DIR)) {
      config.skills.load.extraDirs.push(OPENCLAW_SKILLS_DIR);
    }

    writeJsonFile(OPENCLAW_CONFIG, config);
    logSuccess("OpenClaw configured");

    // 3e. Render and write IDENTITY.md
    const identityTplPath = path.join(
      PACKAGE_ROOT,
      "templates",
      "identity.md.tpl"
    );
    if (fs.existsSync(identityTplPath)) {
      const tpl = fs.readFileSync(identityTplPath, "utf8");
      // Build flat data for template rendering
      const charData = parseYaml(charContent);
      // Add traits_joined for soul template
      if (charData.personality?.traits) {
        charData.personality.traits_joined =
          charData.personality.traits.join(", ");
      }
      const identityContent = renderTemplate(tpl, charData);
      fs.writeFileSync(IDENTITY_MD, identityContent);
    } else {
      // Fallback
      fs.writeFileSync(
        IDENTITY_MD,
        `# IDENTITY.md - Who Am I?\n\n- **Name:** ${chosen.name}\n- **Emoji:** ${chosen.emoji || ""}\n`
      );
    }
    logSuccess("IDENTITY.md created");

    // 3f. Render and inject SOUL.md
    const soulTplPath = path.join(
      PACKAGE_ROOT,
      "templates",
      "soul-injection.md.tpl"
    );
    const charData = parseYaml(charContent);
    if (charData.personality?.traits) {
      charData.personality.traits_joined =
        charData.personality.traits.join(", ");
    }

    let personaText;
    if (fs.existsSync(soulTplPath)) {
      const tpl = fs.readFileSync(soulTplPath, "utf8");
      personaText = renderTemplate(tpl, charData);
    } else {
      personaText = `## ${chosen.name} Capabilities\n\nYou are ${chosen.name}. You can take selfies, send voice messages, and create video clips.\n`;
    }

    // Also write rendered soul-injection.md to skill dir
    fs.writeFileSync(
      path.join(SKILL_DEST, "soul-injection.md"),
      personaText
    );

    // Inject into SOUL.md
    if (!fs.existsSync(SOUL_MD)) {
      fs.writeFileSync(SOUL_MD, "# Agent Soul\n\n");
    }

    let currentSoul = fs.readFileSync(SOUL_MD, "utf8");

    // Remove any existing Clawpal/character section
    const sectionPattern = new RegExp(
      `\\n## ${charData.name || "Clawpal"} Capabilities[\\s\\S]*?(?=\\n## |\\n# |$)`
    );
    currentSoul = currentSoul.replace(sectionPattern, "");

    // Also remove old v1 section if present
    currentSoul = currentSoul.replace(
      /\n## Clawpal Selfie Capability[\s\S]*?(?=\n## |\n# |$)/,
      ""
    );

    fs.writeFileSync(SOUL_MD, currentSoul.trimEnd() + "\n\n" + personaText.trim() + "\n");
    logSuccess("SOUL.md updated");

    // ── Summary ─────────────────────────────────────────────────────────

    const features = [];
    if (referenceImage) features.push("selfie");
    features.push("voice");
    if (replicateKey) features.push("video");

    console.log(`
${c("green", "\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501")}
  ${chosen.emoji || ""} ${c("bright", `${chosen.name} is ready!`)}  [${features.join(" + ")}]
${c("green", "\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501")}

${c("yellow", "  Try saying to your agent:")}
    "Send me a selfie"
    "Send a voice message saying hello"
    "Make a video of you waving"

${c("dim", `  Installed: ${SKILL_DEST}`)}
`);

    rl.close();
  } catch (error) {
    logError(`Installation failed: ${error.message}`);
    console.error(error);
    rl.close();
    process.exit(1);
  }
}

main();
