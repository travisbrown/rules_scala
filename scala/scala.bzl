load(
    "@io_bazel_rules_scala//scala/private:rule_impls.bzl",
    _scala_library_impl = "scala_library_impl",
    _scala_macro_library_impl = "scala_macro_library_impl",
    _scala_binary_impl = "scala_binary_impl",
    _scala_test_impl = "scala_test_impl",
    _scala_repl_impl = "scala_repl_impl",
    _scala_junit_test_impl = "scala_junit_test_impl",
)

load(
    "@io_bazel_rules_scala//scala:providers.bzl",
    _ScalacProvider = "ScalacProvider",
)

load(
    "@io_bazel_rules_scala//scala:scala_cross_version.bzl",
    _new_scala_repository = "new_scala_repository"
)

load(
    "@io_bazel_rules_scala//specs2:specs2_junit.bzl",
    _specs2_junit_dependencies = "specs2_junit_dependencies")

_launcher_template = {
    "_java_stub_template": attr.label(
        default = Label("@java_stub_template//file")),
}



_implicit_deps = {
    "_singlejar": attr.label(
        executable = True,
        cfg = "host",
        default = Label("@bazel_tools//tools/jdk:singlejar"),
        allow_files = True),
    "_ijar": attr.label(
        executable = True,
        cfg = "host",
        default = Label("@bazel_tools//tools/jdk:ijar"),
        allow_files = True),
    "_zipper": attr.label(
        executable = True,
        cfg = "host",
        default = Label("@bazel_tools//tools/zip:zipper"),
        allow_files = True),
    "_java_toolchain": attr.label(
        default = Label("@bazel_tools//tools/jdk:current_java_toolchain")),
    "_host_javabase": attr.label(
        default = Label("@bazel_tools//tools/jdk:current_java_runtime"),
        cfg = "host"),
    "_java_runtime": attr.label(
        default = Label("@bazel_tools//tools/jdk:current_java_runtime"), cfg = "host")
}

scala_deps = {
    "scalac": attr.label(default = Label("@scala_default"), providers = [_ScalacProvider], cfg = "host")
}

# Single dep to allow IDEs to pickup all the implicit dependencies.
_resolve_deps = {
    "_scala_toolchain": attr.label_list(
        default = [
            Label(
                "//external:io_bazel_rules_scala/dependency/scala/scala_library"
            ),
        ],
        allow_files = False),
}

# TODO not version specific
_test_resolve_deps = {
    "_scala_toolchain": attr.label_list(
        default = [
            Label(
                "//external:io_bazel_rules_scala/dependency/scala/scala_library"
            ),
            Label(
                "//external:io_bazel_rules_scala/dependency/scalatest/scalatest_2_11"
            ),
        ],
        allow_files = False),
}

_junit_resolve_deps = {
    "_scala_toolchain": attr.label_list(
        default = [
            Label(
                "//external:io_bazel_rules_scala/dependency/scala/scala_library"
            ),
            Label("//external:io_bazel_rules_scala/dependency/junit/junit"),
            Label(
                "//external:io_bazel_rules_scala/dependency/hamcrest/hamcrest_core"
            ),
        ],
        allow_files = False),
}

# Common attributes reused across multiple rules.
_common_attrs_for_plugin_bootstrapping = {
    "srcs": attr.label_list(allow_files = [".scala", ".srcjar", ".java"]),
    "deps": attr.label_list(),
    "plugins": attr.label_list(allow_files = [".jar"]),
    "runtime_deps": attr.label_list(),
    "data": attr.label_list(allow_files = True, cfg = "data"),
    "resources": attr.label_list(allow_files = True),
    "resource_strip_prefix": attr.string(),
    "resource_jars": attr.label_list(allow_files = True),
    "scalacopts": attr.string_list(),
    "javacopts": attr.string_list(),
    "jvm_flags": attr.string_list(),
    "scalac_jvm_flags": attr.string_list(),
    "javac_jvm_flags": attr.string_list(),
    "print_compile_time": attr.bool(default = False, mandatory = False),
}

_common_attrs = {}
_common_attrs.update(_common_attrs_for_plugin_bootstrapping)
_common_attrs.update({
    # using stricts scala deps is done by using command line flag called 'strict_java_deps'
    # switching mode to "on" means that ANY API change in a target's transitive dependencies will trigger a recompilation of that target,
    # on the other hand any internal change (i.e. on code that ijar omits) WON’T trigger recompilation by transitive dependencies
    "_dependency_analyzer_plugin": attr.label(
        default = Label(
            "@io_bazel_rules_scala//third_party/plugin/src/main:dependency_analyzer"
        ),
        allow_files = [".jar"],
        mandatory = False),
})

_library_attrs = {
    "main_class": attr.string(),
    "exports": attr.label_list(allow_files = False),
}

_common_outputs = {
    "jar": "%{name}.jar",
    "deploy_jar": "%{name}_deploy.jar",
    "manifest": "%{name}_MANIFEST.MF",
    "statsfile": "%{name}.statsfile",
}

_library_outputs = {}
_library_outputs.update(_common_outputs)
_library_outputs.update({
    "ijar": "%{name}_ijar.jar",
})

_scala_library_attrs = {}
_scala_library_attrs.update(_implicit_deps)
_scala_library_attrs.update(scala_deps)
_scala_library_attrs.update(_common_attrs)
_scala_library_attrs.update(_library_attrs)
_scala_library_attrs.update(_resolve_deps)

scala_library = rule(
    implementation = _scala_library_impl,
    attrs = _scala_library_attrs,
    outputs = _library_outputs,
    fragments = ["java"],
    toolchains = ['@io_bazel_rules_scala//scala:toolchain_type'],
)

# the scala compiler plugin used for dependency analysis is compiled using `scala_library`.
# in order to avoid cyclic dependencies `scala_library_for_plugin_bootstrapping` was created for this purpose,
# which does not contain plugin related attributes, and thus avoids the cyclic dependency issue
_scala_library_for_plugin_bootstrapping_attrs = {}
_scala_library_for_plugin_bootstrapping_attrs.update(_implicit_deps)
_scala_library_for_plugin_bootstrapping_attrs.update(scala_deps)
_scala_library_for_plugin_bootstrapping_attrs.update(_library_attrs)
_scala_library_for_plugin_bootstrapping_attrs.update(_resolve_deps)
_scala_library_for_plugin_bootstrapping_attrs.update(
    _common_attrs_for_plugin_bootstrapping)
scala_library_for_plugin_bootstrapping = rule(
    implementation = _scala_library_impl,
    attrs = _scala_library_for_plugin_bootstrapping_attrs,
    outputs = _library_outputs,
    fragments = ["java"],
    toolchains = ['@io_bazel_rules_scala//scala:toolchain_type'],
)

_scala_macro_library_attrs = {
    "main_class": attr.string(),
    "exports": attr.label_list(allow_files = False),
}
_scala_macro_library_attrs.update(_implicit_deps)
_scala_macro_library_attrs.update(scala_deps)
_scala_macro_library_attrs.update(_common_attrs)
_scala_macro_library_attrs.update(_library_attrs)
_scala_macro_library_attrs.update(_resolve_deps)
scala_macro_library = rule(
    implementation = _scala_macro_library_impl,
    attrs = _scala_macro_library_attrs,
    outputs = _common_outputs,
    fragments = ["java"],
    toolchains = ['@io_bazel_rules_scala//scala:toolchain_type'],
)

_scala_binary_attrs = {
    "main_class": attr.string(mandatory = True),
    "classpath_resources": attr.label_list(allow_files = True),
}
_scala_binary_attrs.update(_launcher_template)
_scala_binary_attrs.update(_implicit_deps)
_scala_binary_attrs.update(scala_deps)
_scala_binary_attrs.update(_common_attrs)
_scala_binary_attrs.update(_resolve_deps)
scala_binary = rule(
    implementation = _scala_binary_impl,
    attrs = _scala_binary_attrs,
    outputs = _common_outputs,
    executable = True,
    fragments = ["java"],
    toolchains = ['@io_bazel_rules_scala//scala:toolchain_type'],
)

_scala_test_attrs = {
    "main_class": attr.string(
        default = "io.bazel.rulesscala.scala_test.Runner"),
    "suites": attr.string_list(),
    "colors": attr.bool(default = True),
    "full_stacktraces": attr.bool(default = True),
    "_scalatest_reporter_2_11": attr.label(default = "//scala/support:test_reporter_2.11"),
    "_scalatest_reporter_2_12": attr.label(default = "//scala/support:test_reporter_2.12"),
}
_scala_test_attrs.update(_launcher_template)
_scala_test_attrs.update(_implicit_deps)
_scala_test_attrs.update(scala_deps)
_scala_test_attrs.update(_common_attrs)
_scala_test_attrs.update(_test_resolve_deps)
scala_test = rule(
    implementation = _scala_test_impl,
    attrs = _scala_test_attrs,
    outputs = _common_outputs,
    executable = True,
    test = True,
    fragments = ["java"],
    toolchains = ['@io_bazel_rules_scala//scala:toolchain_type'],
)

_scala_repl_attrs = {}
_scala_repl_attrs.update(_launcher_template)
_scala_repl_attrs.update(_implicit_deps)
_scala_repl_attrs.update(scala_deps)
_scala_repl_attrs.update(_common_attrs)
_scala_repl_attrs.update(_resolve_deps)
scala_repl = rule(
    implementation = _scala_repl_impl,
    attrs = _scala_repl_attrs,
    outputs = _common_outputs,
    executable = True,
    fragments = ["java"],
    toolchains = ['@io_bazel_rules_scala//scala:toolchain_type'],
)

def scala_repositories(scala_default = "2.11.11", additional_scala_versions = [("scala_version_label", "2.12.6")]):
  # required for bootstrapping scalatest_reporter
  _new_scala_repository("scala", "2.11.11")
  _new_scala_repository("scala_2_12", "2.12.5")

  _new_scala_repository("scala_default", scala_default)
  for scala_version_label, version in additional_scala_versions:
    _new_scala_repository(scala_version_label, version)

  # scalatest has macros, note http_jar is invoking ijar
  native.http_jar(
      name = "scalatest_2_11",
      url = "http://central.maven.org/maven2/org/scalatest/scalatest_2.11/2.2.6/scalatest_2.11-2.2.6.jar"
  )
  native.http_jar(
      name = "scalactic_2_11",
      url = "http://central.maven.org/maven2/org/scalactic/scalactic_2.11/3.0.5/scalactic_2.11-3.0.5.jar"
  )

  native.http_jar(
      name = "scalatest_2_12",
      url = "http://central.maven.org/maven2/org/scalatest/scalatest_2.12/3.0.5/scalatest_2.12-3.0.5.jar"
  )
  native.http_jar(
      name = "scalactic_2_12",
      url = "http://central.maven.org/maven2/org/scalactic/scalactic_2.12/3.0.5/scalactic_2.12-3.0.5.jar"
  )
  native.http_jar(
      name = "scala_xml_2_11",
      url = "http://central.maven.org/maven2/org/scala-lang/modules/scala-xml_2.11/1.0.5/scala-xml_2.11-1.0.5.jar"
  )
  native.http_jar(
      name = "scala_xml_2_12",
      url = "http://central.maven.org/maven2/org/scala-lang/modules/scala-xml_2.12/1.0.5/scala-xml_2.12-1.0.5.jar"
  )
  native.http_jar(
      name = "scala_parser_combinators_2_11",
      url = "http://central.maven.org/maven2/org/scala-lang/modules/scala-parser-combinators_2.11/1.0.4/scala-parser-combinators_2.11-1.0.4.jar"
  )

  native.http_jar(
      name = "scala_parser_combinators_2_12",
      url = "http://central.maven.org/maven2/org/scala-lang/modules/scala-parser-combinators_2.12/1.0.4/scala-parser-combinators_2.12-1.0.4.jar"
  )

  native.maven_server(
      name = "scalac_deps_maven_server",
      url = "https://mirror.bazel.build/repo1.maven.org/maven2/",
  )

  native.maven_jar(
      name = "scalac_rules_protobuf_java",
      artifact = "com.google.protobuf:protobuf-java:3.1.0",
      sha1 = "e13484d9da178399d32d2d27ee21a77cfb4b7873",
      server = "scalac_deps_maven_server",
  )

  # used by ScalacProcessor
  native.maven_jar(
      name = "scalac_rules_commons_io",
      artifact = "commons-io:commons-io:2.6",
      sha1 = "815893df5f31da2ece4040fe0a12fd44b577afaf",
      # bazel maven mirror doesn't have the commons_io artifact
      #      server = "scalac_deps_maven_server",
  )

  # Template for binary launcher
  BAZEL_JAVA_LAUNCHER_VERSION = "0.4.5"
  java_stub_template_url = (
      "raw.githubusercontent.com/bazelbuild/bazel/" +
      BAZEL_JAVA_LAUNCHER_VERSION +
      "/src/main/java/com/google/devtools/build/lib/bazel/rules/java/" +
      "java_stub_template.txt")
  native.http_file(
      name = "java_stub_template",
      urls = [
          "https://mirror.bazel.build/%s" % java_stub_template_url,
          "https://%s" % java_stub_template_url
      ],
      sha256 =
      "f09d06d55cd25168427a323eb29d32beca0ded43bec80d76fc6acd8199a24489",
  )

  native.bind(
      name = "io_bazel_rules_scala/dependency/com_google_protobuf/protobuf_java",
      actual = "@scalac_rules_protobuf_java//jar")

  native.bind(
      name = "io_bazel_rules_scala/dependency/commons_io/commons_io",
      actual = "@scalac_rules_commons_io//jar")

  native.bind(
      name = "io_bazel_rules_scala/dependency/scala/scala_compiler",
      actual = "@scala_imports//:scala-compiler")

  native.bind(
      name = "io_bazel_rules_scala/dependency/scala/scala_library",
      actual = "@scala_imports//:scala-library")

  native.bind(
      name = "io_bazel_rules_scala/dependency/scala/scala_reflect",
      actual = "@scala_imports//:scala-reflect")

  native.bind(
      name = "io_bazel_rules_scala/dependency/scalatest/scalatest_2_11",
      actual = "@scalatest_2_11//jar")

  native.bind(
      name = "io_bazel_rules_scala/dependency/scalatest/scalatest_2_12",
      actual = "@scalatest_2_12//jar")

def _sanitize_string_for_usage(s):
  res_array = []
  for idx in range(len(s)):
    c = s[idx]
    if c.isalnum() or c == ".":
      res_array.append(c)
    else:
      res_array.append("_")
  return "".join(res_array)

# This auto-generates a test suite based on the passed set of targets
# we will add a root test_suite with the name of the passed name
def scala_test_suite(name,
                     srcs = [],
                     deps = [],
                     runtime_deps = [],
                     data = [],
                     resources = [],
                     scalacopts = [],
                     jvm_flags = [],
                     visibility = None,
                     size = None,
                     colors = True,
                     full_stacktraces = True):
  ts = []
  for test_file in srcs:
    n = "%s_test_suite_%s" % (name, _sanitize_string_for_usage(test_file))
    scala_test(
        name = n,
        srcs = [test_file],
        deps = deps,
        runtime_deps = runtime_deps,
        resources = resources,
        scalacopts = scalacopts,
        jvm_flags = jvm_flags,
        visibility = visibility,
        size = size,
        colors = colors,
        full_stacktraces = full_stacktraces)
    ts.append(n)
  native.test_suite(name = name, tests = ts, visibility = visibility)

# Scala library suite generates a series of scala libraries
# then it depends on them with a meta one which exports all the sub targets
def scala_library_suite(name,
                        srcs = [],
                        deps = [],
                        exports = [],
                        plugins = [],
                        runtime_deps = [],
                        data = [],
                        resources = [],
                        resource_strip_prefix = "",
                        scalacopts = [],
                        javacopts = [],
                        jvm_flags = [],
                        print_compile_time = False,
                        visibility = None):
  ts = []
  for src_file in srcs:
    n = "%s_lib_%s" % (name, _sanitize_string_for_usage(src_file))
    scala_library(
        name = n,
        srcs = [src_file],
        deps = deps,
        plugins = plugins,
        runtime_deps = runtime_deps,
        data = data,
        resources = resources,
        resource_strip_prefix = resource_strip_prefix,
        scalacopts = scalacopts,
        javacopts = javacopts,
        jvm_flags = jvm_flags,
        print_compile_time = print_compile_time,
        visibility = visibility,
        exports = exports)
    ts.append(n)
  scala_library(
      name = name, deps = ts, exports = exports + ts, visibility = visibility)

_scala_junit_test_attrs = {
    "prefixes": attr.string_list(default = []),
    "suffixes": attr.string_list(default = []),
    "suite_label": attr.label(
        default = Label(
            "//src/java/io/bazel/rulesscala/test_discovery:test_discovery")),
    "suite_class": attr.string(
        default = "io.bazel.rulesscala.test_discovery.DiscoveredTestSuite"),
    "print_discovered_classes": attr.bool(default = False, mandatory = False),
    "_junit": attr.label(
        default = Label(
            "//external:io_bazel_rules_scala/dependency/junit/junit")),
    "_hamcrest": attr.label(
        default = Label(
            "//external:io_bazel_rules_scala/dependency/hamcrest/hamcrest_core")
    ),
    "_bazel_test_runner": attr.label(
        default = Label("@bazel_tools//tools/jdk:TestRunner_deploy.jar"),
        allow_files = True),
}
_scala_junit_test_attrs.update(_launcher_template)
_scala_junit_test_attrs.update(_implicit_deps)
_scala_junit_test_attrs.update(scala_deps)
_scala_junit_test_attrs.update(_common_attrs)
_scala_junit_test_attrs.update(_junit_resolve_deps)
scala_junit_test = rule(
    implementation = _scala_junit_test_impl,
    attrs = _scala_junit_test_attrs,
    outputs = _common_outputs,
    test = True,
    fragments = ["java"],
    toolchains = ['@io_bazel_rules_scala//scala:toolchain_type'])

def scala_specs2_junit_test(name, **kwargs):
  scala_junit_test(
      name = name,
      deps = _specs2_junit_dependencies() + kwargs.pop("deps", []),
      suite_label = Label(
          "//src/java/io/bazel/rulesscala/specs2:specs2_test_discovery"),
      suite_class = "io.bazel.rulesscala.specs2.Specs2DiscoveredTestSuite",
      **kwargs)
