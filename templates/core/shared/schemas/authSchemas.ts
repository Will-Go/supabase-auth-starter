import { z } from "zod";
import { createPasswordPolicySchema } from "@/shared/schemas/passwordPolicy";

export const loginSchema = z.object({
  email: z.string().email("Correo electrónico inválido"),
  password: z.string().min(6, "La contraseña debe tener al menos 6 caracteres"),
});

export const createRegisterSchema = (t: (key: string) => string) =>
  z
    .object({
      email: z.string().email(t("auth.email_invalid")),
      password: createPasswordPolicySchema(t).shape.password,
      confirmPassword: z.string().min(1, t("password.confirm_required")),
    })
    .refine((data) => data.password === data.confirmPassword, {
      message: t("password.mismatch"),
      path: ["confirmPassword"],
    });

export const forgotPasswordSchema = z.object({
  email: z.string().email("Correo electrónico inválido"),
});

export const createResetPasswordSchema = (t: (key: string) => string) =>
  z
    .object({
      password: createPasswordPolicySchema(t).shape.password,
      confirmPassword: z.string().min(1, t("password.confirm_required")),
    })
    .refine((data) => data.password === data.confirmPassword, {
      message: t("password.mismatch"),
      path: ["confirmPassword"],
    });

export type LoginFormData = z.infer<typeof loginSchema>;
export type RegisterFormData = z.input<ReturnType<typeof createRegisterSchema>>;
export type ForgotPasswordFormData = z.infer<typeof forgotPasswordSchema>;
export type ResetPasswordFormData = z.infer<
  ReturnType<typeof createResetPasswordSchema>
>;
