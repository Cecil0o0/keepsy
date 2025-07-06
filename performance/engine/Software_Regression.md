# Software regression
A software regression is a type of software bug where a feature that has worked before stops working. This may happen after changes are applied to the software's source code, including the addition of new features and bug fixes. They may also introduced by changes to the environment in which the software is running, such as system upgrades, system patching or a change to daylight saving time. A software performance regression is a situation where the software still functions correctly, but performs more slowly or uses more memory or resources than before. Various types of software regressions have been identified in practice, including the following:
软件回归是一种软件缺陷，指之前正在工作的特性停止工作了。这可能在变更被应用到软件源代码之后发生，包括新特性和缺陷修复内容的添加。它们也可能软件所运行的环境的变更所引入，比如系统升级、系统补丁或夏令时的调整。软件性能回归是一个场景，指软件仍然正确的运行，但执行速度更慢或相比之前使用更多内存或资源。多种软件回归的类型在实践中被识别包括如下：

- Local - a change introduces a new bug in the changed module or component
- Remote - a change in one part of the software breaks functionality in another module or component.
- Unmasked - a change unmasks an already existing bug that had no effect before the change.
- 本地 - 一次变更向被变更的模块或组件引入一个新缺陷
- 远程 - 软件一部分的变更破坏了其他模块的或组件的功能性
- 未蒙面的 - 一次变更揭示了一个原本就存在的缺陷，该缺陷在变更之前不产生影响。

Regressions are often caused by encompassed bug fixes included in software patches. One approach to avoiding this kind of problem is regression testing. A properly designed test plan aims at preventing the likelihood of a regression.
回归通常由包含在软件补丁里的错误修复所导致的。一种避免此类问题的途径是回归测试。一个合理设计的测试计划旨在阻止性能回归的可能性。

## Prevention and detection

Techniques have been proposed that try to prevent regressions from being introduced into software at various stages of development, as outlined below.
技术被提案去尝试阻止在多个开发阶段中回归被引入软件，大纲如下：

### Prior to release

In order to avoid regressions being seen by the end-user after release, developers regularly run regression tests after changes are introduced to the software. These tests can include unit tests to catch local regressions as well as integation tests to catch remote regressions. Regression testing techniques often leverage existing test cases to minimize the effort involved in creating them. However, due to the volume of these existing tests, it is often necessary to select a representative subset, using techniques such as test-case prioritization.
为了避免回归在发布后被终端用户所见，开发者通常在变更被引入到软件之后运行集成测试。这些测试可以包括单元测试去捕获本地回归，同时集成测试去捕获远程回归。回归测试技术通常利用现有的测试用例去最小化创建它们的努力。然而，由于这些现有测试的总量，经常有必要去选择一个有代表性的子集，使用像测试用例优先级排序的技术。

For detecting performance regressions, software performance tests are run on a regular basis, to monitor the response time and resource usage metrics of the software after subsequent changes. Unlike functional regression tests, the results of performance tests are subject to variance - that is, results can differ between tests due to variance in performance measurements; as a result, a decision must be made on whether a change in performance numbers consititutes a regression, based on experience and end-user demands. Approaches such as [statistical significance testing](https://en.wikipedia.org/wiki/Statistical_significance_test) and change point detection are sometimes used to aid in this decision.
为检测性能回归，软件性能测试被定期运行，去监控后续变更的软件的响应时间和资源使用指标。不像功能回归测试那样，性能测试的结果是受差异影响的 - 那就是说，测试结果会由于性能度量多样性而有差异；因此，必须根据经验和用户需求，对于性能数字上的变化是否构成衰退。诸如 statistical significance testing 以及变更点检测有时被用于辅助这一决策。

### Prior to commit

Since debugging and localizing the root cause of a software regression can be expensive, there also exist some methods that try to prevent regressions from being committed into the code repository in the first place. For example, Git Hooks enable developers to run test scripts before code changes are committed or pushed to the code repository. In addition, change impact analysis has been applied to software to predict the impact of a code change on various components of the program, and to supplement test case selection and prioritization. Software linters are also often added to commit hooks to ensure consistent coding style, thereby minimizing stylistic issues that can make the software prone to regressions.
因为调试和定位软件回归根因会是非常昂贵的，也存在一些方法尝试在第一时间去阻止回归被提交至代码存储库。例如，Git 钩子使得开发者去在代码变更被提交或是推送到代码存储库之前运行测试脚本。额外的，变更影响分析被应用到软件中去预测在多组件的程序中一次代码变更的影响，并且去补充测试用例和优先级排序。软件 linters 也经常被添加到提交钩子中去确保一致性代码风格，从而最小化文体类难题这可能会导致软件容易出现回归问题。

## Localization

Many of the techniques used to find the root cause of non-regression software bugs can also be used to debug software regressions, including breakpoint debugging, print debugging, and program slicing. The techniques described below are often used specifically to debug software regressions.
许多被用以发现非回归软件缺陷的根因的技术也可以被用以调试软件回归，包括断点调试、打印调试、以及程序切片。下方描述的技术是经常被特别用来去调试软件回归。

### Functional regressions

A common techinique used to localize functional regressions is bisection, which takes both a buggy commit and a previouly working commit as input, and tries to find the root cause by doing a binary search on the commits in between. Version control systems such as Git and Mercurial provide built-in ways to perform bisection on a given pair of commits.
常见的用来去定位功能回归的技术是二分法，它接收一个错误提交和之前正常工作的提交作为输入，并且尝试通过在一组提交之间进行二分查找来发现根因。诸如 Git 和 Mercurial 的版本控制系统提供内置途径去执行二分法在给定的一对儿提交之间。

Other options include directly associating the result of a regression test with code changes; setting divergence breakpoints; or using incremental data-flow analysis, which identifies test cases - including failling ones - that are relevant to a set of code changes, among others.
其他选项包括直接将回归测试结果和代码更改关联起来；设置分叉点；使用增量数据流分析，该分析可标识与一组代码更改相关的测试用例（包括失败的测试用例）等。

### Performance regressions

[Profiling](https://en.wikipedia.org/wiki/Profiling_(computer_programming)) measures the performance and resource usage of various components of a program, and is used to generate data useful in debugging performance issues. In the context of software performance regressions, developers often compare the call trees (also known as "timelines") generated by profilers for both the buggy version and the previously working version, and mechanisms exist to simplify this comparison. Web development tools typically provide developers the ability to record these performance profiles.
剖析度量多组件程序的性能和资源使用，并被用以生成数据利于调试性能难题。在软件性能回归的上下文中，开发者经常比较调用树（也被称为“时间线”）被剖析器同时为有缺陷版本和前一个工作版本而生成的。网络开发工具通常提供给开发者能力去记录这些性能剖析数据。

Logging also helps with performance regression localization, and similar to call trees, developers can compare systemactically-placed performance logs of multiple versions of the same software. A tradeoff exists when adding these performance logs, as adding many logs can help developers pinpoint which portions of the software are regressing at smaller granularities, while adding only a few logs will also reduce overhead when executing the program.
打日志也帮助开发者定位性能回归，与调用树类似，开发者可以对比系统放置的相同软件的性能日志的多个版本。权衡取舍当添加这些性能日志时存在，因为添加许多日志可以帮助开发者在更细的力度上精准定位软件的哪个部分是回归的，而添加只有少量日志将也减少执行程序的开销。

Additional approaches include writing performance-aware unit tests to help with localization, and ranking subsystems based on performance counter deviations. Bisection can also be repurposed for performance regressions by considering commits that perform below (or above) a certain baseline value as buggy, and taking either the left or the right side of the commits based on the results of this comparison.
额外方法包括编写性能感知单测去帮助定位，并且基于性能计数器偏差来排序子系统。二分法也可以被重新利用于性能回归通过将执行低于具体基线值的提交看待为有缺陷的，并且基于比较结果去接收要么是左边要么右边的提交。
