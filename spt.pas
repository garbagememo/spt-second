program sppthread;    
{$mode objfpc}
{$modeswitch advancedrecords}


uses
   {$ifdef unix}
   cthreads,cmem,
   {$endif}
   SysUtils,Classes,Math,uVect,uBMP,getopts,uShape,uRadiance,uScene;

const
   MaxThread=32;
var
   BMP:BMPrecord;

type

   //スタックサイズが不定を嫌ってdynamic arrayは使わない
   LineArray=array[0..255*255] of rgbColor;

   TMyThread = class(TThread)
      wide,hight,samps:integer;//render option
      y,yInc:integer;
      Line:LineArray;
      cam:CamRecord;
      procedure Execute; override;
      procedure AddAxis;
   end;


procedure TMyThread.Execute;
var
   x,sx,sy,s:integer;
   r,tColor:Vec3;
begin
   while y<hight do begin
      if y mod 10 =0 then writeln('y=',y);
      for x:= 0 to wide - 1 do begin
         tColor:=ZeroVec;
         for sy := 0 to 1 do begin
            for sx := 0 to 1 do begin
               r:=ZeroVec;
               for s := 0 to sc.cam.samps - 1 do begin
                  r:= r+sc.Radiance(sc.cam.GetRay(x,y,sx,sy), 0)/ sc.cam.samps;
               end;(*samps*)
               tColor:=tColor+ ClampVector(r)* 0.25;
            end;(*sx*)
         end;(*sy*)
         Line[x]:=ColToRGB(tColor);
      end;(* for x *)
      Synchronize(@AddAxis);
   end;(*for y*)
end;

procedure TMyThread.AddAxis;
var
   j:integer;
   yAxis:integer;
begin
   yAxis:=hight-y-1;
   for j:=0 to wide-1 do BMP.SetPixel(j,yAxis,line[j]);
   y:=y+yInc;
end;
  
  
var
   i: integer;
   w,h,samps: integer;
   modelnum,threadnum:integer;
   AspectFlag:boolean;//trueの場合16:9
   ArgInt:integer;
   FN,ArgFN:string;
   c:char;
   StarTime:TDateTime;
var
   ThreadAry:array[0..MaxThread-1] of TMyThread;
begin
   
   ThreadNum:=8;
   modelnum:=0;
   FN:='out.png';
   w:=640 ;h:=480;
   //w:=1920;h:=1080;
   samps := 16;
   AspectFlag:=false;
   c:=#0;
   repeat
      c:=getopt('am:o:s:t:w:');
      case c of
         'a':begin
                AspectFlag:=true;
             end;
         'm' : begin
                  ArgInt:=StrToInt(OptArg);
                  modelnum:=ArgInt;
                  writeln ('model number=',ModelNum);
               end;
         'o' : begin
                  ArgFN:=OptArg;
                  if ArgFN<>'' then FN:=ArgFN;
                  writeln ('Output FileName =',FN);
               end;
         's' : begin
                  ArgInt:=StrToInt(OptArg);
                  samps:=ArgInt;
                  writeln('samples =',ArgInt);
               end;
         't' : begin
                  ArgInt:=StrToInt(OptArg);
                  ThreadNum:=ArgInt;
                  if ThreadNum>=MaxThread then Threadnum:=MaxThread;
                  writeln('Thread Number =',ThreadNum);
               end;
         'w' : begin
                  ArgInt:=StrToInt(OptArg);
                  w:=ArgInt;h:=w *3 div 4;
                  writeln('w=',w,' ,h=',h);
               end;
         '?',':' : begin
                      writeln(' -m [0..7,10,11,20,30] scene number');
                      writeln(' -o [finename] output filename');
                      writeln(' -s [samps] sampling count');
                      writeln(' -t [thread num]');
                      writeln(' -w [width] screen width pixel');
                      halt;
                   end;
      end; { case }
   until c=endofoptions;

   if AspectFlag then begin
      h:=w*9 div 16;
   end;
   writeln('samps=',samps);
   writeln('size=',w,'x',h);
   writeln('model=',modelnum);
   writeln('threads=',threadnum);
   writeln('output=',FN);
   BMP.new(w,h);
   sc.new(w,h,samps);

   Randomize;

   case modelnum of
      60: SkyBunnyScene(sc.scList);
      50: bunnyScene(sc.scList);
      40: TeapotScene(sc.scList);
      30: InitObjScene(sc.scList);
      20: bvhRandomScene(sc.scList);
      11: EvenlySpiralScene(sc.scList);
      10: SpiralScene(sc.scList);
      6:  IslandScene(sc.ScList);
      5:  RandomScene(sc.scList);
      4:  WadaScene(sc.scList);
      3:  ForestScene(sc.scList);
      2:  SkyScene(sc.scList);
      1:  InitNEScene(sc.scList);
   else
      InitScene(sc.scList);
   end;(*case*)

   writeln ('The time is : ',TimeToStr(Time));
   StarTime:=Time; 

   for i:=0 to ThreadNum-1 do begin
      ThreadAry[i]:=TMyThread.Create(true);
      ThreadAry[i].FreeOnTerminate:=false;
      //falseにしないとスレッドが休止時の後始末ができない。
      ThreadAry[i].y:=i;
      ThreadAry[i].wide:=sc.cam.w;
      ThreadAry[i].hight:=sc.cam.h;
      ThreadAry[i].cam:=sc.cam;
      ThreadAry[i].samps:=sc.cam.samps;
      ThreadAry[i].yInc:=ThreadNum;
   end;
   writeln('Setup!');
   
   for i:=0 to ThreadNum-1 do begin
      ThreadAry[i].Start;
   end;
   //このルーチンが別途で無いとマルチスレッドにならない
   for i:=0 to ThreadNum-1 do begin
      ThreadAry[i].WaitFor;
   end;
   writeln('The time is : ',TimeToStr(Time));
   writeln('Calcurate time is=',TimeToStr(Time-StarTime));
   if UpperCase(ExtractFileExt(FN))='.BMP' then
      BMP.WriteBMPFile(FN)
   else if UpperCase(ExtractFileExt(FN))='.PNG' then
      BMP.WritePNG(FN)
   else
      BMP.WritePPM(FN);
end.
  
