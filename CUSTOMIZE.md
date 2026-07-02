# Files requiring customization

After scaffolding, update these files to match your project's design system, branding, and copy.

## UI components (placeholders)

| File | What to customize |
|------|-------------------|
| `shared/components/auth/AuthUI.tsx` | Card layout, inputs, buttons, links |
| `shared/components/auth/PasswordValidationChecklist.tsx` | Checklist styling |
| `app/layout.tsx` | Fonts, metadata, provider order |
| `app/page.tsx` | Home/landing page |
| `app/globals.css` | Theme tokens, colors, fonts |
| `app/login/*` | Login page layout and copy |
| `app/register/*` | Register page layout and copy |
| `app/forgot-password/page.tsx` | Forgot password UI |
| `app/reset-password/page.tsx` | Reset password UI |
| `app/welcome/page.tsx` | Post-login destination page |
| `app/error/page.tsx` | Error page |
| `app/expired-token/page.tsx` | Expired OTP link page |
| `app/unauthorized/page.tsx` | Unauthorized page |
| `locales/*.json` | All UI copy and form error messages |

## Email templates

| File | What to customize |
|------|-------------------|
| `templates/email/EmailConfirmation.html` | Branding, logo, colors — upload to Supabase Dashboard |
| `templates/email/ResetPassword.html` | Branding, logo, colors — upload to Supabase Dashboard |

## Core files to review (optional)

| File | What to review |
|------|----------------|
| `shared/constants/systemRoutes.ts` | Add your protected routes |
| `shared/context/AuthContext.tsx` | OAuth providers, redirect URLs, claims |

## Find customization markers

```bash
grep -r "@customization-required" .
grep -r "CUSTOMIZE:" .
```
