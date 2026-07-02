import { cookies } from "next/headers";
import { hasLocale } from "next-intl";
import { getRequestConfig } from "next-intl/server";

import { defaultLocale, supportedLocales } from "@/shared/constants/locales";

export default getRequestConfig(async () => {
  const cookieStore = await cookies();

  const cookieLocale = cookieStore.get("locale")?.value;

  const selectedLocale = hasLocale(supportedLocales, cookieLocale)
    ? cookieLocale
    : defaultLocale;

  return {
    locale: selectedLocale,
    messages: (await import(`../locales/${selectedLocale}.json`)).default,
  };
});
