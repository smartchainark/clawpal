#!/usr/bin/env node
/**
 * Tencent Hunyuan Image - Clawpal Selfie Module
 *
 * Usage (called by selfie.sh):
 *   node hunyuan-selfie.mjs --prompt "scene description" --image "reference_url" [--output /tmp]
 *
 * Environment:
 *   TENCENT_SECRET_ID   - Tencent Cloud SecretId
 *   TENCENT_SECRET_KEY  - Tencent Cloud SecretKey
 *
 * Outputs JSON for shell parsing
 */

import { existsSync, mkdirSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { execFileSync } from 'child_process';
import https from 'https';
import http from 'http';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Read credentials from environment
const SECRET_ID = process.env.TENCENT_SECRET_ID;
const SECRET_KEY = process.env.TENCENT_SECRET_KEY;
const REGION = process.env.TENCENT_REGION || 'ap-guangzhou';

if (!SECRET_ID || !SECRET_KEY) {
  console.error(JSON.stringify({
    success: false,
    error: 'Missing TENCENT_SECRET_ID or TENCENT_SECRET_KEY environment variables'
  }));
  process.exit(1);
}

// Check and install dependencies
const sdkPath = join(__dirname, 'node_modules', 'tencentcloud-sdk-nodejs-aiart');
if (!existsSync(sdkPath)) {
  console.error('Installing tencentcloud-sdk-nodejs-aiart...');
  execFileSync('npm', ['install', 'tencentcloud-sdk-nodejs-aiart'], { cwd: __dirname, stdio: 'inherit' });
}

// Dynamic import SDK
const aiartSdk = await import('tencentcloud-sdk-nodejs-aiart');
const AiartClient = aiartSdk.aiart.v20221229.Client;

function createClient() {
  return new AiartClient({
    credential: { secretId: SECRET_ID, secretKey: SECRET_KEY },
    region: REGION,
    profile: { httpProfile: { endpoint: 'aiart.tencentcloudapi.com' } },
  });
}

async function submitJob(client, prompt, images = []) {
  const params = {
    Prompt: prompt,
    LogoAdd: 0,
    Revise: 1,
  };

  if (images.length > 0) {
    params.Images = images.slice(0, 3);
  }

  const resp = await client.SubmitTextToImageJob(params);
  return resp.JobId;
}

async function queryJob(client, jobId) {
  return client.QueryTextToImageJob({ JobId: jobId });
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function waitForResult(client, jobId, timeout = 120000) {
  const startTime = Date.now();
  let retryCount = 0;

  while (true) {
    const elapsed = Date.now() - startTime;
    if (elapsed > timeout) throw new Error('Timeout');

    try {
      const result = await queryJob(client, jobId);
      retryCount = 0;

      if (result.JobStatusCode === '5') return result;
      if (result.JobStatusCode === '4') throw new Error(result.JobErrorMsg || 'Job failed');

      // Progress to stderr (JSON output to stdout)
      console.error(`Waiting... (${Math.floor(elapsed / 1000)}s)`);
    } catch (err) {
      if (err.httpCode && retryCount < 3) {
        retryCount++;
        console.error(`Network error, retry ${retryCount}/3...`);
      } else {
        throw err;
      }
    }

    await sleep(3000);
  }
}

function downloadFile(url, filepath) {
  return new Promise((resolve, reject) => {
    const client = url.startsWith('https') ? https : http;
    client.get(url, (response) => {
      if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
        return downloadFile(response.headers.location, filepath).then(resolve).catch(reject);
      }
      const chunks = [];
      response.on('data', chunk => chunks.push(chunk));
      response.on('end', () => {
        writeFileSync(filepath, Buffer.concat(chunks));
        resolve();
      });
      response.on('error', reject);
    }).on('error', reject);
  });
}

function parseArgs(args) {
  const result = { prompt: null, image: null, output: null };

  let i = 0;
  while (i < args.length) {
    const arg = args[i];
    if (arg === '--prompt' || arg === '-p') {
      result.prompt = args[++i];
    } else if (arg === '--image' || arg === '-i') {
      result.image = args[++i];
    } else if (arg === '--output' || arg === '-o') {
      result.output = args[++i];
    }
    i++;
  }

  return result;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (!args.prompt) {
    console.error(JSON.stringify({
      success: false,
      error: 'Missing --prompt argument'
    }));
    process.exit(1);
  }

  try {
    const client = createClient();
    const images = args.image ? [args.image] : [];

    console.error(`Submitting job: ${args.prompt.substring(0, 50)}...`);
    const jobId = await submitJob(client, args.prompt, images);
    console.error(`JobId: ${jobId}`);

    const result = await waitForResult(client, jobId);
    const imageUrl = result.ResultImage[0];

    let localPath = null;
    if (args.output) {
      mkdirSync(args.output, { recursive: true });
      const filename = `hunyuan_${Date.now()}.png`;
      localPath = join(args.output, filename);
      await downloadFile(imageUrl, localPath);
      console.error(`Downloaded: ${localPath}`);
    }

    // Output JSON result to stdout
    console.log(JSON.stringify({
      success: true,
      image_url: imageUrl,
      local_path: localPath,
      provider: 'hunyuan',
      mode: images.length > 0 ? 'img2img' : 'txt2img'
    }));

  } catch (err) {
    console.error(JSON.stringify({
      success: false,
      error: err.message || String(err)
    }));
    process.exit(1);
  }
}

main();
