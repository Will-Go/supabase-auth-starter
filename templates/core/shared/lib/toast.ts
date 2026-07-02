import { toast } from "sonner";

export const notifySuccess = (message: string) => {
  toast.success(message);
};

export const notifyInfo = (
  message: string,
  options?: {
    actionLabel?: string;
    onAction?: () => void;
  }
) => {
  toast.info(message, {
    action:
      options?.actionLabel && options.onAction
        ? {
            label: options.actionLabel,
            onClick: () => options.onAction?.(),
          }
        : undefined,
  });
};

export const notifyError = (message: string) => {
  toast.error(message);
};

export const notifyInformation = (message: string) => {
  toast.info(message);
};

export const notifyWarning = (message: string) => {
  toast.warning(message);
};
