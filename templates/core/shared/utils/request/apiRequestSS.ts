//Server imports
import { cookies } from "next/headers";
import { ApiRequestConfig } from "./apiRequest";

const apiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL || "/api";

//This is a server-side version of the apiRequest function
export async function apiRequestSS<T>({
  method,
  url,
  data,
  params,
  customHeaders,
  responseType,
}: ApiRequestConfig): Promise<T> {
  const base =
    apiBaseUrl.startsWith("http://") || apiBaseUrl.startsWith("https://")
      ? apiBaseUrl
      : process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3000";

  try {
    const cookieStore = await cookies();
    const cookieString = cookieStore.toString();

    // Build URL with params if providedS
    const urlWithParams = new URL(`${apiBaseUrl}${url}`, base);
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined) {
          urlWithParams.searchParams.set(key, String(value));
        }
      });
    }

    // Build request configuration
    const requestConfig: RequestInit = {
      method: method.toUpperCase(),
      cache: "no-store",
      headers: {
        "Content-Type": "application/json",
        cookie: cookieString,
        ...customHeaders,
      },
    };

    // Add body for POST, PUT, PATCH requests
    if (data && ["post", "put", "patch"].includes(method.toLowerCase())) {
      requestConfig.body = JSON.stringify(data);
    }

    const response = await fetch(urlWithParams.toString(), requestConfig);

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    // Handle different response types
    if (responseType === "text") {
      return (await response.text()) as T;
    } else if (responseType === "blob") {
      return (await response.blob()) as T;
    } else if (responseType === "arraybuffer") {
      return (await response.arrayBuffer()) as T;
    } else {
      return await response?.json();
    }
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(error.message || "unexpected_error");
    }
    throw new Error("unexpected_error");
  }
}
