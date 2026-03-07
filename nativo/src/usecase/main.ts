import { pluralize } from './util.ts';
import { pluralize as pluralize2, add } from './util.ts';
import { removeChildFromBody, request } from './dom.ts';

pluralize('apple', 1);
pluralize2('apple', 2);
add(1, 2);
removeChildFromBody(document.querySelector('#app')!);