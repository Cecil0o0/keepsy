# RFC Process

This document describes the RFC process for the keepsy, and provides a way for the keepsy team and the wider community to have discussions about the features and direction of the enterprise-level big data product.
这篇文档描述了 keepsy 征求意见稿的过程，并且为 keepsy 团队和更广泛的社区提供一条途径去讨论有关企业级大数据产品的特性与方向。

# What is an RFC?

The name is a reference to the IETF's Request For Comments process, and involves a document or series of documents which are drafted, reviewd, and eventually ratified (approved) by the keepsy team through discussion among those interested, both within and outside of the keepsy team.
名字是对 IETF 组织的征求意见稿过程的参考与引用，并涉及一篇或一系列文档它们被 keepsy 团队经过对其中感兴趣的文档主题进行探讨后逐步被草稿、评审并最终批准。

# Rough Consensus

The development of new features within the keepsy follows a [Rough Consensus](https://datatracker.ietf.org/doc/html/rfc7282) model, similar to the IETF.
在 keepsy 中新特性的开发遵循一个[粗略共识](https://datatracker.ietf.org/doc/html/rfc7282)模型，类似于 IETF。

The following points are intended to help you understand and participate in this process productively.
下列观点旨在帮助你理解并富有成效的参与过程中。

## Scope of This Process

This RFC process is limited to issues concerning the keepsy and the software services that support it.
此征求意见稿过程仅限于考虑 keepsy 以及支持它的软件服务的问题。

Of course we operate within a broad community ecosystem, and will often choose to implement features in a way that is compatible with other big data software in the open source community. However, if a given proposal cannot or will not be implemented by other big data software, that is not in itself reason enough to abandon a proposal. We are here to make keepsy better.
当然我们在一个广泛的社区系统中运作，并将经常选择去实施特性以一种兼容开源社区其他大数据软件的途径。然而，如果一个给定的提案无法或是将不会被其他大数据软件实施，是不足以充分理由去放弃一个提案。我们在这里是去使 keepsy 更好。

## Full Consensus is Not The Goal

It is not our intention, or within our ability, to accomodate every possible objection to any given proposal. It is our intention to surface all such objections, and make an informed decision as to whether the objection can be addressed, should be accepted, or is reason enough to abandon the proposal entirely.
这并非我们本意，也超出我们的能力范畴，对任意给定的提案去顾及每一个可能的反对意见。我们的本意是去揭示所有这样的反对意见，并非正式的决定是否反对意见可以被解决、应该被接受、或是足够有理由去完全的放弃提案。

We encourage you to participate in these discussions, and to feel free and comfortable bringing up any objections that you have or can imagine (even if you don't entirely agree with the objection!)
我们鼓励你去参与进这些讨论，并你有或可以想象的任何反对意见都可以随意、自在的提出来（即使你不完全同意这个反对意见！）

Our job together then, is to ensure that the objection is given a fair hearing, and is fully understood. Then (either in the pull request comments, or in our OpenRFC meetings), we will decide whether the proposal should be modified in light of the objection, or the objection should be ignored, or if the proposal shoud be abandoned.
那么我们共同的工作，是去确保反对意见被给予公平的倾听，并且是完全理解的。然后（要么是拉去请求评论要么是在我们的 OpenRFC 会议之上），我们将会根据反对意见决定是否提案应该被修改或是反对意见应该被忽略，或是提案应该被放弃。

If an objection is brought up a second time without any relevant changes, after having already been addressed, then it will be ignored. Only new objections merit new or continued consideration.
如果一个反对意见被得到处理再次提出且没有任何相关变化的话，然后它将会被忽略。只有新的反对意见值得新的或是继续的考虑。

## Iterate on Building Blocks

Frequently a feature will be proposed or even fully specified in an RFC, and upon analysis, the feedback might be to cut it into seperate RFCs, or implement another proposal first.
通常来说一个特性将会被提出或甚至完全制定于一次征求意见稿中，并经过分析，反馈也许被拆解到独立的征求意见稿中，或是优先实施另一个提案。

This can be frustrating at times, but it ensures that we are taking care to improve keepsy iteratively, with thorough consideration of each step along the way.
有些时候这可以是令人沮丧的，但它确保我们正在悉心的迭代式的提升 keepsy，并对每一步都进行过全面的思考。

## Implementation as Exploration

Typically, RFCs are discussed and ratified prior to implementation. However, this is not always the case! Occasionally, we will develop a feature when write an RFC after the fact to describe and discuss it prior to merging into the latest keepsy release.
通常来说，征求意见稿被讨论并批准先于实施。然而，事情不总是这样！偶然的，我们将会开发一个特性当在事实发生之后编写征求意见稿去描述和讨论它，先于合并到最新的 keepsy 发布。

Very often, an RFC will be difficult to examine without running code. In those cases, we may opt to develop a proof of concept (or even fully production-ready implementation) of an RFC in process, in order to test it in reality before accepting it.
经常征求意见稿将是难以测验如果不运行代码的话。在那些情况中，在过程中我们也许可选的去开发一个征求意见稿的概念验证（或甚至完全生产就绪的实施），为了在接受它之前在实际情况下测试它。

Even when an RFC is accepted, during implementation it is common to note additional objections, features, or decisions that need to be made. In these cases, we may propose an amendment to a previously ratified RFC.
即使当征求意见稿被接受，在实施它的期间内经常是去评注额外的反对意见、特性、或是需要去制作的决定。在这些情况中，我们也许提出一个修订到先前批准的征求意见稿。