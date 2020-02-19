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
    x:seq[float]
    y:seq[float]
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
    
proc newPlotData(x:openArray[SomeNumber],y:openArray[SomeNumber]):PlotData =
  if x.len != y.len:
    raise newException(ImproperInputError,"X data and Y data must be of the same length")
  var xData:seq[float]
  var yData:seq[float]
  xData.newSeq(x.len)
  yData.newSeq(y.len)
  for i in 0..<x.len:
    xData[i]=x[i].toFloat
    yData[i]=y[i].toFloat

  var filename="nim-gnuplot.dat"
  var num=1
  while filename.existsFile:
    filename="nim-gnuplot-" & ($num) & ".dat"
    num=num+1
  result.new(proc(self:PlotData) =
    self.file.removeFile)
  result.x=xData
  result.y=yData
  result.file=filename
  let myFile=filename.open(fmWrite)
  for i in 0..<x.len:
    myFile.writeLine($(x[i]) & "\t" & $(y[i]))
  myFile.close

proc scatter*(p:Plotter,x:openArray[SomeNumber],y:openArray[SomeNumber]) =
  var pd=newPlotData(x,y)
  p.sendCommand("plot "&"\""&pd.file&"\"")
  
proc linspace*(first:float,last:float,numPoints:int):seq[float] =
  let slope=(last-first)/(numPoints.toFloat-1)
  for i in 0..<numPoints:
    result.add(first+(slope*i.toFloat))
    
