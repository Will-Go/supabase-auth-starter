import { type NextRequest } from "next/server";
import { updateSession } from "@/shared/utils/supabase/proxy";
import createMiddleware from "next-intl/middleware";
import { type Locale, routing } from "@/i18n/routing";
import { defaultLocale, supportedLocales } from "@/shared/constants/locales";
import { SYSTEM_ROUTES } from "@/shared/constants/systemRoutes";

const intlMiddleware = createMiddleware(routing);

export default async function proxy(request: NextRequest) {
  const response = await updateSession(request);

  const intlResponse = intlMiddleware(request);
  intlResponse.cookies.getAll().forEach(({ name, value }) => {
    response.cookies.set(name, value);
  });

  const { pathname } = request.nextUrl;

  if (SYSTEM_ROUTES.some((route) => pathname.startsWith(route))) {
    let locale = response.cookies.get("locale")?.value as Locale;

    if (!locale || !supportedLocales.includes(locale)) {
      locale = defaultLocale;
    }
    response.cookies.set("locale", locale);
  }

  return response;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|auth/callback|auth/confirm|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
