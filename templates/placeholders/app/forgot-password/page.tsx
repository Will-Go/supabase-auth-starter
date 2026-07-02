"use client";

/**
 * @customization-required
 * CUSTOMIZE: Replace layout/styling with your project design system.
 * See CUSTOMIZE.md in the project root.
 */
import { customizationRequired } from "@/shared/customization";
customizationRequired("app_forgot-password_page");

import { Suspense, useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useSearchParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { supabase } from "@/shared/utils/supabase/client";
import {
  AuthButton,
  AuthCard,
  AuthInput,
  AuthLink,
} from "@/shared/components/auth/AuthUI";
import {
  forgotPasswordSchema,
  type ForgotPasswordFormData,
} from "@/shared/schemas/authSchemas";
import { notifyError, notifySuccess } from "@/shared/lib/toast";

function ForgotPasswordForm() {
  const t = useTranslations("auth.forgotPassword");
  const searchParams = useSearchParams();
  const [emailSent, setEmailSent] = useState(false);

  const {
    register,
    handleSubmit,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<ForgotPasswordFormData>({
    resolver: zodResolver(forgotPasswordSchema),
    defaultValues: { email: "" },
  });

  useEffect(() => {
    const emailParam = searchParams.get("email");
    if (emailParam) {
      setValue("email", emailParam);
    }
  }, [searchParams, setValue]);

  const onSubmit = async (data: ForgotPasswordFormData) => {
    try {
      const { error } = await supabase.auth.resetPasswordForEmail(data.email, {
        redirectTo: `${window.location.origin}/reset-password`,
      });

      if (error) throw error;

      notifySuccess(t("success"));
      setEmailSent(true);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : t("error");
      notifyError(message);
    }
  };

  if (emailSent) {
    return (
      <AuthCard
        title={t("successTitle")}
        subtitle={t("successSubtitle")}
        footer={
          <p className="text-zinc-500">
            <AuthLink href="/login">{t("backToLogin")}</AuthLink>
          </p>
        }
      >
        <p className="rounded-lg bg-blue-50 p-4 text-sm text-blue-800">
          {t("successMessage")}
        </p>
        <div className="mt-4">
        <AuthButton
          type="button"
          variant="secondary"
          onClick={() => setEmailSent(false)}
        >
          {t("sendAgain")}
        </AuthButton>
        </div>
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
          label={t("email")}
          type="email"
          autoComplete="email"
          error={errors.email?.message}
          {...register("email")}
        />
        <AuthButton type="submit" disabled={isSubmitting}>
          {isSubmitting ? t("sending") : t("sendLink")}
        </AuthButton>
      </form>
    </AuthCard>
  );
}

export default function ForgotPasswordPage() {
  return (
    <Suspense
      fallback={
        <main className="flex min-h-screen items-center justify-center">
          <p className="text-zinc-500">...</p>
        </main>
      }
    >
      <ForgotPasswordForm />
    </Suspense>
  );
}
