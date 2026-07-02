/**
 * @customization-required
 * CUSTOMIZE: Replace layout/styling with your project design system.
 * See CUSTOMIZE.md in the project root.
 */
import { customizationRequired } from "@/shared/customization";
customizationRequired("app_layout");

import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { Toaster } from "sonner";
import "./globals.css";
import ReactQueryWrapper from "@/shared/wrapper/ReactQueryWrapper";
import AuthProvider from "@/shared/context/AuthContext";
import { NextIntlClientProvider } from "next-intl";
import { getLocale, getMessages } from "next-intl/server";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Test App",
  description: "Supabase auth integration",
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const messages = await getMessages();
  const locale = await getLocale();

  return (
    <html
      lang={locale}
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="flex min-h-full flex-col">
        <ReactQueryWrapper>
          <NextIntlClientProvider messages={messages}>
            <AuthProvider>
              {children}
              <Toaster richColors position="top-right" />
            </AuthProvider>
          </NextIntlClientProvider>
        </ReactQueryWrapper>
      </body>
    </html>
  );
}
