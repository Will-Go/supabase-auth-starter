"use client";

/**
 * @customization-required
 * CUSTOMIZE: Replace layout/styling with your project design system.
 * See CUSTOMIZE.md in the project root.
 */
import { customizationRequired } from "@/shared/customization";
customizationRequired("app_login_page");

import { Suspense, useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useRouter, useSearchParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { useAuth } from "@/shared/context/AuthContext";
import {
  AuthButton,
  AuthCard,
  AuthDivider,
  AuthInput,
  AuthLink,
} from "@/shared/components/auth/AuthUI";
import { loginSchema, type LoginFormData } from "@/shared/schemas/authSchemas";
import { notifyError, notifySuccess } from "@/shared/lib/toast";

const REMEMBER_KEY = "test1_remembered_email";

function LoginForm() {
  const t = useTranslations("auth.login");
  const { signInWithEmailAndPass, signInWithGoogle } = useAuth();
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirectUrl = searchParams.get("redirect");
  const [rememberMe, setRememberMe] = useState(false);

  const {
    register,
    handleSubmit,
    setValue,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: "", password: "" },
  });

  const email = watch("email");

  useEffect(() => {
    const stored = localStorage.getItem(REMEMBER_KEY);
    if (stored) {
      setValue("email", stored);
      setRememberMe(true);
    }
  }, [setValue]);

  const onSubmit = async (data: LoginFormData) => {
    try {
      if (rememberMe) {
        localStorage.setItem(REMEMBER_KEY, data.email);
      } else {
        localStorage.removeItem(REMEMBER_KEY);
      }

      await signInWithEmailAndPass(data.email, data.password);
      notifySuccess(t("success"));
      router.replace(redirectUrl || "/welcome");
    } catch (error) {
      const message =
        error instanceof Error ? error.message : t("error");
      notifyError(message);
    }
  };

  return (
    <AuthCard
      title={t("title")}
      subtitle={t("subtitle")}
      footer={
        <p className="text-zinc-500">
          {t("noAccount")}{" "}
          <AuthLink href="/register">{t("signUp")}</AuthLink>
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
          autoComplete="current-password"
          error={errors.password?.message}
          {...register("password")}
        />

        <div className="flex items-center justify-between text-sm">
          <label className="flex items-center gap-2 text-zinc-600">
            <input
              type="checkbox"
              checked={rememberMe}
              onChange={(e) => setRememberMe(e.target.checked)}
              className="rounded border-zinc-300"
            />
            {t("rememberMe")}
          </label>
          <AuthLink
            href={`/forgot-password?email=${encodeURIComponent(email || "")}`}
          >
            {t("forgotPassword")}
          </AuthLink>
        </div>

        <AuthButton type="submit" disabled={isSubmitting}>
          {isSubmitting ? t("signingIn") : t("signIn")}
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
          {t("signInWithGoogle")}
        </AuthButton>
      </form>
    </AuthCard>
  );
}

export default function LoginPage() {
  return (
    <Suspense
      fallback={
        <main className="flex min-h-screen items-center justify-center">
          <p className="text-zinc-500">...</p>
        </main>
      }
    >
      <LoginForm />
    </Suspense>
  );
}
