import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function maskSecret(value: string, visibleChars = 4): string {
  if (!value || value.length <= visibleChars) return "****";
  return `${"*".repeat(value.length - visibleChars)}${value.slice(-visibleChars)}`;
}
