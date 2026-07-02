import { z } from "zod";

/**
 * Single source of truth for password rules.
 * Both the Zod schema and the UI checklist are derived from this array,
 * so adding/removing a rule only needs to happen here.
 */
export interface PasswordRule {
  id: string;
  /** i18n key for the Zod validation error message. */
  messageKey: string;
  /** i18n key for the checklist label shown to the user. */
  labelKey: string;
  test: (value: string) => boolean;
}

export const passwordRules: PasswordRule[] = [
  {
    id: "min",
    messageKey: "password.min",
    labelKey: "password.checklistMin",
    test: (value) => value.length >= 8,
  },
  {
    id: "uppercase",
    messageKey: "password.uppercase",
    labelKey: "password.checklistUppercase",
    test: (value) => /[A-Z]/.test(value),
  },
  {
    id: "lowercase",
    messageKey: "password.lowercase",
    labelKey: "password.checklistLowercase",
    test: (value) => /[a-z]/.test(value),
  },
  {
    id: "number",
    messageKey: "password.number",
    labelKey: "password.checklistNumber",
    test: (value) => /\d/.test(value),
  },
  {
    id: "special",
    messageKey: "password.special",
    labelKey: "password.checklistSpecial",
    test: (value) => /[!@#$%^&*()\-_=\+\[\]{}|\\;:'",<.>\/?]/.test(value),
  },
];

export const createPasswordSchema = (t: (key: string) => string) =>
  z
    .string()
    .nonempty(t("password.required"))
    .superRefine((value, ctx) => {
      for (const rule of passwordRules) {
        if (!rule.test(value)) {
          ctx.addIssue({ code: "custom", message: t(rule.messageKey) });
        }
      }
    });

export const createPasswordPolicySchema = (t: (key: string) => string) =>
  z.object({
    password: createPasswordSchema(t),
  });
