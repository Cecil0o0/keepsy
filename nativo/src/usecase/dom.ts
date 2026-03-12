import { naming } from './base.ts';

console.log(naming);

export function removeChildFromBody(dom: HTMLElement) {
    document.body.removeChild(dom);
}

export async function request() {
    fetch('https://google.com');
}
