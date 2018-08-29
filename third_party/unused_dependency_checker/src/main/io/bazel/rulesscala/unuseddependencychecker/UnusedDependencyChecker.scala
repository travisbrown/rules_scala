package third_party.unused_dependency_checker.src.main.io.bazel.rulesscala.unused_dependency_checker

import scala.reflect.io.AbstractFile
import scala.tools.nsc.plugins.{Plugin, PluginComponent}
import scala.tools.nsc.{Global, Phase}
import UnusedDependencyChecker._

class UnusedDependencyChecker(val global: Global) extends Plugin { self =>
  val name = "unused-dependency-checker"
  val description = "Errors if there exists dependencies that are not used"

  val components: List[PluginComponent] = List[PluginComponent](Component)

  var direct: Map[String, String] = Map.empty
  var ignoredTargets: Set[String] = Set.empty
  var analyzerMode: AnalyzerMode = Error
  var currentTarget: String = "NA"

  override def init(options: List[String], error: (String) => Unit): Boolean = {
    var directJars: Seq[String] = Seq.empty
    var directTargets: Seq[String] = Seq.empty

    for (option <- options) {
      option.split(":").toList match {
        case "direct-jars" :: data => directJars = data.map(decodeTarget)
        case "direct-targets" :: data => directTargets = data.map(decodeTarget)
        case "ignored-targets" :: data => ignoredTargets = data.map(decodeTarget).toSet
        case "current-target" :: target :: _ => currentTarget = decodeTarget(target)
        case "mode" :: mode :: _ => parseAnalyzerMode(mode).foreach(analyzerMode = _)
        case unknown :: _ => error(s"unknown param $unknown")
        case Nil =>
      }
    }

    direct = directJars.zip(directTargets).toMap

    true
  }


  private object Component extends PluginComponent {
    val global: Global = self.global

    import global._

    override val runsAfter = List("jvm")

    val phaseName: String = self.name

    private def warnOrError(messages: Set[String]): Unit = {
      val reportFunction: String => Unit = analyzerMode match {
        case Error => reporter.error(NoPosition, _)
        case Warn => reporter.warning(NoPosition, _)
      }

      messages.foreach(reportFunction)
    }

    override def newPhase(prev: Phase): StdPhase = new StdPhase(prev) {
      override def run(): Unit = {
        super.run()

        warnOrError(unusedDependenciesFound)
      }

      private def unusedDependenciesFound: Set[String] = {
        val usedJars: Set[AbstractFile] = findUsedJars
        usedJars.foreach(println)
        val directJarPaths = direct.keys.toSet
        val usedJarPaths = usedJars.map(_.path)

        val usedTargets = usedJarPaths
          .map(direct.get)
          .collect {
            case Some(target) => target
          }

        val unusedTargets = directJarPaths
          .filter(jar => !usedTargets.contains(direct(jar)))
          .map(direct.get)
          .collect {
            case Some(target) if !ignoredTargets.contains(target) => target
          }

        unusedTargets.map { target =>
          s"""Target '$target' is specified as a dependency to $currentTarget but isn't used, please remove it from the deps.
             |You can use the following buildozer command:
             |buildozer 'remove deps $target' $currentTarget
             |""".stripMargin
        }
      }

      override def apply(unit: CompilationUnit): Unit = ()
    }

    def findUsedJars: Set[AbstractFile] = {
      val jars = collection.mutable.Set[AbstractFile]()

      def walkTopLevels(root: Symbol): Unit = {
        println(s"  sym: $root")
        def safeInfo(sym: Symbol): Type =
          if (sym.hasRawInfo && sym.rawInfo.isComplete) sym.info else NoType

        def packageClassOrSelf(sym: Symbol): Symbol =
          if (sym.hasPackageFlag && !sym.isModuleClass) sym.moduleClass else sym

        for (x <- safeInfo(packageClassOrSelf(root)).decls) {
          print(s"    decl: $x")
          if (x == root) { println(" (root)"); () }
          else if (x.hasPackageFlag) { println(" (rec)"); walkTopLevels(x) }
          else if (x.owner != root) { // exclude package class members
            print(s" (!own) ${x.hasRawInfo.toString} ${ if (x.hasRawInfo) x.rawInfo.isComplete.toString else 0.toString }")
            if (x.hasRawInfo && x.rawInfo.isComplete) {
              val assocFile = x.associatedFile
              println(s"      file: $assocFile")
              if (assocFile.path.endsWith(".class") && assocFile.underlyingSource.isDefined)
                assocFile.underlyingSource.foreach(jars += _)
            } else {
              println
            }
          }
        }
      }

      exitingTyper {
        walkTopLevels(RootClass)
      }
      jars.toSet
    }
  }

}

object UnusedDependencyChecker {

  sealed trait AnalyzerMode

  case object Error extends AnalyzerMode

  case object Warn extends AnalyzerMode

  def parseAnalyzerMode(mode: String): Option[AnalyzerMode] = mode match {
    case "error" => Some(Error)
    case "warn" => Some(Warn)
    case _ => None
  }

  def decodeTarget(target: String): String = target.replace(";", ":")
}
