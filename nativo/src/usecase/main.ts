// Test case: main.ts -> utils.ts -> helpers.ts -> constants.ts
// This tests recursive linking with 4 levels of dependencies

import { formatDate, formatNumber } from "./utils.ts";
import { Logger } from "./logger.ts";

export function main() {
    const logger = new Logger();
    logger.log("Starting application...");
    
    const date = formatDate(new Date());
    const num = formatNumber(12345.6789);
    
    logger.log(`Date: ${date}, Number: ${num}`);
}

main();
