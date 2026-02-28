// logger.ts - no dependencies (leaf node)

export class Logger {
    private prefix: string;
    
    constructor(prefix: string = "[APP]") {
        this.prefix = prefix;
    }
    
    log(message: string): void {
        console.log(`${this.prefix} ${message}`);
    }
    
    error(message: string): void {
        console.error(`${this.prefix} ERROR: ${message}`);
    }
}
