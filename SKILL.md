---
name: supabase-auth-starter
description: Bootstrap Next.js 16 + Supabase PKCE auth (OAuth callback, email confirm, middleware session, RHF, Zod, React Query, axios, next-intl, sonner, Tailwind). Use when starting a new auth project, scaffolding Supabase PKCE into an existing Next.js app, or when the user mentions supabase auth starter, PKCE scaffold, or bootstrap auth.
---

# Supabase Auth PKCE Jump Starter

Scaffold a complete Supabase PKCE auth stack into a Next.js 16 project. Reference implementation: `test-1/` in this repo.

## When to use

- User wants a new Next.js project with Supabase auth pre-wired
- User wants to add PKCE auth to an existing Next.js 16 App Router project
- User mentions: "supabase auth starter", "PKCE scaffold", "bootstrap auth"

## Quick start

```bash
# New project
./supabase-auth-starter/scripts/scaffold.sh my-app

# Existing project
./supabase-auth-starter/scripts/scaffold.sh --into ./existing-app

# Options
./supabase-auth-starter/scripts/scaffold.sh --into ./app --default-locale es --force
./supabase-auth-starter/scripts/scaffold.sh my-app --dry-run
```

Run from the repository root (parent of `supabase-auth-starter/`).

## What gets scaffolded

### Core (production-ready)

- `proxy.ts` — Next.js 16 session refresh + i18n cookie
- `shared/utils/supabase/*` — browser, server, proxy, admin clients
- `shared/context/AuthContext.tsx` — AuthProvider + useAuth
- `shared/schemas/*` — Zod auth schemas + password policy SSOT
- `app/auth/callback` — PKCE `exchangeCodeForSession`
- `app/auth/confirm` — OTP `verifyOtp` (email, recovery)
- `i18n/*` — next-intl cookie-based locale
- Hooks, axios, React Query wrapper, request utils

### Placeholders (require customization)

Marked with `@customization-required`. See `CUSTOMIZE.md` in the target project.

- Auth UI components (`AuthUI`, `PasswordValidationChecklist`)
- Auth pages: login, register, forgot/reset password, welcome, error pages
- `app/layout.tsx`, `app/page.tsx`, `app/globals.css`
- `locales/*.json`, `templates/email/*.html`

## Auth flows

```mermaid
flowchart TD
    subgraph oauth [Google OAuth PKCE]
        A[signInWithOAuth] --> B[Google]
        B --> C["/auth/callback?code=..."]
        C --> D[exchangeCodeForSession]
        D --> E[/welcome]
    end

    subgraph email [Email signup]
        F[signUp] --> G[Supabase email]
        G --> H["/auth/confirm?type=email"]
        H --> I[verifyOtp]
        I --> E
    end

    subgraph recovery [Password reset]
        J[resetPasswordForEmail] --> K[Reset email]
        K --> L["/auth/confirm?type=recovery"]
        L --> M[/reset-password]
        M --> N[updateUser password]
    end
```

## Post-scaffold checklist

1. Fill `.env` with `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
2. Supabase Dashboard → URL config: Site URL + `/auth/callback` redirect
3. Upload `templates/email/*.html` to Supabase Auth email templates
4. Customize `@customization-required` files — `grep -r "@customization-required" .`
5. Update `shared/constants/systemRoutes.ts` protected routes
6. Enable Google OAuth in Supabase if using `signInWithGoogle`
7. `pnpm dev` — test register → confirm → login → forgot → reset

## Dependencies installed

`@supabase/ssr`, `@supabase/supabase-js`, `@tanstack/react-query`, `axios`, `next-intl`, `react-hook-form`, `@hookform/resolvers`, `zod`, `sonner`, `clsx`, `tailwind-merge`

## Additional resources

- Full docs: [README.md](README.md)
- Customization manifest: [CUSTOMIZE.md](CUSTOMIZE.md)
- File inventory and flags: [README.md](README.md)
