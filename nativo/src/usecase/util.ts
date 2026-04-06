export function pluralize(word: string, count: number): string {
  return count === 1 ? word : word + "s";
}

export function add(a: number, b: number): number {
  return a + b;
}