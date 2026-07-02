export const AUTHENTICATED_ROUTES = ["/welcome", "/reset-password"];

export const PUBLIC_AUTH_ROUTES = [
  "/login",
  "/register",
  "/forgot-password",
  "/auth",
];

export const SYSTEM_ROUTES = [
  ...PUBLIC_AUTH_ROUTES,
  ...AUTHENTICATED_ROUTES,
] as const;
