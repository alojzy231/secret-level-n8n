# Pancake Recipe Generator

A mini-project built during a Google Meet session on **n8n automation & AI prompting**.

The app has two parts:
- A **React frontend** (Vite + TypeScript + Tailwind) — a single button that fetches and displays a freshly generated pancake recipe with a typewriter animation.
- An **n8n workflow** that receives a webhook POST, sends the prompt to **Google Gemini 2.5 Flash**, and returns the generated recipe as JSON.

```
Browser → POST /webhook-test/pancake-recipe → n8n → Gemini 2.5 Flash → JSON response → React UI
```

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Node.js | 18+ | Required by both n8n and the frontend |
| pnpm | any | `npm install -g pnpm` if missing |
| Google Gemini API key | — | Free — see below |

### Getting a free Gemini API key

1. Go to **[aistudio.google.com/apikey](https://aistudio.google.com/apikey)** — sign in with any Google account.
2. Click **"Create API key"** → select or create a project → copy the key.
3. That's it — no billing setup required. Google AI Studio offers a **free tier** with generous rate limits, more than enough for this project.

---

## 1. Clone and install frontend dependencies

```bash
git clone <repo-url>
cd <repo-dir>
pnpm install
```

---

## 2. Start n8n locally

n8n runs entirely in your terminal — no Docker, no account required for local use.

```bash
npx n8n
```

On first run it downloads the n8n package (takes ~30 s). Once you see:

```
Editor is now accessible via:
http://localhost:5678/
```

open that URL in your browser. Create a local owner account when prompted (any email/password — it's only stored locally).

---

## 3. Import the workflow

1. In the n8n editor, click **"+"** in the top-left (or go to **Workflows → New**).
2. Click the **three-dot menu** (top-right of the canvas) → **Import from file**.
3. Select `pancake-recipe-webhook.workflow.json` from this repo.
4. The canvas should show three nodes: **Webhook → Google Gemini → Respond to Webhook**.

---

## 4. Add your Google Gemini credentials

1. Click the **Google Gemini** node on the canvas.
2. Under **Credential**, click **Create new credential**.
3. Paste your Gemini API key and save.

> The credential is named `Google Gemini(PaLM) Api account` in the workflow. n8n will match it automatically once you create it with that name, or you can rename it after creation.

---

## 5. Activate the workflow

Click the **Inactive** toggle (top-right) to set it to **Active**.

> **Important:** while the workflow is inactive, the webhook only responds to test executions. Activating it makes the webhook live on `http://localhost:5678/webhook/pancake-recipe`. The frontend is hardcoded to the **test** URL (`/webhook-test/pancake-recipe`), so for local development you can leave it inactive and use **"Test workflow"** instead — see step 7.

---

## 6. Start the frontend

In a second terminal tab:

```bash
pnpm dev
```

The app opens at **http://localhost:5173** (Vite default).

---

## 7. Test the full flow

### Via the React UI
1. Go to `http://localhost:5173`.
2. Click **"Get Pancake Recipe"**.
3. The recipe should appear with a typewriter animation.

### Via the n8n canvas (without the UI)
1. Click **"Test workflow"** in n8n.
2. In a separate terminal, trigger the webhook manually:
   ```bash
   curl -X POST http://localhost:5678/webhook-test/pancake-recipe \
     -H "Content-Type: application/json" \
     -d '{"prompt": "Give me a vegan pancake recipe"}'
   ```
3. Watch the execution trace in the n8n canvas — each node turns green on success.

---

## Architecture notes

| Detail | Value |
|--------|-------|
| Webhook path | `/webhook-test/pancake-recipe` (test mode) |
| HTTP method | `POST` |
| Request body | `{ "prompt": "..." }` — the `prompt` field is optional; the workflow has a default prompt |
| Response body | `{ "recipe": "<text from Gemini>" }` |
| AI model | `models/gemini-2.5-flash` |

The workflow node expression that reads the prompt:
```
={{ $json?.body?.prompt || 'Please give me a detailed classic pancake recipe...' }}
```

So the frontend can send any custom prompt and the workflow will use it; if the field is missing, the default kicks in.

---

## Common issues

### "Could not get a response" / fetch error in the UI

- n8n is not running — start it with `npx n8n`.
- The workflow is **Active** but you're hitting the test URL. Either deactivate the workflow (so test URL works), or change `N8N_WEBHOOK_URL` in `src/App.tsx` to `/webhook/pancake-recipe`.
- CORS blocked: n8n allows all origins by default on localhost, but if you changed the host, set `N8N_CORS_ENABLE=true` and `N8N_CORS_ALLOWED_ORIGINS=*` in your environment.

### "Webhook returned an empty response"

- The workflow executed but Gemini returned nothing — check the execution log in n8n for the Gemini node error.
- Usually means an invalid or missing API key (see step 4).

### "Request failed with status 404"

- The workflow was not imported, or the path is wrong. Confirm the Webhook node shows path `pancake-recipe`.

### "Request failed with status 401"

- Gemini API key is invalid or not set. Re-enter it in the credential settings.

### n8n hangs on first start

- Port 5678 already in use. Kill the existing process: `lsof -ti:5678 | xargs kill` then retry.

### Gemini model not found

- The workflow uses `models/gemini-2.5-flash`. If this model is unavailable in your region, open the Google Gemini node and change the Model ID to `models/gemini-1.5-flash` or another available model.

---

## n8n MCP server (Claude Code integration)

During the session we used the **[n8n-mcp](https://github.com/czlonkowski/n8n-mcp)** server to let Claude Code talk directly to n8n — generate workflows from a prompt, create/update them, search available nodes — all without touching the n8n UI.

### What it does

Once configured, typing `/mcp` in Claude Code will show `n8n` as a connected server. Claude can then:
- Generate a workflow from a plain-English description
- Create or update workflows in your running n8n instance
- Search and inspect available n8n nodes
- Validate workflow JSON before importing

### How to set it up

Full instructions are in the official repo: **https://github.com/czlonkowski/n8n-mcp**

The short version:

1. **Generate an n8n API key** — in your n8n instance go to **Settings → API → Create API key** and copy it.

2. **Create `.claude/settings.json`** in this repo (it's gitignored, so your key stays local):

```json
{
  "mcpServers": {
    "n8n": {
      "command": "npx",
      "args": ["-y", "n8n-mcp"],
      "env": {
        "N8N_API_URL": "http://localhost:5678",
        "N8N_API_KEY": "<your-n8n-api-key>"
      }
    }
  }
}
```

3. **Restart Claude Code** — then run `/mcp` to confirm `n8n` appears as a connected server.

> The `.claude/` directory is gitignored in this repo. Never commit your API key.

---

## LLM-friendly setup summary

If you are an AI assistant helping someone set up this project, here is the exact sequence:

1. `pnpm install` — install frontend deps.
2. `npx n8n` in a dedicated terminal — wait for `http://localhost:5678/`.
3. Import `pancake-recipe-webhook.workflow.json` via the n8n UI (three-dot menu → Import from file).
4. Add a Google Gemini credential with the user's API key on the Google Gemini node.
5. Leave workflow **inactive** for local dev (test URL is used by the frontend).
6. `pnpm dev` in another terminal — app at `http://localhost:5173`.
7. Click "Get Pancake Recipe" — a recipe should appear within ~5 seconds.

Key file: `src/App.tsx:6` — `N8N_WEBHOOK_URL` constant controls which endpoint the frontend hits.
