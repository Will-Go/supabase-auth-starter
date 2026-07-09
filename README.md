# Supabase Auth PKCE Jump Starter

Reusable scaffold for **Next.js 16 + Supabase PKCE auth** with React Hook Form, Zod, React Query, axios, next-intl, sonner, and Tailwind.

**Requires [pnpm](https://pnpm.io/).** All installs and `create-next-app` use pnpm exclusively.

## Scaffold phases

The script runs in three phases to avoid collisions with `create-next-app`:

| Phase | What happens |
|-------|----------------|
| **1. Create / validate** | `create-next-app` or `--into` existing project — no file modifications |
| **2. Install** | `pnpm-workspace.yaml` + `pnpm install --ignore-scripts` + auth deps |
| **3. Apply scaffold** | Copy all templates, configure `next-intl`, write `.env` |

### next-intl configuration (Phase 3)

Always applied after install:

- `next.config.ts` → `createNextIntlPlugin()` wrapper
- `i18n/request.ts` → cookie-based locale + messages loader
- `i18n/routing.ts` → locale routing config
- `locales/<locale>.json` → UI copy

## Quick start

```bash
# macOS / Linux
./supabase-auth-starter/scripts/scaffold.sh my-app
./supabase-auth-starter/scripts/scaffold.sh --into ./my-existing-app
```

```powershell
# Windows (PowerShell)
.\supabase-auth-starter\scripts\scaffold.ps1 my-app
.\supabase-auth-starter\scripts\scaffold.ps1 -Into .\my-existing-app
```

```cmd
REM Windows (Command Prompt)
supabase-auth-starter\scripts\scaffold.cmd my-app
supabase-auth-starter\scripts\scaffold.cmd --into .\my-existing-app
```

## CLI options

| Flag              | Description                                           |
| ----------------- | ----------------------------------------------------- |
| `--into <path>`   | Scaffold into existing project (skip create-next-app) |
| `--default-locale <code>` | Default locale (default: `en`; available: `en`, `es`) |
| `--locale <code>`         | Alias for `--default-locale`                          |
| `--force`         | Overwrite existing files                              |
| `--dry-run`       | Print actions without executing                       |
| `--skip-install`  | Skip dependency installation (file copy only)         |

## What gets installed

| Package                                           | Purpose                               |
| ------------------------------------------------- | ------------------------------------- |
| `@supabase/ssr`                                   | Browser/server/proxy Supabase clients |
| `@supabase/supabase-js`                           | Auth API                              |
| `react-hook-form` + `@hookform/resolvers` + `zod` | Form validation                       |
| `@tanstack/react-query`                           | Data fetching                         |
| `axios`                                           | HTTP client                           |
| `next-intl`                                       | i18n (cookie-based locale)            |
| `sonner`                                          | Toast notifications                   |
| `clsx` + `tailwind-merge`                         | CSS utilities                         |

## Scaffolded structure

```
my-app/
├── proxy.ts                          # Session refresh + route guards
├── app/
│   ├── auth/callback/route.ts        # PKCE OAuth
│   ├── auth/confirm/route.ts         # Email OTP
│   ├── login/ register/ forgot-password/ reset-password/
│   ├── welcome/ error/ expired-token/ unauthorized/
│   └── layout.tsx                    # [CUSTOMIZE] providers wired
├── shared/
│   ├── context/AuthContext.tsx
│   ├── schemas/                      # authSchemas + passwordPolicy
│   ├── utils/supabase/               # client, server, proxy, admin
│   ├── hooks/                        # useAppQuery, useAppMutation
│   ├── lib/                          # axios, toast, utils
│   └── components/auth/              # [CUSTOMIZE] AuthUI placeholders
├── i18n/
├── locales/
├── templates/email/                  # [CUSTOMIZE] Supabase email templates
└── CUSTOMIZE.md                      # Generated customization checklist
```

## Auth architecture

| Route                | Handler                           | Flow                             |
| -------------------- | --------------------------------- | -------------------------------- |
| `GET /auth/callback` | `exchangeCodeForSession(code)`    | Google OAuth PKCE                |
| `GET /auth/confirm`  | `verifyOtp({ token_hash, type })` | Email confirm, password recovery |

**OAuth:** `signInWithOAuth` → Google → `/auth/callback?code=...` → session → redirect

**Email signup:** `signUp` → email link → `/auth/confirm?type=email` → session

**Password reset:** `resetPasswordForEmail` → email → `/auth/confirm?type=recovery&next=/reset-password` → `updateUser({ password })`

## Post-setup (Supabase Dashboard)

1. **Authentication → URL Configuration**
   - Site URL: `http://localhost:3000`
   - Redirect URLs: `http://localhost:3000/auth/callback`

2. **Authentication → Email Templates**
   - Copy content from `templates/email/EmailConfirmation.html` → Confirm signup
   - Copy content from `templates/email/ResetPassword.html` → Reset password

3. **Authentication → Providers**
   - Enable Google if using OAuth

4. **Environment** — fill in `.env` (created by scaffold):

   ```
   NEXT_PUBLIC_SUPABASE_URL=
   NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
   ```

## Customization

Files marked `@customization-required` need project-specific styling and copy.

```bash
grep -r "@customization-required" .
```

See [CUSTOMIZE.md](CUSTOMIZE.md) for the full list.

### Password policy

Rules are defined once in `shared/schemas/passwordPolicy.ts` (`passwordRules` array). Both Zod validation and `PasswordValidationChecklist` UI read from this array.

### Protected routes

Edit `shared/constants/systemRoutes.ts`:

```typescript
export const AUTHENTICATED_ROUTES = ["/welcome", "/reset-password"];
```

## Cursor skill

Install as a project skill by linking or copying `SKILL.md` to `.cursor/skills/supabase-auth-starter/SKILL.md`, or invoke directly when scaffolding.

## Template layout

```
supabase-auth-starter/
├── SKILL.md
├── README.md
├── CUSTOMIZE.md
├── scripts/
│   ├── scaffold.sh       # macOS / Linux
│   ├── scaffold.ps1      # Windows (PowerShell)
│   └── scaffold.cmd      # Windows (cmd launcher)
└── templates/
    ├── core/           # Copy as-is
    ├── placeholders/   # UI — always overwrites, needs customization
    ├── locales/        # en.json, es.json — copied per --default-locale
    ├── config/         # env template, next.config.ts
    └── manifests/      # customize.json
```

## Troubleshooting

| Issue                        | Fix                                                         |
| ---------------------------- | ----------------------------------------------------------- |
| Session not persisting       | Ensure `proxy.ts` exists at project root (Next.js 16 proxy) |
| Email link goes to wrong URL | Update Supabase Site URL + email templates                  |
| `next-intl` error            | Verify `next.config.ts` uses `createNextIntlPlugin()`       |
| Protected route not guarded  | Add path to `AUTHENTICATED_ROUTES` in `systemRoutes.ts`     |
