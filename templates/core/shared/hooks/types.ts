"use client";

import { useTranslations } from "next-intl";
import { notifyError } from "@/shared/lib/toast";

export interface AppRequestNotifyOptions {
  /** Success toast message — static string or function receiving the result */
  successMsg?: string | ((data: unknown) => string);
  /** Custom error toast message — static string or function receiving the error */
  errorMsg?: string | ((error: unknown) => string);
  /** i18n namespace for useTranslations (default: "server.error") */
  translateKey?: string;
  /** Show translated error toast (default: true) */
  showTranslatedErrorToast?: boolean;
  /** Show custom errorMsg toast (default: true) */
  showErrorToast?: boolean;
}

/**
 * Internal hook that returns an error handler matching the
 * toast + i18n translation logic from useRequestActions (lines 77-94).
 */
export function useErrorToastHandler(options: AppRequestNotifyOptions) {
  const {
    translateKey = "server.error",
    showTranslatedErrorToast = true,
    showErrorToast = true,
    errorMsg,
  } = options;

  const t = useTranslations(translateKey);

  return (error: Error | unknown) => {
    if (showTranslatedErrorToast) {
      if (translateKey) {
        const errorKey = (error as string) || "unexpected_error";
        let translatedError = t.has(errorKey)
          ? t(errorKey)
          : t("unexpected_error");

        const securityMatch =
          typeof errorKey === "string"
            ? errorKey.match(
                /For security purposes, you can only request this after (\d+) seconds/
              )
            : null;

        if (securityMatch && t.has("security_wait_seconds")) {
          translatedError = t("security_wait_seconds", {
            seconds: securityMatch[1],
          });
        }

        notifyError(translatedError);
      } else {
        notifyError(error as string);
      }
    }

    if (errorMsg && showErrorToast) {
      const message =
        typeof errorMsg === "function" ? errorMsg(error) : errorMsg;
      notifyError(message);
    }
  };
}
