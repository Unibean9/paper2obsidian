# AWS Bedrock Setup

Paper2Obsidian uses **Amazon Bedrock Converse API** for:

- Step 4: metadata extraction (dataset, keywords, summary, …)
- AI chat with paper context (RAG-style)

Grobid and OpenAlex are unchanged (local Docker + public API).

## 1. AWS prerequisites

1. Enable your model in the [Bedrock console](https://console.aws.amazon.com/bedrock/) (e.g. **Claude 3.5 Sonnet**).
2. Create IAM user or role with permission, for example:

```json
{
  "Effect": "Allow",
  "Action": ["bedrock:InvokeModel"],
  "Resource": "arn:aws:bedrock:*::foundation-model/*"
}
```

3. Note **region** (e.g. `us-east-1`) and **model ID** (e.g. `anthropic.claude-3-5-sonnet-20240620-v2:0`).

## 2. Configure credentials via `.env` (recommended)

```bash
cp .env.example .env
# Edit .env and paste your keys (file is gitignored)
```

Variables:

| Variable | Example |
|----------|---------|
| `AWS_REGION` | `us-east-1` |
| `BEDROCK_MODEL_ID` | `anthropic.claude-3-5-sonnet-20240620-v2:0` |
| `AWS_ACCESS_KEY_ID` | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | `...` |

Run the app from the project root so `.env` is found:

```bash
flutter run -d macos
```

## 3. Or configure in the app UI

Open **Settings** (gear icon) and fill:

| Field | Example |
|-------|---------|
| AWS Region | `us-east-1` |
| Model ID | `anthropic.claude-3-5-sonnet-20240620-v2:0` |
| Access Key ID | `AKIA...` |
| Secret Access Key | `...` |

Credentials are stored locally in `SharedPreferences` on your machine.

## 4. Optional: build-time defines

```bash
flutter run -d macos \
  --dart-define=AWS_REGION=us-east-1 \
  --dart-define=BEDROCK_MODEL_ID=anthropic.claude-3-5-sonnet-20240620-v2:0 \
  --dart-define=AWS_ACCESS_KEY_ID=YOUR_KEY \
  --dart-define=AWS_SECRET_ACCESS_KEY=YOUR_SECRET
```

App settings override empty define values after first save.

## 5. Run stack

```bash
docker compose up -d grobid
flutter pub get
flutter run -d macos
```

You no longer need Ollama for summary or chat.

## Troubleshooting

| Error | Fix |
|-------|-----|
| `Bedrock is not configured` | Add keys in Settings or `--dart-define` |
| `403` / signature mismatch | Check region matches model availability; verify secret key |
| `AccessDeniedException` | Enable model in Bedrock console; fix IAM policy |
| Timeout | Use a smaller/faster model (e.g. Claude 3 Haiku) |
