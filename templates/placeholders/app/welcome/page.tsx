"use client";

/**
 * @customization-required
 * CUSTOMIZE: Replace layout/styling with your project design system.
 * See CUSTOMIZE.md in the project root.
 */
import { customizationRequired } from "@/shared/customization";
customizationRequired("app_welcome_page");

import { useTranslations } from "next-intl";
import { useAuth } from "@/shared/context/AuthContext";
import { AuthButton, AuthCard, AuthLink } from "@/shared/components/auth/AuthUI";

export default function WelcomePage() {
  const t = useTranslations("auth.welcome");
  const { user, loading, signOut } = useAuth();

  if (loading) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <p className="text-zinc-500">{t("loading")}</p>
      </main>
    );
  }

  return (
    <AuthCard title={t("title")} subtitle={t("subtitle")}>
      <div className="space-y-4">
        <div className="rounded-lg bg-zinc-50 p-4 text-sm">
          <p className="text-zinc-500">{t("email")}</p>
          <p className="font-medium text-zinc-900">{user?.email}</p>
        </div>
        <AuthButton type="button" onClick={() => signOut()}>
          {t("signOut")}
        </AuthButton>
        <p className="text-center text-sm text-zinc-500">
          <AuthLink href="/">{t("backHome")}</AuthLink>
        </p>
      </div>
    </AuthCard>
  );
}
