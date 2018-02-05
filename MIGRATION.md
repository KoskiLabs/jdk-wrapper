Migration from vjkoskela/jdk-wrapper to koskilabs/jdk-wrapper
=============================================================

1) You must add `JDKW_VERSION=<VERSION>` to your JDK Wrapper invocations through some combination of:
    A) Declaration in your personal `~/.jdkw` file
    B) Declaration in your project `.jdkw` file(s)
    C) Argument in your `jdk-wrapper.sh` invocation
    D) Definition in your environment (e.g. via `.bashrc` or equivalents)

You can determine the value of `<VERSION>` to use by examining the [Github releases](https://github.com/koskilabs/jdk-wrapper/releases) of JDK Wrapper.

2) You must add `JDKW_DIST=oracle` to your JDK Wrapper invocations through some combination of:
    A) Declaration in your personal `~/.jdkw` file
    B) Declaration in your project `.jdkw` file(s)
    C) Argument in your `jdk-wrapper.sh` invocation
    D) Definition in your environment (e.g. via `.bashrc` or equivalents)

The other possible value for `JDKW_DIST` is `zulu` ([Zulu](https://www.azul.com/downloads/zulu/); aka OpenJDK). For more information please consult the JDK Wrapper's [README.md](https://github.com/koskilabs/jdk-wrapper/blob/master/README.md).

3) You must replace all copies of `jdk-wrapper.sh` with the new `jdk-wrapper.sh` from [Github releases](https://github.com/koskilabs/jdk-wrapper/releases).
The new version acts as a wrapper for JDK Wrapper downloading and caching the version specified by `JDKW_VERSION`. In the future to upgrade to a new version
of JDK Wrapper simply change the value of `JDKW_VERSION`. Changes to the wrapper should occur far less frequently than to the actual implementation. If there
have been changes to the wrapper it will nag you about it until you update your `jdk-wrapper.sh`.