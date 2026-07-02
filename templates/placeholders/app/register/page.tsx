"use client";

/**
 * @customization-required
 * CUSTOMIZE: Replace layout/styling with your project design system.
 * See CUSTOMIZE.md in the project root.
 */
import { customizationRequired } from "@/shared/customization";
customizationRequired("app_register_page");

import { useMemo, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useTranslations } from "next-intl";
import { supabase } from "@/shared/utils/supabase/client";
import { useAuth } from "@/shared/context/AuthContext";
import {
  AuthButton,
  AuthCard,
  AuthDivider,
  AuthInput,
  AuthLink,
} from "@/shared/components/auth/AuthUI";
import PasswordValidationChecklist from "@/shared/components/auth/PasswordValidationChecklist";
import {
  createRegisterSchema,
  type RegisterFormData,
} from "@/shared/schemas/authSchemas";
import { notifyError, notifySuccess } from "@/shared/lib/toast";

export default function RegisterPage() {
  const t = useTranslations("auth.register");
  const tForm = useTranslations("form_error");
  const { signInWithGoogle } = useAuth();
  const [success, setSuccess] = useState(false);

  const registerSchema = useMemo(
    () => createRegisterSchema((key) => tForm(key)),
    [tForm]
  );

  const {
    register,
    handleSubmit,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<RegisterFormData>({
    resolver: zodResolver(registerSchema),
    defaultValues: { email: "", password: "", confirmPassword: "" },
  });

  const password = watch("password", "");

  const onSubmit = async (data: RegisterFormData) => {
    try {
      const { error } = await supabase.auth.signUp({
        email: data.email,
        password: data.password,
      });

      if (error) throw error;

      notifySuccess(t("success"));
      setSuccess(true);
    } catch (error) {
      const message = error instanceof Error ? error.message : t("error");
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
          {t("hasAccount")} <AuthLink href="/login">{t("signIn")}</AuthLink>
        </p>
      }
    >
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        <AuthInput
          label={t("email")}
          type="email"
          autoComplete="email"
          error={errors.email?.message}
          {...register("email")}
        />
        <AuthInput
          label={t("password")}
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
          {isSubmitting ? t("creating") : t("createAccount")}
        </AuthButton>

        <AuthDivider label={t("or")} />

        <AuthButton
          type="button"
          variant="secondary"
          disabled={isSubmitting}
          onClick={() =>
            signInWithGoogle({
              redirectTo: "/auth/callback?next=/welcome",
            })
          }
        >
          {t("registerWithGoogle")}
        </AuthButton>
      </form>
    </AuthCard>
  );
}
