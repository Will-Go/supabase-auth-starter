/**
 * @customization-required
 * CUSTOMIZE: Replace layout/styling with your project design system.
 * See CUSTOMIZE.md in the project root.
 */
import { customizationRequired } from "@/shared/customization";
customizationRequired("app_page");

import Link from "next/link";
import { createClient } from "@/shared/utils/supabase/server";
import { getTranslations } from "next-intl/server";

export default async function Page() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const t = await getTranslations("home");

  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col justify-center gap-8 px-6 py-16">
      <div>
        <h1 className="text-3xl font-semibold tracking-tight text-zinc-900">
          {t("title")}
        </h1>
        <p className="mt-2 text-zinc-600">{t("subtitle")}</p>
      </div>

      {user ? (
        <div className="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
          <p className="text-sm text-zinc-500">{t("signedInAs")}</p>
          <p className="mt-1 font-medium text-zinc-900">{user.email}</p>
          <Link
            href="/welcome"
            className="mt-4 inline-block rounded-lg bg-zinc-900 px-4 py-2 text-sm font-medium text-white"
          >
            {t("goToWelcome")}
          </Link>
        </div>
      ) : (
        <div className="flex flex-wrap gap-3">
          <Link
            href="/login"
            className="rounded-lg bg-zinc-900 px-4 py-2 text-sm font-medium text-white"
          >
            {t("login")}
          </Link>
          <Link
            href="/register"
            className="rounded-lg border border-zinc-300 px-4 py-2 text-sm font-medium text-zinc-900"
          >
            {t("register")}
          </Link>
        </div>
      )}
    </main>
  );
}
