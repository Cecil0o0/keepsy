// helpers.ts - no dependencies

export function padZero(n: number): string {
    return n < 10 ? `0${n}` : `${n}`;
}

export function capitalize(str: string): string {
    return str.charAt(0).toUpperCase() + str.slice(1);
}
