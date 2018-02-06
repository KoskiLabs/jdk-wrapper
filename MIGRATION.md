Migration from vjkoskela/jdk-wrapper to koskilabs/jdk-wrapper
=============================================================

1) You _must_ add `JDKW_DIST=oracle` to your JDK Wrapper invocations through some combination of:
    A) Declaration in your personal `~/.jdkw` file
    B) Declaration in your project `.jdkw` file(s)
    C) Argument in your `jdk-wrapper.sh` invocation
    D) Definition in your environment (e.g. via `.bashrc` or equivalents)

The other possible value for `JDKW_DIST` is `zulu` ([Zulu](https://www.azul.com/downloads/zulu/); aka OpenJDK). For more information please
consult the JDK Wrapper's [README.md](https://github.com/koskilabs/jdk-wrapper/blob/master/README.md).

2) You _may_ add `JDKW_RELEASE=<RELEASE>` to your JDK Wrapper invocations through some combination of:
    A) Declaration in your personal `~/.jdkw` file
    B) Declaration in your project `.jdkw` file(s)
    C) Argument in your `jdk-wrapper.sh` invocation
    D) Definition in your environment (e.g. via `.bashrc` or equivalents)

You can determine the value of `<RELEASE>` to use by examining the [Github releases](https://github.com/koskilabs/jdk-wrapper/releases) of
JDK Wrapper. The default value for `JDKW_RELEASE` is `latest`.

3) You _must_ replace all copies of `jdk-wrapper.sh` with the new `jdk-wrapper.sh` from [Github releases](https://github.com/koskilabs/jdk-wrapper/releases).
The new version acts as a wrapper for JDK Wrapper downloading and caching the version specified by `JDKW_RELEASE`. In the future to upgrade to a new version
of JDK Wrapper simply change the value of `JDKW_RELEASE` (or use `latest`; the default value of `JDKW_RELEASE`). Changes to the wrapper should occur far less
frequently than to the actual implementation. If there have been changes to the wrapper it will nag you about it until you update your `jdk-wrapper.sh`.
