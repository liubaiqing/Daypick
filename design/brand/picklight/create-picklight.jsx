#target illustrator
// Illustrator-native concept 02. Writes only assets next to this script.
(function () {
  var root = new File($.fileName).parent;
  function color(hex) {
    var c = new RGBColor();
    c.red = parseInt(hex.substr(0,2),16);
    c.green = parseInt(hex.substr(2,2),16);
    c.blue = parseInt(hex.substr(4,2),16);
    return c;
  }
  function layer(d, name) { var l=d.layers.add(); l.name=name; return l; }
  // One smooth cubic stroke with round caps: anchor / incoming / outgoing.
  var arc = [
    [[208,568],[208,568],[366,816]],
    [[817,406],[701,785],[817,406]]
  ];
  function draw(d,H,x,y,size,ls,mono) {
    var s=size/1024;
    function xy(a){return [x+a[0]*s,H-y-a[1]*s];}
    var a=ls[0].pathItems.add(); a.name='拾光弧 — upward cradle';
    a.closed=false;a.filled=false;a.stroked=true;
    a.strokeColor=color(mono || '5687A0');a.strokeWidth=92*s;
    a.strokeCap=StrokeCap.ROUNDENDCAP;
    for(var i=0;i<arc.length;i++){
      var p=a.pathPoints.add();p.anchor=xy(arc[i][0]);
      p.leftDirection=xy(arc[i][1]);p.rightDirection=xy(arc[i][2]);
      p.pointType=PointType.CORNER;
    }
    var sun=ls[1].pathItems.ellipse(H-y-150*s,x+336*s,270*s,270*s);
    sun.name='日光 — floating sun';sun.stroked=false;sun.fillColor=color(mono || 'EDB363');
  }
  function png(d,name){var o=new ExportOptionsPNG24();o.transparency=true;o.antiAliasing=true;o.artBoardClipping=true;o.horizontalScale=100;o.verticalScale=100;d.exportFile(new File(root+'/'+name),ExportType.PNG24,o);}
  var d=app.documents.add(DocumentColorSpace.RGB,1024,1024);
  d.layers[0].name='预览背景（隐藏）';d.layers[0].visible=false;
  draw(d,1024,0,0,1024,[layer(d,'拾光弧'),layer(d,'圆日')]);
  var ai=new IllustratorSaveOptions();ai.pdfCompatible=true;ai.compressed=true;
  d.saveAs(new File(root+'/daypick-picklight.ai'),ai);
  var svg=new ExportOptionsSVG();svg.coordinatePrecision=3;svg.embedRasterImages=false;
  d.exportFile(new File(root+'/daypick-picklight'),ExportType.SVG,svg);
  png(d,'daypick-picklight-1024');
  var p=app.documents.add(DocumentColorSpace.RGB,1600,1080);
  var back=p.layers[0];back.name='Backgrounds';
  var ls=[layer(p,'拾光弧'),layer(p,'圆日')],labels=layer(p,'Labels');
  function rect(x,y,w,h,c){var r=back.pathItems.rectangle(1080-y,x,w,h);r.stroked=false;r.fillColor=color(c);}
  function text(t,x,y,size,c){var a=labels.textFrames.add();a.contents=t;a.position=[x,1080-y];a.textRange.characterAttributes.size=size;a.textRange.characterAttributes.fillColor=color(c);try{a.textRange.characterAttributes.textFont=app.textFonts.getByName('ArialMT');}catch(e){}}
  rect(0,0,1600,1080,'F7F8F6');
  text('Daypick',64,44,34,'223440');
  text('PICKING UP THE DAY   /   CONCEPT 02',65,95,13,'6E7F87');
  rect(48,154,742,590,'FFFFFF');rect(810,154,742,590,'223440');
  draw(p,1080,147,154,544,ls);draw(p,1080,909,154,544,ls);
  text('PICKLIGHT / FLAT SILHOUETTE',78,707,12,'6E7F87');
  text('DARK BACKGROUND',840,707,12,'BFCDD4');
  text('ACTUAL PIXEL SIZES',65,796,12,'6E7F87');
  var ss=[16,24,32,48,128],xx=[80,180,300,440,600];
  for(var i=0;i<ss.length;i++){text(ss[i]+' px',xx[i],838,12,'6E7F87');draw(p,1080,xx[i],875,ss[i],ls);}
  text('ONE-COLOUR CHECK',868,796,12,'6E7F87');draw(p,1080,865,844,176,ls,'223440');
  text('MIST BLUE',1150,832,12,'6E7F87');rect(1150,864,44,44,'5687A0');text('#5687A0',1215,876,15,'223440');
  text('WARM DAYLIGHT',1150,936,12,'6E7F87');rect(1150,968,44,44,'EDB363');text('#EDB363',1215,980,15,'223440');
  png(p,'daypick-picklight-preview');
  p.close(SaveOptions.DONOTSAVECHANGES);d.close(SaveOptions.DONOTSAVECHANGES);
  d=app.open(new File(root+'/daypick-picklight.ai'));d.selection=null;app.executeMenuCommand('fitin');
})();
