import coursier.maven.MavenRepository

import scala.util.{Failure, Try}
interp.repositories() ++= Seq(
  MavenRepository("https://dl.bintray.com/comp-bio-aging/main/")
)
@
import $ivy.`com.github.pathikrit::better-files:3.4.0`
import $ivy.`com.nrinaudo::kantan.csv:0.5.0`
import $ivy.`com.nrinaudo::kantan.csv-generic:0.5.0`
import $ivy.`group.aging-research::geo-fetch:0.0.3`
import $ivy.`io.circe::circe-optics:0.11.0`
import $ivy.`io.circe::circe-parser:0.11.0`
println("Script dependencies loaded!")