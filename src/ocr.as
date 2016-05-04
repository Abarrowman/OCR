//constants
var green:uint=0xff00ff00;
var white:uint=0xffffffff;
var black:uint=0xff000000;
var displayScale:Number=2;
var colors:Vector.<uint>=Vector.<uint>([
0xff0000,
0x00ff00,
0x0000ff,
0xffff00,
0xff00ff,
0x00ffff
]);

var glyphBitmap:BitmapData;
var dict:Dictionary = new Dictionary();
var currentColor:int=0;
var select:Rectangle=null;
var lineTop:int=0;
var lineBot:int=0;
var lineHeight:int=0;
var message:String="";
var auto:String=null;

var oldMessage:String;
var oldDict:Dictionary;
var oldSelect:Rectangle;
var oldLineTop:int=0;
var oldLineBot:int=0;
var oldLineHeight:int=0;
var oldGlyphBitmap:BitmapData;


var debug:Boolean=false;
var data:BitmapData=new BitmapData(10,10);
var bit:Bitmap=new Bitmap(data);
bit.scaleX=bit.scaleY=displayScale;
var sprite:Sprite=new Sprite();
sprite.scaleX=sprite.scaleY=displayScale;

addChild(bit);
addChild(sprite);
go.addEventListener(MouseEvent.CLICK, goFunc);
current.addEventListener(KeyboardEvent.KEY_DOWN, currentFunc);
undo.addEventListener(MouseEvent.CLICK, undoFunc);
addEventListener(Event.ENTER_FRAME, autoFunc);
setup();

function autoFunc(event:Event):void {
	if (auto!=null) {
		//trace("~"+auto);
		sprite.graphics.clear();
		setMessage(message+auto);
		go.enabled=true;
		auto=null;
		findNextGlyph();
	}
}

function currentFunc(event:KeyboardEvent):void {
	if (event.keyCode==Keyboard.ENTER) {
		goFunc();
	}
}

function undoFunc(...rest):void {
	if (oldDict!=null) {
		lineTop=oldLineTop;
		lineBot=oldLineBot;
		lineHeight=oldLineHeight;
		glyphBitmap=oldGlyphBitmap;
		setMessage(oldMessage);
		dict=oldDict;
		setSelect(oldSelect);
		undo.enabled=false;
		go.enabled=true;
		stage.focus=current;
	}
}

function goFunc(...rest):void {
	if (current.text.length!=0) {
		oldMessage=message;

		oldLineTop=lineTop;
		oldLineBot=lineBot;
		oldLineHeight=lineHeight;
		oldDict=new Dictionary();
		oldGlyphBitmap=glyphBitmap;
		oldSelect=select;
		for (var k:Object in dict) {
			var val:Object=dict[k];
			if ((val is Vector.<BitmapData>)&&(k is String)) {
				var key:String=k as String;
				//trace(key);
				var value:Vector.<BitmapData>=val as Vector.<BitmapData>;
				var valueCopy:Vector.<BitmapData>=new Vector.<BitmapData>();
				for (var n:int=0; n<value.length; n++) {
					valueCopy.push(value[n]);
				}
				oldDict[key]=valueCopy;
			}
		}

		

		var glyphChars:String=current.text;
		//trace(glyphChars);

		/*
		var tinyBitmap:Bitmap=new Bitmap(glyphBitmap);
		tinyBitmap.x=(stage.stageWidth-glyphBitmap.width)/2;
		tinyBitmap.y=(stage.stageHeight-glyphBitmap.height)/2;
		addChild(tinyBitmap);
		*/

		var glyphBitmaps:Vector.<BitmapData>;
		if (dict[glyphChars]==null) {
			glyphBitmaps=Vector.<BitmapData>([glyphBitmap]);
			dict[glyphChars]=glyphBitmaps;
		} else if (dict[glyphChars] is Vector.<BitmapData>) {
			glyphBitmaps=dict[glyphChars] as Vector.<BitmapData>;
			glyphBitmaps.push(glyphBitmap);
		}
		current.text="";
		setMessage(message+glyphChars);
		stage.focus=current;
		findNextGlyph();
	}
}

function setup():void {
	data=new TestText(361,70);
	bit.bitmapData=data;
	sprite.graphics.clear();
	undo.enabled=false;
	go.enabled=true;
	select=null;
	message="";
	lineBot=0;
	lineTop=0;
	lineHeight=0;
	glyphBitmap=null;
	stage.focus=current;
	auto=null;
	oldMessage=null;
	oldDict=null;
	oldSelect=null;
	findFirstGlyph();
}

function done():void {
	//we are done
	go.enabled=false;
	/*trace("Done! The message was {");
	trace(message);
	trace("}");*/
	stage.focus=stage;
	if (message!="") {
		undo.enabled=true;
	}
}

function selectGlyph(rect:Rectangle):void {
	setSelect(rect);
	glyphBitmap=getSubBitmapData(data,select);
	glyphBitmap=getSubBitmapData(glyphBitmap,glyphBitmap.getColorBoundsRect(white,black));
	var aspectRatio:Number=glyphBitmap.width/glyphBitmap.height;
	//try to identify what this is

	var best:String=null;
	var bestScore:Number=Number.MAX_VALUE;

	for (var k:Object in dict) {
		var val:Object=dict[k];
		if ((val is Vector.<BitmapData>)&&(k is String)) {
			var key:String=k as String;
			//trace("#"+key);
			var value:Vector.<BitmapData>=val as Vector.<BitmapData>;
			for (var n:int=0; n<value.length; n++) {
				var bitData:BitmapData=value[n];
				var bitAspectRatio:Number=bitData.width/bitData.height;
				//TODO Adam do not hard code aspect ratio tolerance
				if (Math.abs(bitAspectRatio-aspectRatio)<0.2) {
					//close enough
					var tempBit:BitmapData;
					if ((bitData.width==glyphBitmap.width)&&(bitData.height==glyphBitmap.height)) {
						tempBit=bitData;
					} else {
						tempBit=new BitmapData(glyphBitmap.width,glyphBitmap.height,true);
						var matrix:Matrix=new Matrix();
						matrix.scale(glyphBitmap.width/bitData.width, glyphBitmap.height/bitData.height);
						tempBit.draw(glyphBitmap, matrix);
					}
					var res:Object=glyphBitmap.compare(tempBit);
					if (res is Number) {
						var valu:Number=res as Number;
						if (valu==0) {
							//party
							best=key;
							bestScore=0;
						}
					} else if (res is BitmapData) {
						tempBit=res as BitmapData;
						var scoreTotal:Number=0;
						var xn:int;
						var yn:int;
						var pix:uint;
						var r:int;
						var g:int;
						var b:int;
						var a:int;
						var denom:Number=tempBit.width*tempBit.height*4;
						for (xn=0; xn<tempBit.width; xn++) {
							for (yn=0; yn<tempBit.height; yn++) {
								pix=tempBit.getPixel32(xn,yn);
								a=(pix<<24)&0xff;
								r=(pix<<16)&0xff;
								g=(pix<<8)&0xff;
								b=pix&0xff;
								scoreTotal+=(r*r+g*g+b*b+a*a)/denom;
							}
						}
						if (scoreTotal<0) {
							//overflow there is no way this is the best
						} else if (scoreTotal<bestScore) {
							bestScore=scoreTotal;
							best=key;
						}
					}
				}
			}
		}
	}

	//TODO ADAM do not hard code this
	if (best!=null&&bestScore<0.001) {
		undo.enabled=false;
		if (bestScore!=0) {
			trace(best+" "+bestScore);
		}
		auto=best;
		go.enabled=false;
	} else {
		if (message!="") {
			undo.enabled=true;
		}
	}
}

function findGlyphBounds(ex:int, ey:int):Rectangle {
	var clone:BitmapData=data.clone();
	fillBitmapData(clone, ex, ey, green, 0);
	var rect:Rectangle=clone.getColorBoundsRect(white,green);
	return rect;
}

function findNextGlyph():void {
	var xn:int;
	var ex:int;
	var ey:int;
	var yn:int;
	var pix:uint;
	var startX:int=select.x+select.width+1;
	var found:Boolean=false;
	var rect:Rectangle;
	for (xn=startX; ((xn<data.width)&&(!found)); xn++) {
		for (yn=lineTop; yn<lineBot; yn++) {
			pix=data.getPixel32(xn,yn);
			//trace(xn+" "+lineMid+" "+pix+" "+black+" "+white);
			if (pix==black) {
				ex=xn;
				ey=yn;
				found=true;
			}
		}
	}

	if (found) {
		//TODO ADAM unhard code minimum size for space
		if ((ex-startX)>6) {
			setMessage(message+" ");
		}

		circlePoint(ex, ey);
		rect=findGlyphBounds(ex,ey);
		if (rect.y>lineTop) {
			rect.height+=rect.y-lineTop;
			rect.y=lineTop;
		}
		if ((rect.y+rect.height)<lineBot) {
			rect.height=lineBot-rect.y;
		}
		selectGlyph(rect);
		lineBot=Math.max(rect.y+rect.height,lineBot);
		lineTop=Math.min(rect.y,lineBot);
		lineHeight=Math.max(lineHeight,lineBot-lineTop);
	} else {
		//is there a new line of text below this one?
		var clone:BitmapData=getSubBitmapData(data, new Rectangle(0,lineBot+1, data.width, data.height-(lineBot+1)));
		boxRectangle(new Rectangle(0, lineBot+1, data.width, clone.height));

		rect=clone.getColorBoundsRect(white,black,true);
		ey=rect.y+lineBot+1;
		boxRectangle(new Rectangle(rect.x, ey, rect.width, rect.height));

		found=false;


		for (yn=ey; ((yn<data.height)&&(!found)); yn++) {
			pix=data.getPixel32(rect.x,yn);
			if (pix==black) {
				ey=yn;
				found=true;
			}
		}


		if (found) {
			setMessage(message+"\n");

			circlePoint(rect.x, ey);
			rect=findGlyphBounds(rect.x,ey);

			selectGlyph(rect);

			lineBot=ey+rect.height;
			lineTop=ey;

		} else {
			done();
		}
	}
}

function findFirstGlyph():void {
	var pix:uint;
	var ey:int;
	var found:Boolean=false;

	var rect:Rectangle=data.getColorBoundsRect(white,black,true);
	boxRectangle(rect);

	for (var yn=rect.y; ((yn<data.height)&&(!found)); yn++) {
		pix=data.getPixel32(rect.x,yn);
		if (pix==black) {
			ey=yn;
			found=true;
		}
	}

	if (found) {
		circlePoint(rect.x, yn);
		rect=findGlyphBounds(rect.x,yn);
		selectGlyph(rect);
		lineTop=rect.y;
		lineBot=rect.y+rect.height;
		lineHeight=lineBot-lineTop;
	} else {
		done();
	}
}

function getSubBitmapData(bitData:BitmapData, sourceRect:Rectangle):BitmapData {
	var clone:BitmapData=new BitmapData(sourceRect.width,sourceRect.height,true);
	clone.copyPixels(bitData, sourceRect, new Point(0,0));
	return clone;
}

function setMessage(m:String):void {
	message=m;
	old.text=message;
}

function setSelect(rect:Rectangle):void {
	boxRectangle(rect, false);
	select=rect;
}

function nextLineStyle():void {
	sprite.graphics.lineStyle(0.5,colors[currentColor]);
	currentColor=(currentColor+1)%colors.length;
}

function boxRectangle(rec:Rectangle, debugOnly:Boolean=true):void {
	if (! debug) {
		sprite.graphics.clear();
	}
	if (debug||! debugOnly) {
		nextLineStyle();
		sprite.graphics.drawRect(rec.x, rec.y, rec.width, rec.height);
	}
}

function circlePoint(px:int, py:int, debugOnly:Boolean=true):void {
	if (! debug) {
		sprite.graphics.clear();
	}
	if (debug||! debugOnly) {
		nextLineStyle();
		sprite.graphics.drawCircle(px+.5,py+.5,1.5);
	}
}

function fillBitmapData(bitData:BitmapData, cordX:int, cordY:int, setColor:uint, sense:int=32):void {
	//color being searched for
	var getColor:int=bitData.getPixel32(cordX,cordY);
	var getColorA:int=getColor>>24&0xff;
	var getColorR:int=getColor>>16&0xff;
	var getColorG:int=getColor>>8&0xff;
	var getColorB:int=getColor&0xff;

	var cords:Vector.<Point>=new Vector.<Point>();
	cords.push(new Point(cordX, cordY));
	while (cords.length>0) {
		var n:int=cords.length-1;
		var cord:Point=cords[n];
		if (checkPixelForFill(bitData,cord.x,cord.y,setColor,sense,getColor,getColorA,getColorR,getColorG,getColorB)) {

			bitData.setPixel32(cord.x, cord.y, setColor);


			cords.push(new Point(cord.x+1, cord.y));
			cords.push(new Point(cord.x-1, cord.y));
			cords.push(new Point(cord.x, cord.y+1));
			cords.push(new Point(cord.x, cord.y-1));
			cords.push(new Point(cord.x+1, cord.y+1));
			cords.push(new Point(cord.x-1, cord.y+1));
			cords.push(new Point(cord.x+1, cord.y-1));
			cords.push(new Point(cord.x-1, cord.y-1));

		}
		cords.splice(n, 1);
	}
}
function checkPixelForFill(bitData:BitmapData, cordX:int, cordY:int, setColor:int, sense:int, getColor:int, getColorA:int, getColorR:int, getColorG:int, getColorB:int):Boolean {
	var ok:Boolean=false;
	if (cordX>=0&&cordY>=0&&cordX<bitData.width&&cordY<bitData.height) {
		var current:int=bitData.getPixel32(cordX,cordY);
		if (setColor!=current) {
			if (sense==0) {
				if (current==getColor) {
					ok=true;
				}
			} else {
				var diff:int=Math.abs((current>>24&0xff)-getColorA)+Math.abs((current>>16&0xff)-getColorR)+Math.abs((current>>8&0xff)-getColorG)+Math.abs((current&0xff)-getColorB);
				if (diff<=sense) {
					ok=true;
				}
			}
		}
	}
	return ok;
}