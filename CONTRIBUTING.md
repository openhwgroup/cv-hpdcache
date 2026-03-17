# How to Contribute to the OpenHW HPDcache Repository

Contributions are welcomed and encouraged.

## Issues

If you encounter any problem (e.g. bug in the RTL model or missing description of a feature in the documentation) while using the HPDcache, please you are invited to [open an issue](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/creating-an-issue) in the official Github's repository of the [HPDcache](https://github.com/openhwgroup/cv-hpdcache).

Remember to explain sufficiently your issue to allow maintainers to reproduce it. A good description would contain the following:

- A descriptive title: Summarize the issue concisely
- Detailed description: Provide context, including what you expected to happen versus what actually occurred
- Steps to reproduce: Include step-by-step instructions for replicating the bug
- Screenshots or logs: Visuals or logs can help others understand the problem quickly
- Environment details: Mention the version of the tools and RTL, if relevant
- Labels: Use tags like "bug", "enhancement", "testbench", or "question" to categorize the issue properly

## Pull-Requests

If you want to contribute to the HPDcache's repository (e.g. fix a bug or add a new feature in the RTL of the HPDcache, improve the documentation or add additional test sequences in the testbench), you are welcomed to open a pull-request.

To do that, we invite you to follow the following steps:

1. All contributors are required to be covered by the [Eclipse Contributor Agreement](https://www.eclipse.org/legal/ECA.php).
   Please follow the corresponding instructions before creating a pull-request
2. In some cases, it may be interesting to open an issue with the "question" tag to ask if someone is already working on the feature you would like to propose, or if the community would be interested in such feature
3. If you modify the RTL or the testbench's C++ code, before creating the pull-request, you should run the provided smoke tests.
   The provided ``smoke_tests.sh`` script does some code formatting checks (RTL and C++), and also runs some tests in the C++ testbench with different hardware configurations of the HPDcache.
```bash
bash ./rtl/tb/scripts/smoke_tests.sh
```
4. If all tests passed, you can create the [pull-request](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request).

To create a pull request you will need to: fork the HPDcache's repository in your personal Github account, create a branch with your modifications, and open the pull-request.
For detailed instructions on how to do this, you can follow [Github's official instructions](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request-from-a-fork).

After the creation of the pull-request, we have some Continuous Integration (CI) tests that will be executed on Github's servers.
If one test fails, you can look into the logs from your web browser.
You can rerun the failing test locally to debug the issue.

## How to run tests locally

You can go into the ``rtl/tb`` directory if you want to run other tests or if you want to debug any issues found during the execution of smoke tests.
Please read the testbench's [README.md](rtl/tb/README.md) to see how to do that.

## Code Conventions

For the RTL code, we follow the [LowRISC guidelines](https://github.com/lowRISC/style-guides?tab=readme-ov-file).
Please take a look on these documents before creating a pull-request.
These code conventions are checked by one of the tests of the CI.
You can also run the code formatting checks locally:
```bash
cd rtl/lint
make verible-lint
```

For the C++ code in the testbench, there are also some code conventions.
You can check for those by running the following:
```bash
cd rtl/tb
./scripts/check_format_tb.sh
```

We use clang-format to do this check.
The corresponding clang-format configuration file is ``rtl/tb/.clang-format``
