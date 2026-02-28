// utils.ts -> helpers.ts, constants.ts

import { DEFAULT_LOCALE } from "./constants.ts";
import { padZero } from "./helpers.ts";

export function formatDate(date: Date): string {
    const year = date.getFullYear();
    const month = padZero(date.getMonth() + 1);
    const day = padZero(date.getDate());
    return `${year}-${month}-${day}`;
}

export function formatNumber(num: number): string {
    return num.toLocaleString(DEFAULT_LOCALE);
}
