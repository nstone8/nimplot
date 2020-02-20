import os
import osproc
import streams
import strutils

type
  ImproperInputError=object of CatchableError
  NoGnuPlotError=object of CatchableError
  
type
  Plotter= ref object
    process:Process
    input:Stream
  PlotData = ref object
    file:string

proc sendCommand(p:Plotter,cmd:string) =
  p.input.writeLine(cmd)
  p.input.flush
  
proc toFloat(x:float):float = x
    
proc newPlotter*():Plotter =
  var gnuplot = ""
  for path in getEnv("PATH").split(":"):
    if joinPath(path,"gnuplot").existsFile:
      gnuplot=joinPath(path,"gnuplot")
      break
  if gnuplot=="":
    raise newException(NoGnuPlotError,"gnuplot cannot be found on your system")
  let process=startProcess(gnuplot)
  result.new(proc(a:Plotter) =
    a.process.close())
  let input=process.inputStream
  result.process=process
  result.input=input

proc close(p:Plotter) =
  p.process.close
    
proc newPlotData[T:SomeNumber](data:seq[(seq[T],seq[T])]):PlotData =
  var allSeries:seq[(seq[float],seq[float])]
  allSeries.newSeq(data.len)
  for i in 0..<data.len:
    if data[i][0].len != data[i][1].len:
      raise newException(ImproperInputError,"X data and Y data must be of the same length")
    var
      datalen=data[i][0].len
      newXData:seq[float]
      newYData:seq[float]
    newXData.newSeq(datalen)
    newYData.newSeq(datalen)
    for j in data[i][0]:
      newXData.add(j.toFloat)
    for k in data[i][1]:
      newYData.add(k.toFloat)
    allSeries[i]=(newXData,newYData)  
  
  var filename="nim-gnuplot.dat"
  var num=1
  while filename.existsFile:
    filename="nim-gnuplot-" & ($num) & ".dat"
    num=num+1

  let myFile=filename.open(fmWrite)
  for series in allSeries:
    for i in 0..<series[0].len:
      myFile.writeLine($(series[0][i]) & "\t" & $(series[1][i]))
    myFile.writeLine("")
      
  result.new(proc(self:PlotData) =
    self.file.removeFile)
  result.file=filename

  myFile.close

proc scatter*[T:SomeNumber](p:Plotter,data:varargs[(seq[T],seq[T])]) =
  var toPass:seq[(seq[T],seq[T])] = @[]
  for d in data:
    toPass.add(d)
  var pd=newPlotData(toPass)
  p.sendCommand("plot "&"\""&pd.file&"\"")
  
proc linspace*(first:float,last:float,numPoints:int):seq[float] =
  let slope=(last-first)/(numPoints.toFloat-1)
  for i in 0..<numPoints:
    result.add(first+(slope*i.toFloat))
    
