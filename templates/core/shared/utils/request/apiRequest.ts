"use client";
//THIS FUNCTION IS USED FOR AUTHENTICATED USERS
import { AxiosProgressEvent } from "axios";
import axiosInstance from "@/shared/lib/axiosService";

type HttpMethod = "get" | "post" | "put" | "delete" | "patch";

export interface ApiRequestConfig<T = unknown> {
  method: HttpMethod;
  url: string;
  data?: T;
  params?: Record<string, string | number | boolean | undefined>;
  customHeaders?: Record<string, string>;
  withCredentials?: boolean;
  onUploadProgress?: (progressEvent: AxiosProgressEvent) => void;
  responseType?:
    "arraybuffer" | "document" | "json" | "text" | "stream" | "blob";
}

export async function apiRequest<T>({
  method,
  url,
  data,
  params,
  customHeaders,
  withCredentials = false,
  onUploadProgress,
}: ApiRequestConfig): Promise<T> {
  // Make the request
  try {
    const response = await axiosInstance({
      method,
      url,
      data,
      params, // Pass params to the request
      headers: {
        ...customHeaders,
      },
      onUploadProgress,
      withCredentials,
    });
    return response.data;
  } catch (error) {
    if (typeof error === "string") {
      throw new Error(error || "unexpected_error").message;
    }

    throw new Error("unexpected_error").message;
  }
}
