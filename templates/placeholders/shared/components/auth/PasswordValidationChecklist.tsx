"use client";

/**
 * @customization-required
 * CUSTOMIZE: Replace layout/styling with your project design system.
 * See CUSTOMIZE.md in the project root.
 */
import { customizationRequired } from "@/shared/customization";
customizationRequired("shared_components_auth_PasswordValidationChecklist");

import { useTranslations } from "next-intl";
import { passwordRules } from "@/shared/schemas/passwordPolicy";

interface PasswordValidationChecklistProps {
  password: string;
}

export default function PasswordValidationChecklist({
  password,
}: PasswordValidationChecklistProps) {
  const t = useTranslations("form_error");

  return (
    <div className="rounded-lg border border-zinc-200 bg-zinc-50 p-3">
      <p className="mb-2 text-xs font-medium text-zinc-700">
        {t("password.checklistTitle")}
      </p>
      <ul className="space-y-1">
        {passwordRules.map((rule) => {
          const isValid = rule.test(password);
          return (
            <li key={rule.id} className="flex items-center gap-2 text-xs">
              <span
                className={isValid ? "text-green-600" : "text-zinc-400"}
                aria-hidden
              >
                {isValid ? "✓" : "○"}
              </span>
              <span
                className={
                  isValid ? "text-green-700 line-through" : "text-zinc-500"
                }
              >
                {t(rule.labelKey)}
              </span>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
