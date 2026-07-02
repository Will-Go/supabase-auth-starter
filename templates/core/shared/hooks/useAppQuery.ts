"use client";

import { useCallback, useEffect, useRef } from "react";
import {
  useQuery,
  useQueryClient,
  type UseQueryOptions,
  type UseQueryResult,
} from "@tanstack/react-query";
import { notifySuccess } from "@/shared/lib/toast";
import {
  useErrorToastHandler,
  type AppRequestNotifyOptions,
} from "@/shared/hooks/types";

type UseAppQueryOptions<
  TQueryFnData = unknown,
  TError = Error,
  TData = TQueryFnData,
> = UseQueryOptions<TQueryFnData, TError, TData> &
  AppRequestNotifyOptions & {
    /** Callback fired once when data is successfully fetched */
    onSuccess?: (data: TData) => void;
    /** Callback fired once when the query errors */
    onError?: (error: TError) => void;
  };

export function useAppQuery<
  TQueryFnData = unknown,
  TError = Error,
  TData = TQueryFnData,
>(
  options: UseAppQueryOptions<TQueryFnData, TError, TData>
): UseQueryResult<TData, TError> & {
  invalidate: () => Promise<void>;
  reset: () => Promise<void>;
} {
  const {
    successMsg,
    errorMsg,
    translateKey,
    showTranslatedErrorToast,
    showErrorToast,
    onSuccess,
    onError,
    ...queryOptions
  } = options;

  const handleErrorToast = useErrorToastHandler({
    errorMsg,
    translateKey,
    showTranslatedErrorToast,
    showErrorToast,
  });

  const queryClient = useQueryClient();
  const query = useQuery<TQueryFnData, TError, TData>(queryOptions);

  const invalidate = useCallback(
    () => queryClient.invalidateQueries({ queryKey: queryOptions.queryKey }),
    [queryClient, queryOptions.queryKey]
  );

  const reset = useCallback(
    () => queryClient.resetQueries({ queryKey: queryOptions.queryKey }),
    [queryClient, queryOptions.queryKey]
  );

  // Ref-based de-duplication so toasts fire once per data/error cycle
  const successFiredRef = useRef(false);
  const errorFiredRef = useRef(false);
  const prevDataRef = useRef<TData | undefined>(undefined);
  const prevErrorRef = useRef<TError | null>(null);

  useEffect(() => {
    if (query.data !== prevDataRef.current) {
      successFiredRef.current = false;
      prevDataRef.current = query.data;
    }
  }, [query.data]);

  useEffect(() => {
    if (query.error !== prevErrorRef.current) {
      errorFiredRef.current = false;
      prevErrorRef.current = query.error;
    }
  }, [query.error]);

  // Fire success toast + callback
  useEffect(() => {
    if (
      query.isSuccess &&
      query.data !== undefined &&
      !successFiredRef.current
    ) {
      successFiredRef.current = true;

      if (successMsg) {
        const message =
          typeof successMsg === "function"
            ? successMsg(query.data)
            : successMsg;
        notifySuccess(message);
      }

      onSuccess?.(query.data);
    }
  }, [query.isSuccess, query.data, successMsg, onSuccess]);

  // Fire error toast + callback
  useEffect(() => {
    if (query.isError && query.error && !errorFiredRef.current) {
      errorFiredRef.current = true;
      handleErrorToast(query.error);
      onError?.(query.error);
    }
  }, [query.isError, query.error, handleErrorToast, onError]);

  return { ...query, invalidate, reset };
}
