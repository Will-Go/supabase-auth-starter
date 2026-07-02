/**
 * @customization-required
 * CUSTOMIZE: Replace layout/styling with your project design system.
 * See CUSTOMIZE.md in the project root.
 */
import { customizationRequired } from "@/shared/customization";
customizationRequired("app_unauthorized_page");

import { AuthCard, AuthLink } from "@/shared/components/auth/AuthUI";
import { getTranslations } from "next-intl/server";

export default async function UnauthorizedPage() {
  const t = await getTranslations("auth.unauthorized");

  return (
    <AuthCard title={t("title")} subtitle={t("subtitle")}>
      <AuthLink href="/login">{t("backToLogin")}</AuthLink>
    </AuthCard>
  );
}
