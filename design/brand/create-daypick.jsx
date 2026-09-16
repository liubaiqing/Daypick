// Run in Adobe Illustrator: File > Scripts > Other Script.
// Native editable paths only; no tracing, embedded bitmap or external services.
#target illustrator
(function () {
  var root = new File($.fileName).parent;
  function rgb(h) { var c = new RGBColor(); c.red=parseInt(h.substr(0,2),16); c.green=parseInt(h.substr(2,2),16); c.blue=parseInt(h.substr(4,2),16); return c; }
  function layer(d,n) { var l=d.layers.add(); l.name=n; return l; }
  function gradient(d,n,colors) { var g=d.gradients.add(); g.name=n+' '+d.gradients.length; g.type=GradientType.LINEAR; while(g.gradientStops.length<colors.length)g.gradientStops.add(); for(var i=0;i<colors.length;i++){g.gradientStops[i].rampPoint=i*100/(colors.length-1);g.gradientStops[i].color=rgb(colors[i]);}return g; }
  function fill(g,x,y,s,H){var c=new GradientColor();c.gradient=g;c.origin=[x+160*s,H-y-160*s];c.length=850*s;c.matrix=app.getRotationMatrix(-45);return c;}
  // Each node: anchor, incoming handle, outgoing handle (top-left design coordinates).
  var outer=[
    [[224,112],[162,112],[224,112]],
    [[438,112],[438,112],[702,112]],
    [[904,512],[904,270],[904,754]],
    [[438,912],[702,912],[438,912]],
    [[224,912],[224,912],[162,912]],
    [[112,800],[112,862],[112,800]],
    [[112,224],[112,224],[112,162]]
  ];
  var inner=[
    [[320,320],[320,320],[320,320]],
    [[320,704],[320,704],[320,704]],
    [[438,704],[438,704],[598,704]],
    [[696,512],[696,636],[696,388]],
    [[438,320],[598,320],[438,320]]
  ];
  function path(parent,nodes,x,y,s,H){var p=parent.pathItems.add();p.closed=true;p.stroked=false;for(var i=0;i<nodes.length;i++){var q=p.pathPoints.add();function xy(a){return[x+a[0]*s,H-y-a[1]*s];}q.anchor=xy(nodes[i][0]);q.leftDirection=xy(nodes[i][1]);q.rightDirection=xy(nodes[i][2]);q.pointType=PointType.CORNER;}return p;}
  function draw(d,H,x,y,size,simple,ls){var s=size/1024;var b=ls[0].compoundPathItems.add();b.name='D — continuous rounded silhouette';var p=path(b,outer,x,y,s,H);path(b,inner,x,y,s,H);var blue=gradient(d,'Mist blue '+size,['B9D3E7','729ABC','486D91']);p.fillColor=simple?rgb('729ABC'):fill(blue,x,y,s,H);
    var sun=ls[1].pathItems.ellipse(H-y-350*s,x+398*s,220*s,220*s);sun.name='Day — lifted sunlight';sun.stroked=false;var gold=gradient(d,'Daylight '+size,['FFE1A2','F3BE70','E7A756']);var gc=new GradientColor();gc.gradient=gold;gc.origin=[x+425*s,H-y-370*s];gc.length=260*s;gc.matrix=app.getRotationMatrix(-45);sun.fillColor=simple?rgb('F3BE70'):gc;
    if(!simple){b.rotate(-45,false,false,true,false,Transformation.CENTER);sun.rotate(-45,false,false,true,false,Transformation.CENTER);var shine=path(ls[2],[ [[170,260],[170,260],[170,190]], [[252,168],[197,168],[300,168]], [[446,168],[380,168],[620,168]], [[698,246],[612,182],[615,203]], [[446,195],[580,195],[380,195]], [[252,195],[300,195],[208,195]], [[170,300],[170,250],[170,300]] ],x,y,s,H);shine.name='Soft upper-left reflection';shine.fillColor=rgb('E5F0F7');shine.opacity=9;}
  }
  function png(d,name){var o=new ExportOptionsPNG24();o.transparency=true;o.antiAliasing=true;o.artBoardClipping=true;o.horizontalScale=100;o.verticalScale=100;d.exportFile(new File(root+'/'+name),ExportType.PNG24,o);}
  var d=app.documents.add(DocumentColorSpace.RGB,1024,1024);d.name='Daypick — D and daylight';
  var bg=d.layers[0];bg.name='预览背景（不参与导出）';bg.visible=false;
  var body=layer(d,'D 主体'),sun=layer(d,'圆日'),light=layer(d,'高光与暗部');draw(d,1024,0,0,1024,false,[body,sun,light]);
  var ai=new IllustratorSaveOptions();ai.pdfCompatible=true;ai.compressed=true;d.saveAs(new File(root+'/daypick-icon.ai'),ai);
  var svg=new ExportOptionsSVG();svg.coordinatePrecision=3;svg.embedRasterImages=false;d.exportFile(new File(root+'/daypick-icon'),ExportType.SVG,svg);png(d,'daypick-icon-1024');
  var p=app.documents.add(DocumentColorSpace.RGB,1600,1060);p.name='Daypick — preview';var back=p.layers[0];back.name='Preview backgrounds';var pl=[layer(p,'D 主体'),layer(p,'圆日'),layer(p,'高光与暗部')];var tx=layer(p,'Labels');
  function rect(x,y,w,h,color){var a=back.pathItems.rectangle(1060-y,x,w,h);a.stroked=false;a.fillColor=rgb(color);return a;}
  function text(t,x,y,size,color){var a=tx.textFrames.add();a.contents=t;a.position=[x,1060-y];a.textRange.characterAttributes.size=size;a.textRange.characterAttributes.fillColor=rgb(color);try{a.textRange.characterAttributes.textFont=app.textFonts.getByName('ArialMT');}catch(e){}return a;}
  rect(0,0,1600,1060,'F3F6FA');text('Daypick',64,48,34,'1B2430');text('D + DAYLIGHT   /   ICON STUDY 01',65,99,13,'667487');
  rect(48,154,488,480,'FFFFFF');rect(556,154,488,480,'202B3A');var env=rect(1064,154,488,480,'DCEBFA');env.fillColor=fill(gradient(p,'App atmosphere',['BEDDF3','E2DCF2','D6EEE6']),1064,154,.55,1060);
  draw(p,1060,96,177,392,false,pl);draw(p,1060,604,177,392,false,pl);draw(p,1060,1112,177,392,false,pl);
  text('LIGHT',74,597,12,'667487');text('DARK',582,597,12,'C3D1DF');text('APP ATMOSPHERE',1090,597,12,'667487');
  text('ACTUAL PIXEL SIZES',65,687,13,'667487');var sizes=[16,24,32,48,256],xs=[84,210,348,498,740];for(var i=0;i<sizes.length;i++){draw(p,1060,xs[i],755,sizes[i],sizes[i]<=32,pl);text(String(sizes[i])+' px',xs[i],724,12,'667487');}text('Small sizes: simplified lighting, same silhouette.',64,1020,13,'667487');
  text('MIST BLUE',1160,738,12,'667487');rect(1160,776,64,64,'729ABC');text('#729ABC',1245,796,16,'1B2430');text('DAYLIGHT',1160,880,12,'667487');rect(1160,918,64,64,'F3BE70');text('#F3BE70',1245,938,16,'1B2430');
  png(p,'daypick-icon-preview');p.close(SaveOptions.DONOTSAVECHANGES);
  d.close(SaveOptions.DONOTSAVECHANGES);d=app.open(new File(root+'/daypick-icon.ai'));d.selection=null;app.executeMenuCommand('fitin');
})();
