"use client";

/**
 * @customization-required
 * CUSTOMIZE: Replace layout/styling with your project design system.
 * See CUSTOMIZE.md in the project root.
 */
import { customizationRequired } from "@/shared/customization";
customizationRequired("app_reset-password_page");

import { useMemo, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useTranslations } from "next-intl";
import { supabase } from "@/shared/utils/supabase/client";
import {
  AuthButton,
  AuthCard,
  AuthInput,
  AuthLink,
} from "@/shared/components/auth/AuthUI";
import PasswordValidationChecklist from "@/shared/components/auth/PasswordValidationChecklist";
import {
  createResetPasswordSchema,
  type ResetPasswordFormData,
} from "@/shared/schemas/authSchemas";
import { notifyError, notifySuccess } from "@/shared/lib/toast";

export default function ResetPasswordPage() {
  const t = useTranslations("auth.resetPassword");
  const tForm = useTranslations("form_error");
  const [success, setSuccess] = useState(false);

  const resetPasswordSchema = useMemo(
    () => createResetPasswordSchema((key) => tForm(key)),
    [tForm]
  );

  const {
    register,
    handleSubmit,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<ResetPasswordFormData>({
    resolver: zodResolver(resetPasswordSchema),
    defaultValues: { password: "", confirmPassword: "" },
  });

  const password = watch("password", "");

  const onSubmit = async (data: ResetPasswordFormData) => {
    try {
      const { error } = await supabase.auth.updateUser({
        password: data.password,
      });

      if (error) throw error;

      notifySuccess(t("success"));
      setSuccess(true);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : t("error");
      notifyError(message);
    }
  };

  if (success) {
    return (
      <AuthCard
        title={t("successTitle")}
        subtitle={t("successSubtitle")}
        footer={<AuthLink href="/login">{t("goToLogin")}</AuthLink>}
      >
        <p className="rounded-lg bg-green-50 p-4 text-sm text-green-800">
          {t("successMessage")}
        </p>
      </AuthCard>
    );
  }

  return (
    <AuthCard
      title={t("title")}
      subtitle={t("subtitle")}
      footer={
        <p className="text-zinc-500">
          <AuthLink href="/login">{t("backToLogin")}</AuthLink>
        </p>
      }
    >
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        <AuthInput
          label={t("newPassword")}
          type="password"
          autoComplete="new-password"
          error={errors.password?.message}
          {...register("password")}
        />
        <PasswordValidationChecklist password={password} />
        <AuthInput
          label={t("confirmPassword")}
          type="password"
          autoComplete="new-password"
          error={errors.confirmPassword?.message}
          {...register("confirmPassword")}
        />
        <AuthButton type="submit" disabled={isSubmitting}>
          {isSubmitting ? t("updating") : t("updatePassword")}
        </AuthButton>
      </form>
    </AuthCard>
  );
}
