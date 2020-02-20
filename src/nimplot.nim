import os
import osproc
import streams
import strutils

const defaultColors=[
    "#1f77b4",  # muted blue
    "#ff7f0e",  # safety orange
    "#2ca02c",  # cooked asparagus green
    "#d62728",  # brick red
    "#9467bd",  # muted purple
    "#8c564b",  # chestnut brown
    "#e377c2",  # raspberry yogurt pink
    "#7f7f7f",  # middle gray
    "#bcbd22",  # curry yellow-green
    "#17becf"   # blue-teal
]

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
    
proc newPlotData(data:seq[(seq[float],seq[float])]):PlotData =
  for i in 0..<data.len:
    if data[i][0].len != data[i][1].len:
      raise newException(ImproperInputError,"X data and Y data must be of the same length")
  
  var filename="nim-gnuplot.dat"

  let myFile=filename.open(fmWrite)
  for series in data:
    for i in 0..<series[0].len:
      myFile.writeLine($(series[0][i]) & "\t" & $(series[1][i]))
    myFile.writeLine("\n")
      
  result.new()
  result.file=filename

  myFile.close

proc plotWrapper(p:Plotter,data:openArray[(seq[float],seq[float])],typeCommand:string) =
  var toPass:seq[(seq[float],seq[float])] = @[]
  for d in data:
    toPass.add(d)
  var
    pd=newPlotData(toPass)
    commands="plot"
  for i in 1..toPass.len:
    let colorIndex=(i-1) mod defaultColors.len
    p.sendCommand("set style line " & $i & " linecolor rgb " & "\"" & defaultColors[colorIndex] & "\"" & " ")
    commands=commands & " \"" & pd.file&"\" index " & $(i-1) & " with " & typeCommand & " linestyle " & $i & ","
  commands=commands[0 .. ^2]
  p.sendCommand(commands)

proc scatter*(p:Plotter,data:openArray[(seq[float],seq[float])]) =
  plotWrapper(p,data,"points")
  
proc linspace*(first:float,last:float,numPoints:int):seq[float] =
  let slope=(last-first)/(numPoints.toFloat-1)
  for i in 0..<numPoints:
    result.add(first+(slope*i.toFloat))
    
