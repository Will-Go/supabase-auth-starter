"use client";

import {
  useMutation,
  type UseMutationOptions,
  type UseMutationResult,
} from "@tanstack/react-query";
import { notifySuccess } from "@/shared/lib/toast";
import {
  useErrorToastHandler,
  type AppRequestNotifyOptions,
} from "@/shared/hooks/types";

type UseAppMutationOptions<
  TData = unknown,
  TError = Error,
  TVariables = void,
  TContext = unknown,
> = UseMutationOptions<TData, TError, TVariables, TContext> &
  AppRequestNotifyOptions;

export function useAppMutation<
  TData = unknown,
  TError = Error,
  TVariables = void,
  TContext = unknown,
>(
  options: UseAppMutationOptions<TData, TError, TVariables, TContext>
): UseMutationResult<TData, TError, TVariables, TContext> {
  const {
    successMsg,
    errorMsg,
    translateKey,
    showTranslatedErrorToast,
    showErrorToast,
    onSuccess,
    onError,
    onSettled,
    ...mutationOptions
  } = options;

  const handleErrorToast = useErrorToastHandler({
    errorMsg,
    translateKey,
    showTranslatedErrorToast,
    showErrorToast,
  });

  // Wrap mutationFn to intercept offline mutations
  const originalMutationFn = mutationOptions.mutationFn;

  if (originalMutationFn) {
    mutationOptions.mutationFn = async (
      variables: TVariables,
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      context: any
    ): Promise<TData> => {
      return originalMutationFn(variables, context);
    };
  }

  return useMutation<TData, TError, TVariables, TContext>({
    ...mutationOptions,
    networkMode: "offlineFirst",

    onSuccess(...args) {
      if (successMsg) {
        const message =
          typeof successMsg === "function" ? successMsg(args[0]) : successMsg;
        notifySuccess(message);
      }
      onSuccess?.(...args);
    },

    onError(...args) {
      handleErrorToast(args[0]);
      onError?.(...args);
    },

    onSettled(...args) {
      onSettled?.(...args);
    },
  });
}
