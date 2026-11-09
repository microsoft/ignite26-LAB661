<a name="start-building"></a>

<p align="center">
<img src="img/banner-ignite-26.png" alt="Microsoft Ignite 2026" width="100%"/>
</p>

# [Microsoft Ignite 2026](https://ignite.microsoft.com)

## 🔥LAB661: Hill climbing for agents: From 60% to 90% with Open Source and Foundry
### Session description

Take a working agent that misses its target and improve it through hill climbing: a repeatable process for making one measured change at a time. Use ASSERT to generate evaluations and test data from requirements, create scoring criteria with Rubrics, and implement controls with Agent Control Specification (ACS). Then run the evaluations against real models on Microsoft Foundry to measure results and iterate toward higher quality, lower cost, and safer outcomes.

### 🚀 Getting started

In this lab you take Contoso DevBot, a coding agent that misses its target, and
climb toward a safe agent one measured change at a time. ASSERT measures what
DevBot gets wrong, an Agent Control Specification (ACS) policy generated from that
evidence blocks it, and the same evaluation proves the change worked. The
[attendee instructions](instructions/README.md) show how every lab maps to the
session.

#### In a guided session

If you're in the Ignite lab room:

1. Open the lab in Skillable. Your environment is prepared for you.
2. Follow the [Skillable manual](instructions/skillable/README.md), starting with the "Core" labs.
3. If you finish early, continue with the optional "More" labs.

#### On your own

If you're learning at your own pace:

1. Open this repository in GitHub Codespaces to get a prebuilt environment.
2. Follow the [Self-paced guide](instructions/self-paced/README.md), starting with the "Core" labs.
3. If you finish early, continue with the optional "More" labs.

### 🎯 Learning outcomes

By the end of this session, you will be able to:

- Apply a hill-climbing loop to an agent: measure where it fails with ASSERT, make one change, and verify the result with the same evidence.
- Generate an Agent Control Specification (ACS) policy from evaluation findings, validate that it blocks every known-bad output, and enforce it at runtime without editing the agent.
- Run the loop on real models in Microsoft Foundry with your Azure identity, and use the run-assert-eval skill with GitHub Copilot to go from a named risk to a proven fix.

### 💻 Technologies used

- [ASSERT](https://responsibleai.github.io/ASSERT/). Read [Turn specs into evals for any agent with ASSERT](https://commandline.microsoft.com/assert-written-intent-executable-evals/).
- [Rubrics](https://github.com/responsibleai/ASSERT/blob/main/docs/concepts.md#judge), the ASSERT judge rubrics. Read [Are your AI evals measuring the right things?](https://commandline.microsoft.com/structured-ai-evaluation-design-assert-vs-petri-bloom/)
- [Agent Control Specification (ACS)](https://github.com/responsibleai/agent-control-spec). Read [Agent Control Specification: Portable runtime governance for AI agents](https://commandline.microsoft.com/agent-control-specification-runtime-governance/) and [Evaluating, controlling, and optimizing AI agents with ASSERT and ACS](https://commandline.microsoft.com/safety-requirements-failure-paths-assert-acs/).
- [Microsoft Foundry Models](https://learn.microsoft.com/azure/foundry/concepts/foundry-models-overview). Read [The agent optimization loop and how we built it in Foundry](https://commandline.microsoft.com/the-agent-optimization-loop-and-how-we-built-it-in-foundry/).
- [GitHub Copilot agent skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills). Read [Introducing run-assert-eval: Find the risk, fix it, prove it](https://commandline.microsoft.com/run-assert-eval-responsible-ai-agent-risk-discovery-at-runtime/).

### 📚 Continue your learning

Pick your next step based on your learning style:

| Resource | What you'll get |
|----------|-----------------|
| **[Ignite 2026 Next Steps](https://aka.ms/ignite26-next-steps)** | Additional session repos and materials from Microsoft Ignite 2026 |
| **[Microsoft AI Skills Navigator](https://aka.ms/ignite26-asn)** | Discover AI skills, learning paths, and resources for your next step |
| **[Microsoft Learn](https://aka.ms/ignite26-learn)** | Official documentation and guided learning paths on these topics |
| **[Microsoft Foundry Community](https://aka.ms/MicrosoftFoundryDiscord-Ignite26)** | Connect with other learners and experts in our Discord community |

### 🌟 Microsoft Learn MCP Server

The Microsoft Learn MCP Server gives your AI agent direct access to Microsoft's official documentation — grounded, up-to-date answers about the topics in this session.

**GitHub Copilot CLI** — Install with:

```shell
copilot plugin install microsoftdocs/mcp
```

**VS Code** — One-click install:  
[![Install in VS Code](https://img.shields.io/badge/VS_Code-Install_Microsoft_Learn_MCP-0098FF?style=flat-square&logo=visualstudiocode&logoColor=white)](https://vscode.dev/redirect/mcp/install?name=microsoft-learn&config=%7B%22type%22%3A%22http%22%2C%22url%22%3A%22https%3A%2F%2Flearn.microsoft.com%2Fapi%2Fmcp%22%7D)

For more information, visit the [Learn MCP Server repo](https://aka.ms/learnmcp).

### 👥 Content owners

<table>
<tr>
    <td align="center"><a href="https://github.com/nitya">
        <img src="https://github.com/nitya.png" width="100px;" alt="Nitya Narasimhan"/><br />
        <sub><b>Nitya Narasimhan</b></sub></a><br />
            <a href="https://github.com/nitya" title="talk">📢</a>
    </td>
    <td align="center"><a href="https://github.com/spiderpc">
        <img src="https://github.com/spiderpc.png" width="100px;" alt="Mike Shi"/><br />
        <sub><b>Mike Shi</b></sub></a><br />
            <a href="https://github.com/spiderpc" title="talk">📢</a>
    </td>
    <td align="center"><a href="https://github.com/mesameki">
        <img src="https://github.com/mesameki.png" width="100px;" alt="Mehrnoosh Sameki"/><br />
        <sub><b>Mehrnoosh Sameki</b></sub></a><br />
            <a href="https://github.com/mesameki" title="talk">📢</a>
    </td>
</tr></table>

### ⚖️ Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.

Any use of third-party trademarks or logos are subject to those third-party's policies.
