export const meta = {
    name: 'meta',
    description: 'meta description',
    usage: 'meta usage',
    options: {
        '-h, --help': 'output usage information',
        '-v, --version': 'output the version number'
    }
};

export const count_meta: number = 1044412323 as number;
export const tool_name: string = 'nativo' as string;
export const bin_num: number = 0b10101010101010100 as number;
export const oct_num: number = 0o1777770 as number;
export const hex_num: number = 0x1FFFFFFF0 as number;
export const regex: RegExp = /abc/igm;
export const bool_literal: boolean = true;
export const bool_literal2: boolean = false;
export const null_literal: null = null;
export const undefined_literal: undefined = undefined;
export const bigInt_literal: bigint = 12345678901234567890n;
export const template_literal: string = `Hello, ${tool_name}!`;
export const array_literal: number[] = [1, 2, 3, 4, 5];
export const object_literal: { name: string; value: number } = { name: 'example', value: 42 };
export const symbol_literal: symbol = Symbol('unique-id');

export const lexDecl1: number = 42;
export const lexDecl2: string = "hello";
export const lexDecl3: boolean = true;
export const lexDecl4: null = null;
export const lexDecl5: undefined = undefined;
export const lexDecl6: bigint = 123n;
export const lexDecl7: symbol = Symbol("id");
export const lexDecl8: RegExp = /test/g;
export const lexDecl9: number[] = [1, 2, 3];
export const lexDecl10: { key: string } = { key: "value" };
export const lexDecl11: number = 3.14159;
export const lexDecl12: string = `template`;
export const lexDecl13: boolean = false;
export const lexDecl14: object = Object.create(null);
export const lexDecl15: Function = () => {};
export const lexDecl16: Date = new Date();
export const lexDecl17: Error = new Error("msg");
export const lexDecl18: Map<string, number> = new Map();
export const lexDecl19: Set<number> = new Set();
export const lexDecl20: ArrayBuffer = new ArrayBuffer(8);

export let config: { apiUrl: string; timeout: number } = {
  apiUrl: 'https://api.example.com',
  timeout: 5000
};
export let count: number = 0;
export let x: number = 10, y: number = 20, z: number = 30;
export let dom: HTMLDivElement = document.createElement("div");

export const func: Function = () => {
    return "hello";
};

export let classDecl: any = class ClassDecl {
    constructor(public name: string) {}
    method(): string {
        return `Hello, ${this.name}!`;
    }
};
