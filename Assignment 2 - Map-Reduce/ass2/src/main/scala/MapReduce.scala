/* MapReduce.scala - Assignment 2 for COEN 424*/

import org.apache.spark.sql.SQLContext
import org.apache.spark.SparkContext
import org.apache.spark.SparkContext._
import org.apache.spark.SparkConf

import org.apache.spark.sql.types._                         // include the Spark Types to define our schema
import org.apache.spark.sql.functions._                     // include the Spark helper functions
import org.apache.spark.sql.Column

import org.apache.commons.io.FileUtils;
import java.io._
import scala.util.Try

object MapReduce {

  def main(args: Array[String]) {

    Try {
    FileUtils.deleteDirectory(new File("./results.csv"))
    }

    val csvFile = "nms_airborne_radioactivity_ssn_radioactivite_dans_air.csv"

    val conf = new SparkConf().setMaster(args(0))
      .setAppName("COEN 424 - Assignment 2")
      .set("spark.local.dir", "/tmp/spark-temp")

    val sc = new SparkContext(conf)

    val sqlContext = new SQLContext(sc)	

    val full_csv = sqlContext.read
      .format("com.databricks.spark.csv")
      .option("header", "true") // Use first line of all files as header
      .option("inferSchema", "true") // Automatically infer data types (otherwise everything is assumed string)
      .load(csvFile)


    val data = full_csv.select("Location/Emplacement", 
                                  "Collection Start/Debut du prelevement (UTC)",
                                  "7Be MDC/7Be CMD (mBq/m3)")

    val newNames = Seq("location", "date", "mdc")
    val df = data.toDF(newNames: _*).withColumn("year", substring_index(col("date"), "/", -1))
    val df_copy = df

    val mapping: Map[String, Column => Column] = Map(
      "min" -> min, "max" -> max, "mean" -> avg, "stddev" -> stddev)

    val groupBy = Seq("location", "year")
    val aggregate = Seq("mdc")
    val operations = Seq("min", "max", "mean", "stddev")
    val exprs = aggregate.flatMap(c => operations .map(f => mapping(f)(col(c))))

    df_copy.registerTempTable("df_copy")
    var median =  sqlContext.sql("select location, year, percentile_approx(mdc, 0.5) as median from df_copy group by location, year")
    
    val results = df.groupBy(groupBy.map(col): _*).agg(exprs.head, exprs.tail: _*)

    val end_result = results.join(median, Seq("location", "year"), joinType="outer")

    end_result.show()

    end_result.repartition(1).select("location", "year", "min(mdc)", "max(mdc)", "avg(mdc)", "stddev_samp(mdc)", "median")
                          .write.format("com.databricks.spark.csv")
                          .option("header", "true")
                          .save("results.csv")


    sc.stop()

  }
}