/**
 * @customization-required
 * CUSTOMIZE: Replace layout/styling with your project design system.
 * See CUSTOMIZE.md in the project root.
 */
import { customizationRequired } from "@/shared/customization";
customizationRequired("app_expired-token_page");

import { AuthCard, AuthLink } from "@/shared/components/auth/AuthUI";
import { getTranslations } from "next-intl/server";

export default async function ExpiredTokenPage() {
  const t = await getTranslations("auth.expiredToken");

  return (
    <AuthCard title={t("title")} subtitle={t("subtitle")}>
      <div className="space-y-4 text-center">
        <AuthLink href="/forgot-password">{t("requestNew")}</AuthLink>
        <p className="text-sm text-zinc-500">
          <AuthLink href="/login">{t("backToLogin")}</AuthLink>
        </p>
      </div>
    </AuthCard>
  );
}
