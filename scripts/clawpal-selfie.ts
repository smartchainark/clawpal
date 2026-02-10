/**
 * Clawpal Selfie - Edit reference image and send via OpenClaw
 *
 * Usage:
 *   npx ts-node clawpal-selfie.ts "<user_context>" "<channel>" ["<mode>"] ["<caption>"]
 *
 * Environment variables:
 *   CLAWPAL_PROVIDER - Provider: fal or replicate (default: auto-detect from available keys)
 *   FAL_KEY - fal.ai API key (for fal provider)
 *   REPLICATE_API_TOKEN - Replicate API token (for replicate provider)
 *   CLAWPAL_REFERENCE_IMAGE - Custom reference image URL (optional)
 *   OPENCLAW_GATEWAY_URL - OpenClaw gateway URL (default: http://localhost:18789)
 *   OPENCLAW_GATEWAY_TOKEN - Gateway auth token (optional)
 */

import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

// Default reference image (override via CLAWPAL_REFERENCE_IMAGE env var)
const REFERENCE_IMAGE =
  process.env.CLAWPAL_REFERENCE_IMAGE ||
  "https://cdn.jsdelivr.net/gh/smartchainark/clawpal@main/assets/clawpal.jpg";

// Types
interface GrokImagineEditInput {
  image_url: string;
  prompt: string;
  num_images?: number;
  output_format?: OutputFormat;
}

interface GrokImagineImage {
  url: string;
  content_type: string;
  file_name?: string;
  width: number;
  height: number;
}

interface GrokImagineResponse {
  images: GrokImagineImage[];
  revised_prompt?: string;
}

interface OpenClawMessage {
  action: "send";
  channel: string;
  message: string;
  media?: string;
}

type Provider = "fal" | "replicate";
type SelfieMode = "mirror" | "direct" | "auto";
type OutputFormat = "jpeg" | "png" | "webp";

interface EditAndSendOptions {
  userContext: string;
  channel: string;
  mode?: SelfieMode;
  caption?: string;
  outputFormat?: OutputFormat;
  useCLI?: boolean;
}

interface Result {
  success: boolean;
  imageUrl: string;
  channel: string;
  mode: string;
  prompt: string;
  provider: string;
  revisedPrompt?: string;
}

// Check for fal.ai client
let falClient: any;
try {
  const { fal } = require("@fal-ai/client");
  falClient = fal;
} catch {
  falClient = null;
}

/**
 * Auto-detect provider from available API keys
 */
function detectProvider(): Provider {
  const explicit = process.env.CLAWPAL_PROVIDER?.toLowerCase();
  if (explicit === "fal" || explicit === "replicate") return explicit;
  if (process.env.REPLICATE_API_TOKEN) return "replicate";
  if (process.env.FAL_KEY) return "fal";
  throw new Error(
    "No API key found. Set REPLICATE_API_TOKEN or FAL_KEY"
  );
}

/**
 * Auto-detect selfie mode from user context
 */
function detectMode(userContext: string): "mirror" | "direct" {
  const mirrorKeywords =
    /outfit|wearing|clothes|hoodie|jacket|suit|fashion|full-body|mirror/i;
  const directKeywords =
    /cafe|restaurant|beach|park|city|close-up|portrait|face|eyes|smile/i;

  if (directKeywords.test(userContext)) return "direct";
  if (mirrorKeywords.test(userContext)) return "mirror";
  return "mirror";
}

/**
 * Build edit prompt based on mode
 */
function buildPrompt(userContext: string, mode: "mirror" | "direct"): string {
  if (mode === "direct") {
    return `a close-up selfie taken by himself at ${userContext}, direct eye contact with the camera, looking straight into the lens, eyes centered and clearly visible, not a mirror selfie, phone held at arm's length, face fully visible`;
  }
  return `make a pic of this person, but ${userContext}. the person is taking a mirror selfie`;
}

/**
 * Edit reference image using Grok Imagine via fal.ai
 */
async function editImage(
  input: GrokImagineEditInput
): Promise<GrokImagineResponse> {
  const falKey = process.env.FAL_KEY;

  if (!falKey) {
    throw new Error(
      "FAL_KEY environment variable not set. Get your key from https://fal.ai/dashboard/keys"
    );
  }

  if (falClient) {
    falClient.config({ credentials: falKey });

    const result = await falClient.subscribe("xai/grok-imagine-image/edit", {
      input: {
        image_url: input.image_url,
        prompt: input.prompt,
        num_images: input.num_images || 1,
        output_format: input.output_format || "jpeg",
      },
    });

    return result.data as GrokImagineResponse;
  }

  // Fallback to fetch
  const response = await fetch("https://fal.run/xai/grok-imagine-image/edit", {
    method: "POST",
    headers: {
      Authorization: `Key ${falKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      image_url: input.image_url,
      prompt: input.prompt,
      num_images: input.num_images || 1,
      output_format: input.output_format || "jpeg",
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Image edit failed: ${error}`);
  }

  return response.json();
}

/**
 * Edit reference image using Flux Kontext Pro via Replicate
 */
async function editViaReplicate(
  imageUrl: string,
  prompt: string,
  outputFormat: string = "jpg"
): Promise<{ url: string }> {
  const token = process.env.REPLICATE_API_TOKEN;
  if (!token) throw new Error("REPLICATE_API_TOKEN not set");

  const createRes = await fetch(
    "https://api.replicate.com/v1/models/black-forest-labs/flux-kontext-pro/predictions",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        Prefer: "wait",
      },
      body: JSON.stringify({
        input: {
          prompt,
          input_image: imageUrl,
          aspect_ratio: "1:1",
          output_format: outputFormat === "jpeg" ? "jpg" : outputFormat,
        },
      }),
    }
  );

  if (!createRes.ok) {
    throw new Error(`Replicate failed: ${await createRes.text()}`);
  }

  let prediction = await createRes.json();

  // Poll if not yet completed
  while (prediction.status === "starting" || prediction.status === "processing") {
    await new Promise((r) => setTimeout(r, 2000));
    const pollRes = await fetch(
      `https://api.replicate.com/v1/predictions/${prediction.id}`,
      { headers: { Authorization: `Bearer ${token}` } }
    );
    prediction = await pollRes.json();
  }

  if (prediction.status === "failed") {
    throw new Error(`Replicate failed: ${prediction.error}`);
  }

  const outputUrl = Array.isArray(prediction.output)
    ? prediction.output[0]
    : prediction.output;

  return { url: outputUrl };
}

/**
 * Send image via OpenClaw
 */
async function sendViaOpenClaw(
  message: OpenClawMessage,
  useCLI: boolean = true
): Promise<void> {
  if (useCLI) {
    const cmd = `openclaw message send --action send --channel "${message.channel}" --message "${message.message}" --media "${message.media}"`;
    await execAsync(cmd);
    return;
  }

  const gatewayUrl =
    process.env.OPENCLAW_GATEWAY_URL || "http://localhost:18789";
  const gatewayToken = process.env.OPENCLAW_GATEWAY_TOKEN;

  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };

  if (gatewayToken) {
    headers["Authorization"] = `Bearer ${gatewayToken}`;
  }

  const response = await fetch(`${gatewayUrl}/message`, {
    method: "POST",
    headers,
    body: JSON.stringify(message),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`OpenClaw send failed: ${error}`);
  }
}

/**
 * Main: Edit reference image and send to channel
 */
async function editAndSend(options: EditAndSendOptions): Promise<Result> {
  const {
    userContext,
    channel,
    mode = "auto",
    caption = "Selfie from Clawpal",
    outputFormat = "jpeg",
    useCLI = true,
  } = options;

  const provider = detectProvider();
  const actualMode = mode === "auto" ? detectMode(userContext) : mode;
  const editPrompt = buildPrompt(userContext, actualMode);

  console.log(`[INFO] Provider: ${provider}`);
  console.log(`[INFO] Mode: ${actualMode}`);
  console.log(`[INFO] Editing reference image: "${editPrompt}"`);

  let imageUrl: string;
  let revisedPrompt: string | undefined;

  if (provider === "replicate") {
    const result = await editViaReplicate(REFERENCE_IMAGE, editPrompt, outputFormat);
    imageUrl = result.url;
  } else {
    const imageResult = await editImage({
      image_url: REFERENCE_IMAGE,
      prompt: editPrompt,
      num_images: 1,
      output_format: outputFormat,
    });
    imageUrl = imageResult.images[0].url;
    revisedPrompt = imageResult.revised_prompt;
  }

  console.log(`[INFO] Image edited: ${imageUrl.substring(0, 80)}...`);

  console.log(`[INFO] Sending to ${channel}`);
  await sendViaOpenClaw(
    { action: "send", channel, message: caption, media: imageUrl },
    useCLI
  );

  console.log(`[INFO] Done!`);

  return {
    success: true,
    imageUrl,
    channel,
    mode: actualMode,
    prompt: editPrompt,
    provider,
    revisedPrompt,
  };
}

// CLI entry point
async function main() {
  const args = process.argv.slice(2);

  if (args.length < 2) {
    console.log(`
Usage: npx ts-node clawpal-selfie.ts <user_context> <channel> [mode] [caption]

Arguments:
  user_context  - Scene description (required)
  channel       - Target channel (required) e.g., #general, @user
  mode          - mirror, direct, or auto (default: auto)
  caption       - Message caption (optional)

Environment:
  CLAWPAL_PROVIDER         - fal or replicate (default: auto-detect)
  FAL_KEY                  - fal.ai API key
  REPLICATE_API_TOKEN      - Replicate API token
  CLAWPAL_REFERENCE_IMAGE  - Custom reference image URL (optional)

Example:
  REPLICATE_API_TOKEN=r8_xxx npx ts-node clawpal-selfie.ts "at a cozy cafe" "#general" direct "Coffee time!"
`);
    process.exit(1);
  }

  const [userContext, channel, mode, caption] = args;

  try {
    const result = await editAndSend({
      userContext,
      channel,
      mode: (mode as SelfieMode) || "auto",
      caption,
    });

    console.log("\n--- Result ---");
    console.log(JSON.stringify(result, null, 2));
  } catch (error) {
    console.error(`[ERROR] ${(error as Error).message}`);
    process.exit(1);
  }
}

export {
  editImage,
  editViaReplicate,
  sendViaOpenClaw,
  editAndSend,
  detectMode,
  detectProvider,
  buildPrompt,
  GrokImagineEditInput,
  GrokImagineResponse,
  OpenClawMessage,
  EditAndSendOptions,
  Result,
};

if (require.main === module) {
  main();
}
