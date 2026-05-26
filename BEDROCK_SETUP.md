# AWS Bedrock Setup

Bedrock credentials are **not** configured in the app UI. They come from a `.env` file **bundled when you build/run**.

## 1. Create `.env` before run/build

```bash
cp .env.example .env
# Edit .env with your AWS keys and model
```

Required variables:

| Variable | Example |
|----------|---------|
| `AWS_REGION` | `us-east-1` |
| `BEDROCK_MODEL_ID` | `google.gemma-3-4b-it` |
| `AWS_ACCESS_KEY_ID` | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | `...` |

`.env` is listed in `pubspec.yaml` assets and **gitignored** — it is not pushed to GitHub.

## 2. Run or build

```bash
flutter pub get
flutter run -d macos
```

At startup the app loads `asset:.env` from the bundle. In debug, if the asset is missing, it may fall back to project-root `.env` when you run from the repo.

## 3. AWS console

- Enable your model in [Bedrock](https://console.aws.amazon.com/bedrock/) for the same region as `AWS_REGION`.
- IAM user needs `bedrock:InvokeModel`.

## 4. App Settings

**Settings** only configures the **Obsidian vault path** (use **Browse** on macOS).

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `Env: missing AWS keys` | Ensure `.env` exists before `flutter run` / `flutter build` |
| Asset error on build | `cp .env.example .env` and fill keys |
| 403 signature | Check secret key, model ID, region; rebuild after changing `.env` |
| 403 invalid token | Rotate IAM keys; update `.env`; rebuild |

After changing `.env`, run **`flutter run`** or **`flutter build`** again (hot reload does not reload assets).
