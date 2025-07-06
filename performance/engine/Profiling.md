# Profiling (computer programming)

In software engineering, profiling (program profiling, software profiling) is a form of dynamic program analysis that measures, for example, the space (memory) or time complexity of a program, the usage of particular instructions, or the frequency and duration of function calls. Most commonly, profiling information serves to aid program optimization, and more specifically, performance engineering.
在软件工程中，剖析（程序剖析、软件剖析）是一种动态程序分析形势它度量，比如，一个程序的空间（内存）或时间复杂度，特定指令的使用，或函数调用的频率和时长。最常见的是，剖析信息服务于辅助程序优化，更准确的来说，性能工程。

Profiling is achieved by instrumenting either the program source code or its binary executable form using a tool called a profiler (or code profiler). Profilers may use a number of different techniques, such as event-based, statistical, instrumented, and simulation methods.
剖析通过使用一种称为剖析器的工具去检测要么是程序源码或它的二进制可执行形式（或称为代码剖析器）。剖析器可能使用一系列不同的技术，比如基于事件的方法、统计方法、检测方法、和模拟方法。

## Gathering program events

Profilers use a wide variety of techniques to collect data, including hardware interrupts, code instruction, instruction set simulation, operating system hooks, and performance counters.
剖析器使用广泛技术去收集数据，包括硬件中断、代码指令、指令集模拟、操作系统钩子，以及性能计数器。

## Use of profilers

The output of a profiler may be:
剖析器的输出可能是：

- A statistical summary of the events observed (a profile) Summary profile information is often shown annotated against the source code statements where the events occur, so the size of measurement data is linear to the code size of the program.
- 事件观察的统计汇总（一份资料）汇总资料信息通常展示有注释的事件发生的源代码语句，所以度量数据的大小和程序的代码大小是线性关系。

```shell
/* -------------- source ------------------- count */
0001              IF X = "A".                0055
0002                  THEN DO
0003                      ADD 1 to XCOUNT    0032
0004                  ELSE
0005              IF X = "B"                 0055
```

- A stream of recorded events (a trace)
  For sequential programs, a summary profile is usually sufficient, but performance problems in parallel programs (waiting for messages or sychronization issues) often depend on the time relationship of events, thus requiring a full trace to get an understanding of what is hanppening.
  The size of a (full) trace is linear to the program's instruction path length, making it somewhat impractical. A trace may therefore be initiated at one point in a program and terminated at another point to limit the output.
- 一条事件记录流（追踪）
  对于顺序程序，汇总资料通常是充分的，但是在并行程序的性能难题（等待消息或同步难题）通常依赖于事件的时间关系，因此需要一次完整追踪去理解发生了什么。
  一次追踪的大小和程序指令路径长度呈线性关系，这使得它在某种程度上不太实用。追踪可能在程序的某一点启动并且在另一个点终止去限制输出。

- An ongoing interaction with the hypervisor (continuous or periodic monitoring via on-screen display for instance)
  This provides the opportunity to switch a trace on or off at any desired point during execution in addition to viewing on-going metrics about the (still executing) program. It also provides the opportunity to suspend asynchronous processes at critical points to examine interactions with other parallel processess in more detail.
  与 hypervisor （例如通过屏幕上展示的连续或周期监控）正在进行的交互
  这不仅提供了在执行中的任何期望时机点去切换追踪的启停状态的机会而且可以查看有关（仍在执行中的）程序的进行中指标。它也提供在关键点挂起异步程进程去测验和其他并行进程交互的机会。

A profiler can be applied to an individual method or at the scale of a module or program, to identify performance bottlenecks by making long-running code obvious. A profiler can be used to understand code from a timing point of view, with the objective of optimizing it to handle various runtime conditions or various loads. Profiling results can be ingested by a compiler that provides profile-guided optimization. Profiling results can be used to guide the design and optimization of an individual algorithm; the Krauss matching wildcards algorithm is an example. Profilers are built into some application performance management systems that aggregate profiling data to provide insight into transaction workloads in distributed applications.
剖析器可以被应用于单个独立方法或在模块或程序的级别，去通过长时间运行代码显而易见的标识性能瓶颈。剖析器可以被用于从时间的角度去理解代码，目的是优化它来处理多种运行时条件或多种负载。剖析结果可被编译器摄取它提供剖析指引的优化。剖析结果可被用于去指引独立算法的设计和优化；Krauss 模糊匹配算法是一个案例。剖析器被构建进一些应用程序性能管理系统它聚合剖析数据为分布式应用成中的事务型工作负载提供见解。


