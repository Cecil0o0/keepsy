## Make a change

Currently, I have no time to write a guideline for it.

## Debug Data Engine

Issues are unavoidable during the whole lifespan of Data Engine software. If you unfortunately encounter any problems during develop it, please follow the debugging guidelines below to help identify and resolve them efficiently.

**Prerequisites**
- Confirm that you are working on MacOS, and then I recommend that VSCode IDE to edit source code for rich helpful features.
- Install [Zig Language](https://marketplace.visualstudio.com/items?itemName=ziglang.vscode-zig) extension
- Install [CodeLLDB](https://marketplace.visualstudio.com/items?itemName=vadimcn.vscode-lldb) extension if you haven't.
- Directly open the `engine` folder with VSCode
- Use the [Debug User Interface](https://code.visualstudio.com/docs/debugtest/debugging) and start a debug session for yourself. To do it in one of the following ways:
  - Open file `src/main.zig`, click `Debug` of the CodeLens actions for the line `pub fn main() !void {`.
  - Confirm to grant priviledges if encountered.
  - Use the prepared Launch, triggered by the command `Debug: starting Debugging`.

💡 Adding a required breakpoints may help you quickly identity or locate that specific issue.