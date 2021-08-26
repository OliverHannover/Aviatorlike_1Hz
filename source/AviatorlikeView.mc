using Toybox.Graphics as Gfx;
using Toybox.Lang as Lang;
using Toybox.Math as Math;
using Toybox.System as Sys;
using Toybox.Time as Time;
using Toybox.Application as App;
using Toybox.Time.Gregorian as Calendar;
using Toybox.WatchUi as Ui;
using Toybox.Activity as Act;
using Toybox.ActivityMonitor as ActMonitor;
using Toybox.Sensor as Snsr;

enum
{
    LAT,
    LON
}


class AviatorlikeView extends Ui.WatchFace{

		var targetDc = null;
	    
	    //Positions for Displays + Text
	    var ULBGx, ULBGy, ULBGwidth;
	    var ULTEXTx, ULTEXTy;
	    var ULINFOx, ULINFOy;  
	    
	  	var LLBGx, LLBGy, LLBGwidth;
	    var LLTEXTx, LLTEXTy;
	    var LLINFOx, LLINFOy;
	    var labelText;
	  	var labelInfoText;  
	  	
	  	var infoLeft;
		var infoRight;
	    
	    var isAwake;
	    var fontLabel;
	    
	    var clockTime;
	    
	  	var width;
	    var height;  
	  	// the x coordinate for the center
	    var center_x;
	    // the y coordinate for the center
	    var center_y;      
	      
		var lastLoc;		
	
		var moonx, moony, moonwidth;
	
	//für den kurzen Sek-Zeiger 	
    private var _offscreenBuffer as BufferedBitmap?;
    private var _screenCenterPoint as Array<Number>?;
    private var _fullScreenRefresh as Boolean;
    private var _partialUpdatesAllowed as Boolean;
		
		
    function initialize() {
        WatchFace.initialize();        
	    fontLabel = Ui.loadResource(Rez.Fonts.id_font_label); 
   	    _fullScreenRefresh = true;
        _partialUpdatesAllowed = (Ui.WatchFace has :onPartialUpdate);
    }
   
    
    function onLayout(dc) {
    	// mit 1.0 multipliziert, damit die Nachkommastellen m,itkommen, ansonsten passt die Positionierung nicht, da gerundet wird. 
        width = dc.getWidth()*1.0;
        height = dc.getHeight()*1.0;
        
        center_x = dc.getWidth() / 2;
        center_y = dc.getHeight() / 2;
        Sys.println("width = " + width + ", height = " + height);    
        
        _screenCenterPoint = [dc.getWidth() / 2, dc.getHeight() / 2] as Array<Number>;
         // If this device supports BufferedBitmap, allocate the buffers we use for drawing
        if (Graphics has :BufferedBitmap) {
            // Allocate a full screen size buffer with a palette of only 4 colors to draw
            // the background image of the watchface.  This is used to facilitate blanking
            // the second hand during partial updates of the display
            _offscreenBuffer = new Gfx.BufferedBitmap({
                :width=>dc.getWidth()*1.0,
                :height=>dc.getHeight()*1.0,
                :palette=> [
                	Graphics.COLOR_TRANSPARENT,
                	//Graphics.COLOR_DK_RED,
                	//Graphics.COLOR_RED,
                    Graphics.COLOR_DK_GRAY,
                    Graphics.COLOR_LT_GRAY,
                    Graphics.COLOR_BLACK,
                    Graphics.COLOR_WHITE
                ] as Array<ColorValue>
            });

        } else {
            _offscreenBuffer = null;
        }
            
            		
			//oberer Displayhintergrund
			ULBGwidth = height/100 * 63.5;
			ULBGx = width/2 - ULBGwidth/2;
		   	ULBGy = height/100 * 23.7; // in % der Höhe von oben
		   	Sys.println("oberes Dips. Hoehe = " + ULBGy + " - Test: " + height/100 + ", " + dc.getWidth()/100 );
		   	
		    //oberer Displaytext
		   	ULTEXTx = width/2;
		   	ULTEXTy = height/100 * 24;
		   	
		    //zusätzlicher oberer Info-Text
		   	ULINFOx = width/2 + ULBGwidth/2 - 7;
		   	ULINFOy = height/100 * 24;  
		   	
		    //unterer Displayhintergrund
		   	LLBGx = ULBGx;
		   	LLBGy = height/100 * 62;
		   	LLBGwidth = ULBGwidth;
		   	Sys.println("unteres Dips. Hoehe = " + LLBGy);
		    
		    //unterer Display-Text
		   	LLTEXTx = width/2;
		   	LLTEXTy = height/100 * 62;
		    
		    //unterer Info-Text
		   	LLINFOx = ULINFOx;
		   	LLINFOy = height/100 * 62; 
		    
		    moonwidth = 40;
		   	moonx = width - moonwidth - 15;
		   	moony = height/2 - moonwidth/2; 		
				 
		   
}
 
  //! This function is used to generate the coordinates of the 4 corners of the polygon
    //! used to draw a watch hand. The coordinates are generated with specified length,
    //! tail length, and width and rotated around the center point at the provided angle.
    //! 0 degrees is at the 12 o'clock position, and increases in the clockwise direction.
    //! @param centerPoint The center of the clock
    //! @param angle Angle of the hand in radians
    //! @param handLength The length of the hand from the center to point
    //! @param tailLength The length of the tail of the hand
    //! @param width The width of the watch hand
    //! @return The coordinates of the watch hand
    private function generateHandCoordinates(centerPoint as Array<Number>, angle as Float, handLength as Number, tailLength as Number, width as Number) as Array< Array<Float> > {
        // Map out the coordinates of the watch hand
        var coords = [[-(width / 2), tailLength] as Array<Number>,
                      [-(width / 2), -handLength] as Array<Number>,
                      [width / 2, -handLength] as Array<Number>,
                      [width / 2, tailLength] as Array<Number>] as Array< Array<Number> >;
        var result = new Array< Array<Float> >[4];
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);

        // Transform the coordinates
        for (var i = 0; i < 4; i++) {
            var x = (coords[i][0] * cos) - (coords[i][1] * sin) + 0.5;
            var y = (coords[i][0] * sin) + (coords[i][1] * cos) + 0.5;

            result[i] = [centerPoint[0] + x, centerPoint[1] + y] as Array<Float>;
        }

        return result;
    }



    // Draw the hash mark symbols on the watch-------------------------------------------------------
    function drawHashMarks(dc) {

            var n;      
        	var alpha, r1, r2;

        	//alle 5 minutes
            dc.setPenWidth(3);
            dc.setColor(App.getApp().getProperty("MinutesColor"), Gfx.COLOR_TRANSPARENT);
           	r1 = width/2 -5; //inside
			r2 = width/2 ; //outside
           	for (alpha = Math.PI / 6; alpha <= 13 * Math.PI / 6; alpha += (Math.PI / 30)) { //jede Minute 			
				dc.drawLine(center_x+r1*Math.sin(alpha),center_y-r1*Math.cos(alpha), center_x+r2*Math.sin(alpha),center_y-r2*Math.cos(alpha)); 

     		}
        
        	//alle 5 minutes
            dc.setPenWidth(3);
            dc.setColor(App.getApp().getProperty("QuarterNumbersColor"), Gfx.COLOR_TRANSPARENT);
           	//r1 = width/2 -20; //inside
           	r1 = width/2 - (5 * App.getApp().getProperty("markslenth"));
			r2 = width/2 ; //outside
           	//for (var alpha = Math.PI / 6; alpha <= 13 * Math.PI / 6; alpha += (Math.PI / 30)) { //jede Minute
         	for (alpha = Math.PI / 6; alpha <= 11 * Math.PI / 6; alpha += (Math.PI / 3)) { //jede 5. Minute  			
				dc.drawLine(center_x+r1*Math.sin(alpha),center_y-r1*Math.cos(alpha), center_x+r2*Math.sin(alpha),center_y-r2*Math.cos(alpha)); 
				alpha += Math.PI / 6;  
				dc.drawLine(center_x+r1*Math.sin(alpha),center_y-r1*Math.cos(alpha), center_x+r2*Math.sin(alpha),center_y-r2*Math.cos(alpha));    	
     		}      
 
    }
 
 
    
    function drawQuarterHashmarks(dc){          
      //12, 3, 6, 9
      var NbrFont = (App.getApp().getProperty("Numbers"));   
      
       if ( NbrFont == 0 || NbrFont == 1) { //no number	  		
			var n;      
        	var r1, r2,  thicknes;      	
        	var outerRad = 0;
        	var lenth=20;
       		lenth = 20;
       	
        	var thick = 5;
        	thicknes = thick * 0.02;
        	
        	//when moon then only three marks
        	var nurdrei = 0;
        	var alphaMax = 4;
        	var MoonEnable = (App.getApp().getProperty("MoonEnable"));
				if (MoonEnable && NbrFont == 0) {
        			nurdrei = (Math.PI / 2) ;
        			alphaMax = 4;
        		}
        		if (MoonEnable && NbrFont == 1) {
        			nurdrei = (Math.PI / 2) ;
        			alphaMax = 3;
        		}
        		if (MoonEnable == false && NbrFont == 0) {
        			nurdrei = 0;
        			alphaMax = 4;
        		}
        		if (MoonEnable == false && NbrFont == 1) {
        			nurdrei = 0 ;
        			alphaMax = 3;
        		}
        		      	
           	for (var alpha = (Math.PI / 2) + nurdrei ; alpha <= alphaMax * Math.PI / 2; alpha += (Math.PI / 2)) { //jede 15. Minute    
			r1 = (width/2 + 3) - outerRad; //outside
			r2 = r1 -lenth; //inside			
							
			var marks = [[center_x+r1*Math.sin(alpha-thicknes),center_y-r1*Math.cos(alpha-thicknes)],
						[center_x+r2*Math.sin(alpha-thicknes),center_y-r2*Math.cos(alpha-thicknes)],
						[center_x+r2*Math.sin(alpha+thicknes),center_y-r2*Math.cos(alpha+thicknes)],
						[center_x+r1*Math.sin(alpha+thicknes),center_y-r1*Math.cos(alpha+thicknes)]   ];
			
			dc.setColor(App.getApp().getProperty("QuarterNumbersColor"), Gfx.COLOR_TRANSPARENT);		
			dc.fillPolygon(marks);
			
			dc.setPenWidth(1);
			dc.setColor(App.getApp().getProperty("BackgroundColor"), Gfx.COLOR_TRANSPARENT); 
			dc.drawLine(center_x+r2*Math.sin(alpha),center_y-r2*Math.cos(alpha), center_x+r1*Math.sin(alpha),center_y-r1*Math.cos(alpha));
			
			//Sys.println(alpha + " - " + (2 * Math.PI / 2));   		
			}
		}	
		else {	
	        var r1 = width/2 -5; //inside
			var r2 = width/2 ; //outside
		   	dc.setPenWidth(8);       
            dc.setColor(App.getApp().getProperty("QuarterNumbersColor"), Gfx.COLOR_TRANSPARENT);
            for (var alpha = Math.PI / 2; alpha <= 13 * Math.PI / 2; alpha += (Math.PI / 2)) {
				dc.drawLine(center_x+r1*Math.sin(alpha),center_y-r1*Math.cos(alpha), center_x+r2*Math.sin(alpha),center_y-r2*Math.cos(alpha));                
             }
         }
    } 

 

         
	function drawDigitalTime() {

  			var now = Time.now();
			var dualtime = false;
			var dualtimeTZ = (App.getApp().getProperty("DualTimeTZ"));
			var dualtimeDST = (App.getApp().getProperty("DualTimeDST"));			
			
			clockTime = Sys.getClockTime();
	 			
			var dthour;
			var dtmin;
			var dtsec;
			var dtnow = now;
			// adjust to UTC/GMT
			dtnow = dtnow.add(new Time.Duration(-clockTime.timeZoneOffset));
			// adjust to time zone
			dtnow = dtnow.add(new Time.Duration(dualtimeTZ));
			
						
			if (dualtimeDST != 0) {
				// calculate Daylight Savings Time (DST)
				var dtDST;
				if (dualtimeDST == -1) {
					// Use the current dst value
					dtDST = clockTime.dst;
				} else {
					// Use the configured DST value
					dtDST = dualtimeDST; 
				}
				// adjust DST
				dtnow = dtnow.add(new Time.Duration(dtDST));
			}

			// create a time info object
			var dtinfo = Calendar.info(dtnow, Time.FORMAT_LONG);
			
			dthour = dtinfo.hour;
			dtmin = dtinfo.min;
			dtsec = dtinfo.sec;
			
			//var use24hclock;
			//var ampmStr = "am ";
			
			var use24hclock = Sys.getDeviceSettings().is24Hour;
			if (!use24hclock) {
				if (dthour >= 12) {
					labelInfoText = "pm";
				}
				if (dthour > 12) {
					dthour = dthour - 12;				
				} else if (dthour == 0) {
					dthour = 12;
					labelInfoText = "am";
				}
			}			
			
			if (dthour < 10) {
				labelText = Lang.format("0$1$:", [dthour]);
			} else {
				labelText = Lang.format("$1$:", [dthour]);
			}
			if (dtmin < 10) {
				labelText = labelText + Lang.format("0$1$", [dtmin]);
			} else {
				labelText = labelText + Lang.format("$1$", [dtmin]);
			}
			
			if (isAwake) {
				if (dtsec < 10) {
					labelText = labelText + Lang.format(":0$1$", [dtsec]);
				} else {
					labelText = labelText + Lang.format(":$1$", [dtsec]);
				}
			}
			
			
  
  }//End of drawDigitalTime(dc)-------


	function drawAltitude() {
			
			var unknownaltitude = true;
			var actaltitude = 0;
			var actInfo;
			var metric = Sys.getDeviceSettings().elevationUnits == Sys.UNIT_METRIC;
			labelInfoText = "m";
						
			actInfo = Act.getActivityInfo();
			if (actInfo != null) {
			
				if (metric) {				
				labelInfoText = "m";
				actaltitude = actInfo.altitude;
				} else {
				labelInfoText = "ft";
				actaltitude = actInfo.altitude  * 3.28084;
				}
			
			
				if (actaltitude != null) {
					unknownaltitude = false;
				} 				
			}			
							
			if (unknownaltitude) {
				labelText = "unknown";
			} else {
				labelText = Lang.format("$1$", [actaltitude.toLong()]);				
			}
			
			infoLeft = labelText;
       		//dc.drawText(width / 2, (height / 10 * 6.9), fontDigital, altitudeStr, Gfx.TEXT_JUSTIFY_CENTER);
        }
	
	
function drawBattery(dc) {
	// Draw battery -------------------------------------------------------------------------
		
		var Battery = Toybox.System.getSystemStats().battery;       
        
        var alpha, hand;
        alpha = 0; 
        alpha = 2*Math.PI/100*(Battery); 

						
			var r1, r2;      	
        	var outerRad = 0;
        	var lenth = 15;
     
			r1 = width/2 - outerRad; //outside
			r2 = r1 -lenth; ////L�nge des Bat-Zeigers
										
			hand =     [[center_x+r1*Math.sin(alpha+0.1),center_y-r1*Math.cos(alpha+0.1)],
						[center_x+r2*Math.sin(alpha),center_y-r2*Math.cos(alpha)],
						[center_x+r1*Math.sin(alpha-0.1),center_y-r1*Math.cos(alpha-0.1)]   ];				
						
        if (Battery >= 25) {
        dc.setColor(Gfx.COLOR_ORANGE, Gfx.COLOR_TRANSPARENT);
        }
        if (Battery < 25) {
        dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
        }
		if (Battery >= 50) {
        dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT);
        }
		dc.fillPolygon(hand);
		
		dc.setColor(App.getApp().getProperty("QuarterNumbersColor"), Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        var n;
		for (n=0; n<2; n++) {
			dc.drawLine(hand[n][0], hand[n][1], hand[n+1][0], hand[n+1][1]);
		}
		dc.drawLine(hand[n][0], hand[n][1], hand[0][0], hand[0][1]);		
	}
	
	
	//StepGoal progress-------------------------------
 	function drawStepGoal(dc) {
              
        var actsteps = 0;
        var stepGoal = 0;		
		
		stepGoal = ActMonitor.getInfo().stepGoal;
		actsteps = ActMonitor.getInfo().steps;
		var stepPercent = 100 * actsteps / stepGoal;
        
        //dc.drawText(width / 2, (height / 4 * 3), fontDigital, stepGoal, Gfx.TEXT_JUSTIFY_CENTER);
        //dc.drawText(width / 2, (height / 5), fontDigital, stepPercent, Gfx.TEXT_JUSTIFY_CENTER);
       
       	if (stepPercent >= 100) {
       		stepPercent = 100;
       	} 
       	
       	if (stepPercent > 95) {
       		dc.setColor(Gfx.COLOR_PURPLE, Gfx.COLOR_TRANSPARENT);
       	}
       	if (stepPercent <= 95) {
       		dc.setColor(Gfx.COLOR_BLUE, Gfx.COLOR_TRANSPARENT);
       	}
       	if (stepPercent < 70 ) {
       		dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT);
       	}
       	if (stepPercent < 29) {
       		dc.setColor(Gfx.COLOR_ORANGE , Gfx.COLOR_TRANSPARENT);
       	}
       	if (stepPercent < 5) {
       		dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
       	}
       	
       	    
              
        var alpha, hand;
        alpha = 0; 
        alpha = 2*Math.PI/100*(stepPercent);

			var r1, r2;      	
        	var outerRad = 0;
        	var lenth = 15;
     
			r1 = width/2 - outerRad; //outside
			r2 = r1 -lenth; ////L�nge des Step-Zeigers
										
			hand =     [[center_x+r2*Math.sin(alpha+0.1),center_y-r2*Math.cos(alpha+0.1)],
						[center_x+r1*Math.sin(alpha),center_y-r1*Math.cos(alpha)],
						[center_x+r2*Math.sin(alpha-0.1),center_y-r2*Math.cos(alpha-0.1)]   ];					
		
       if (stepPercent < 100) {       
					
			dc.fillPolygon(hand);			
			dc.setColor(App.getApp().getProperty("QuarterNumbersColor"), Gfx.COLOR_TRANSPARENT);
	        dc.setPenWidth(1);
	        var n;
			for (n=0; n<2; n++) {
				dc.drawLine(hand[n][0], hand[n][1], hand[n+1][0], hand[n+1][1]);
			}
			dc.drawLine(hand[n][0], hand[n][1], hand[0][0], hand[0][1]);
		}
		
 	}


//Sonnenauf- und Untergang

	function momentToString(moment) {
		if (moment == null) {
			return "--:--";
		}

   		var tinfo = Time.Gregorian.info(new Time.Moment(moment.value() + 30), Time.FORMAT_SHORT);
		var text;
		if (Sys.getDeviceSettings().is24Hour) {
			text = tinfo.hour.format("%02d") + ":" + tinfo.min.format("%02d");
		} else {
			var hour = tinfo.hour % 12;
			if (hour == 0) {
				hour = 12;
			}
			text = hour.format("%02d") + ":" + tinfo.min.format("%02d");			
		}
		return text;
	}
 	

    function buildSunsetStr()
    {
		var sc = new SunCalc();
		var lat;
		var lon;		
		var loc = Act.getActivityInfo().currentLocation;

		if (loc == null)
		{
			lat = App.getApp().getProperty(LAT);
			lon = App.getApp().getProperty(LON);
		} 
		else
		{
			lat = loc.toDegrees()[0] * Math.PI / 180.0;
			App.getApp().setProperty(LAT, lat);
			lon = loc.toDegrees()[1] * Math.PI / 180.0;
			App.getApp().setProperty(LON, lon);
		}


// lokale Position (nur für Simulator!)
		lat = 52.375892 * Math.PI / 180.0;
		lon = 9.732010 * Math.PI / 180.0;

		if(lat != null && lon != null)
		{
			
			var now = new Time.Moment(Time.now().value());			
			var sunrise_moment = sc.calculate(now, lat.toDouble(), lon.toDouble(), SUNRISE);
			var sunset_moment = sc.calculate(now, lat.toDouble(), lon.toDouble(), SUNSET);
			var sunrise = momentToString(sunrise_moment);
			var sunset = momentToString(sunset_moment);		

    		labelText =  sunrise + "  " + sunset;
    		   		
    		infoLeft = sunrise;
			infoRight = sunset;	
				
		}else{
	    	labelText = Ui.loadResource(Rez.Strings.none);
	    	}
		
	}
// Ende - Sonnenauf- und Untergang

	//draw stepHistory-Graph-----------------------------------------------------------------------------------	
	function drawStepGraph(dc,stepGraphposX, stepGraphposY, stepInfoX, stepInfoY) {
		var activityHistory = ActMonitor.getHistory();
	  	var histDays=activityHistory.size();
	  	//Sys.println("histDays: " + histDays);
	  		  	
	  	var maxheight = 26.0;	  	
	  	var stepHistory=0;
	  	var maxValue; 
	  	var graphheight; 
	  	//Sys.println("graphheight : " + graphheight);
	  	
	  	var graphposX = stepGraphposX;
	  	var graphposY = stepGraphposY + 4;
	  	
	  	dc.setColor((App.getApp().getProperty("ForegroundColor")), Gfx.COLOR_TRANSPARENT);
	  	dc.setPenWidth(1);
	  	//first draw empty graph---------------------------------------------------------
	  	for(var i=0;i<7;i++) {	 
	  		//Sys.println("i : " + i); 	
	  		//dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
	  		dc.drawRectangle(graphposX, graphposY, 9, maxheight);
	        graphposX = graphposX - 11;	        
	  	}//--------------------------------------------------------------------------
	  		  	
	  if (histDays > 0) {	  	
	  		graphposX = stepGraphposX;
		  	for(var i=0;i<histDays;i++) {
		  		maxValue=stepHistory+activityHistory[i].stepGoal;
		  		graphheight = maxheight / maxValue;		  		
		  		stepHistory=stepHistory+activityHistory[i].steps;		  		
		  		graphheight = graphheight * stepHistory;
		  		
		  		if (graphheight > maxheight) {
		  			graphheight = maxheight;
		  		}
		  		
		  		//Sys.println("graphheight " + i + ": " + graphheight);	
		  		dc.fillRectangle(graphposX, graphposY+maxheight-graphheight, 8, graphheight);		  	
		  		dc.setColor((App.getApp().getProperty("ForegroundColor")), Gfx.COLOR_TRANSPARENT);
		  		dc.drawRectangle(graphposX, graphposY, 9, maxheight);
	
		        graphposX = graphposX - 11;
		        stepHistory=0;
		        graphheight = maxheight / maxValue;
		  	}
		  	
		  	//aktual step graph--------------------------------------
		  	maxValue=ActMonitor.getInfo().stepGoal;
	  		graphheight = maxheight / maxValue;
	  		
		  	dc.drawText(stepInfoX, stepInfoY + 17, fontLabel, ActMonitor.getInfo().steps, Gfx.TEXT_JUSTIFY_RIGHT);
	  		graphheight = graphheight * ActMonitor.getInfo().steps;
	  		if (graphheight > maxheight) {
	  			graphheight = maxheight;
	  		}
	  		dc.setColor((App.getApp().getProperty("HandsColor1")), Gfx.COLOR_TRANSPARENT);
	  		dc.fillRectangle(stepGraphposX+11, graphposY+maxheight-graphheight, 9, graphheight);	 
	  		dc.setColor((App.getApp().getProperty("ForegroundColor")), Gfx.COLOR_TRANSPARENT); 	
		  	dc.drawRectangle(stepGraphposX+11, graphposY, 9, maxheight);
	  	}
	  }// end od draw stepHistory-Graph----------------------



	//build string for display in labels-------------------- 
	function setLabel(displayInfo) {
				
			labelText = "";
  			labelInfoText = "";	        
    		     	    	
	 		//Draw date---------------------------------
		   	if (displayInfo == 1) {
		   		date.buildDateString();
		   		labelText = date.dateStr;	  		      
			}	
	
	 	    //Draw Steps --------------------------------------
	      	if (displayInfo == 2) {				   		
		   		labelText = Lang.format("$1$", [ActMonitor.getInfo().steps]);
	  			labelInfoText = Lang.format("$1$", [ActMonitor.getInfo().stepGoal]);   						
			}
			
			//Draw Steps to go --------------------------------------
	      	if (displayInfo == 3) {
	        var actsteps = 0;
	        var stepGoal = 0;
	        var stepstogo = 0;		
			stepGoal = ActMonitor.getInfo().stepGoal;
			actsteps = ActMonitor.getInfo().steps;
			
		        if (actsteps <= stepGoal) {
			        stepstogo = "- " + (stepGoal - actsteps);
			    }
			    if (actsteps > stepGoal) {
			        stepstogo = "+ " + (actsteps - stepGoal);
			    }    			        
			        stepstogo = Lang.format("$1$", [stepstogo]); 			        
		   		labelText = stepstogo;				        			              
			}

	 	    //Draw StepGraph --------------------------------------
	      	if (displayInfo == 4) {				   		
		   		labelText = "";
	  			labelInfoText = Lang.format("$1$", [ActMonitor.getInfo().stepGoal]); 	  						
			}


	 		//Draw DigitalTime---------------------------------
		   	if (displayInfo == 5) {
				 drawDigitalTime(); 
			}	         
	        
	    	// Draw Altitude------------------------------
			if (displayInfo == 6) {
				drawAltitude();	
			 }	
				
			// Draw Calories------------------------------
			if (displayInfo == 7) {	
				var actInfo = ActMonitor.getInfo(); 
		        var actcals = actInfo.calories;		       
		        labelText = Lang.format("$1$", [actcals]);
		        labelInfoText = "kCal";
			}
			
			//Draw distance
			if (displayInfo == 8) {
				distance.drawDistance();
				labelText = distance.distStr;
	  			labelInfoText = distance.distUnit;
	  			//Sys.println("Distance");
			}			
			
			//Draw battery
			if (displayInfo == 9) {
				var Battery = Toybox.System.getSystemStats().battery;       
        	    labelText = Lang.format("$1$ % ", [ Battery.format ( "%2d" ) ] );
			}
			
			//Draw Day and week of year
			if (displayInfo == 10) {
				date.builddayWeekStr();
				//labelText = date.dayWeekStr;
				labelText = date.aktDay + " / " + date.week;
			}
			
			//next / over next sun event
			if (displayInfo == 11) {
				buildSunsetStr();
		    }
		    
		   	//heart rate
			if (displayInfo == 12) {
			var hasHR = (ActivityMonitor has :HeartRateIterator) ? true : false;			
				if (hasHR) {
					var HRH = ActMonitor.getHeartRateHistory(null, true);
					var hr="--";
					
					if(HRH != null) {
						var HRS=HRH.next();
						if(HRS!=null && HRS.heartRate!=null && HRS.heartRate!=ActMonitor.INVALID_HR_SAMPLE) {
							hr = HRS.heartRate.toString();
							labelText = hr;
							labelInfoText = "bpm";
							//labelText = HRH.getMax()+"/"+HRH.getMin()+" "+HRS.heartRate+" bpm";			
						}
					}	
				}
				else {
				labelText = "no sensor";
				}				
		    }
		   		    	    
		    
		    
	//Sys.println("Dispfilled");
	//Sys.println("");
	}		
	

// Handle the update event-----------------------------------------------------------------------
function onUpdate(dc) {
    
        // We always want to refresh the full screen when we get a regular onUpdate call.
        //var targetDc = null;
        
        _fullScreenRefresh = true;
        var offscreenBuffer = _offscreenBuffer;
        if (null != offscreenBuffer) {
            dc.clearClip();
            // If we have an offscreen buffer that we are using to draw the background,
            // set the draw context of that buffer as our target.
            targetDc = offscreenBuffer.getDc();
        } else {
            targetDc = dc;
        }


        

        
  // Clear the screen--------------------------------------------
        //dc.setColor(App.getApp().getProperty("BackgroundColor"), Gfx.COLOR_TRANSPARENT));
        targetDc.setColor(Gfx.COLOR_TRANSPARENT, App.getApp().getProperty("BackgroundColor"));
        targetDc.clear();

     

        
        
    // Moon phase
		var MoonEnable = (App.getApp().getProperty("MoonEnable"));
		if (MoonEnable) {             			
	   		var now = Time.now();
			var dateinfo = Calendar.info(now, Time.FORMAT_SHORT);
	        var clockTime = Sys.getClockTime();
	        var moon = new Moon(Ui.loadResource(Rez.Drawables.moon1), moonwidth, moonx, moony);
	        	
	        moon.updateable_calcmoonphase(targetDc, dateinfo, clockTime.hour);
	        
			targetDc.setColor(App.getApp().getProperty("QuarterNumbersColor"), Gfx.COLOR_TRANSPARENT);
			targetDc.setPenWidth(1);	   
	 		targetDc.drawCircle(moonx+moonwidth/2,moony+moonwidth/2,moonwidth/2-1);
	 		
	 		//targetDc.setColor((App.getApp().getProperty("NumbersColor")), Gfx.COLOR_TRANSPARENT);
	 		//targetDc.drawText(moonx+moonwidth/2,moony+moonwidth/2-12, fontLabel, moon.c_moon_label, Gfx.TEXT_JUSTIFY_CENTER);
			//targetDc.drawText(moonx+moonwidth/2,moony+moonwidth/2, fontLabel, moon.c_phase, Gfx.TEXT_JUSTIFY_CENTER);
		}
              
   // Draw the numbers --------------------------------------------------------------------------------------
       var NbrFont = (App.getApp().getProperty("Numbers")); 
       targetDc.setColor((App.getApp().getProperty("NumbersColor")), (App.getApp().getProperty("BackgroundColor")));
       var font1 = 0;  
       
   		    if ( NbrFont == 1) { //fat
	    		font1 = Ui.loadResource(Rez.Fonts.id_font_fat);
	    		targetDc.drawText((width / 2), 5, font1, "12", Gfx.TEXT_JUSTIFY_CENTER);
	    	}            
		    if ( NbrFont == 2) { //fat
		    		font1 = Ui.loadResource(Rez.Fonts.id_font_fat);
		    		targetDc.drawText((width / 2), 5, font1, "12", Gfx.TEXT_JUSTIFY_CENTER);
		    		if (! MoonEnable) {
		    			targetDc.drawText(width - 16, (height / 2) - 26, font1, "3", Gfx.TEXT_JUSTIFY_RIGHT);
	        		}
	        		targetDc.drawText(width / 2, height - 54, font1, "6", Gfx.TEXT_JUSTIFY_CENTER);
	        		targetDc.drawText(16, (height / 2) - 26, font1, "9", Gfx.TEXT_JUSTIFY_LEFT);
		    	}
		    if ( NbrFont == 3) { //race
		    		font1 = Ui.loadResource(Rez.Fonts.id_font_race);
		    		targetDc.drawText((width / 2), 5, font1, "12", Gfx.TEXT_JUSTIFY_CENTER);
		    		if (! MoonEnable) {	
		    			targetDc.drawText(width - 16, (height / 2) - 26, font1, "3", Gfx.TEXT_JUSTIFY_RIGHT);
	        		}
	        		targetDc.drawText(width / 2, height - 52, font1, "6", Gfx.TEXT_JUSTIFY_CENTER);
	        		targetDc.drawText(16, (height / 2) - 26, font1, "9", Gfx.TEXT_JUSTIFY_LEFT);
		    	}
		    if ( NbrFont == 4) { //classic
		    		font1 = Ui.loadResource(Rez.Fonts.id_font_classic);
		    		targetDc.drawText((width / 2), 15, font1, "12", Gfx.TEXT_JUSTIFY_CENTER);
		    		if (! MoonEnable) {	
		    			targetDc.drawText(width - 16, (height / 2) - 18, font1, "3", Gfx.TEXT_JUSTIFY_RIGHT);
	        		}
	        		targetDc.drawText(width / 2, height - 48, font1, "6", Gfx.TEXT_JUSTIFY_CENTER);
	        		targetDc.drawText(16, (height / 2) - 18, font1, "9", Gfx.TEXT_JUSTIFY_LEFT);
		    	}
		   if ( NbrFont == 5) {  //roman
		    		font1 = Ui.loadResource(Rez.Fonts.id_font_roman);
		    		targetDc.drawText((width / 2), 11, font1, "}", Gfx.TEXT_JUSTIFY_CENTER);
		    		if (! MoonEnable) {	
		    			targetDc.drawText(width - 16, (height / 2) - 22, font1, "3", Gfx.TEXT_JUSTIFY_RIGHT);
	        		}
	        		targetDc.drawText(width / 2, height - 50, font1, "6", Gfx.TEXT_JUSTIFY_CENTER);
	        		targetDc.drawText(16, (height / 2) - 22, font1, "9", Gfx.TEXT_JUSTIFY_LEFT);
		   		}
		   	if ( NbrFont == 6) {  //simple
		    		targetDc.drawText((width / 2), 10, Gfx.FONT_SYSTEM_LARGE   , "12", Gfx.TEXT_JUSTIFY_CENTER);
		    		if (! MoonEnable) {
		    			targetDc.drawText(width - 16, (height / 2) - 22, Gfx.FONT_SYSTEM_LARGE  , "3", Gfx.TEXT_JUSTIFY_RIGHT);
	        		}
	        		targetDc.drawText(width / 2, height - 45, Gfx.FONT_SYSTEM_LARGE   , "6", Gfx.TEXT_JUSTIFY_CENTER);
	        		targetDc.drawText(16, (height / 2) - 22, Gfx.FONT_SYSTEM_LARGE   , "9", Gfx.TEXT_JUSTIFY_LEFT);
		   		}
       
        
      
    // Indicators ---------------------------------------------------------------------------       
 	

		//! Alm / Msg indicators
		var AlmMsgEnable = (App.getApp().getProperty("AlmMsgEnable"));
		var AlmMsg = (App.getApp().getProperty("AlmMsg"));
		
		if (AlmMsgEnable) {
			var offcenter=35;
			var labelLeft = "";
			var labelRight = "";
			//var infoLeft = "";
			//var infoRight = "";
			infoLeft = "";
			infoRight = "";
			
			targetDc.setColor((App.getApp().getProperty("QuarterNumbersColor")), (App.getApp().getProperty("BackgroundColor")));
			var messages = Sys.getDeviceSettings().notificationCount;
			var alarm = Sys.getDeviceSettings().alarmCount; 
			
			if (AlmMsg == 1) { // setting Alm/Msg count		     	
		     	labelLeft = "Alm";
		     	infoLeft = alarm;
		     	
	     		labelRight = "Msg";
				infoRight = messages; 
			} 	     	
	 	    
	 	    if (AlmMsg == 2) { // setting Alm/Msg only indicators 
	 	    	labelLeft = "Alm";		     	
	     		labelRight = "Msg";	
				//messages
 	     		if (messages > 0) {
 	     		    targetDc.fillCircle(width / 2 + offcenter, height / 2 -7, 5);
 	     		}
 	     		targetDc.setPenWidth(2);
 	        	targetDc.drawCircle(width / 2 + offcenter, height / 2 -7, 5);	
 	        		     		     	
				//Alarm		     	
 	     		if (alarm > 0) {
 	     			targetDc.fillCircle(width / 2 - offcenter, height / 2 -7, 5);
 	     		}
 	     		targetDc.setPenWidth(2);
 	        	targetDc.drawCircle(width / 2 - offcenter, height / 2 -7, 5);
	     	} 
	     	
	     	if (AlmMsg == 3) { 
	     		date.builddayWeekStr();    	
	     		labelLeft = "day";
	     		infoLeft = date.aktDay;
	     		labelRight = "week";				
				infoRight = date.week;     	
	     	}
	     	
	     	if (AlmMsg == 4) { 
	     		buildSunsetStr();    	
	     		labelLeft = "s.rise";
	     		labelRight = "s.set";				   	
	     	}
	     	
	     	if (AlmMsg == 5) { 
	     		drawAltitude();    	
	     		labelLeft = "elev";	     		
	     		distance.drawDistance();
	     		labelRight = "dist";				
				infoRight = distance.distStr;    	
	     	}
	     	
	     	if (AlmMsg == 6) {    	
	     		labelLeft = "goal";	     		
	     		infoLeft = ActMonitor.getInfo().stepGoal;
	     		labelRight = "steps";				
				infoRight = ActMonitor.getInfo().steps;    	
	     	}
	     		
			targetDc.drawText(width / 2 + offcenter, height / 2 -15, fontLabel, infoRight, Gfx.TEXT_JUSTIFY_CENTER);	     		
	 		targetDc.drawText(width / 2 + offcenter, height / 2 -2, fontLabel, labelRight, Gfx.TEXT_JUSTIFY_CENTER);
	 		
	 		targetDc.drawText(width / 2 - offcenter, height / 2 -15, fontLabel, infoLeft, Gfx.TEXT_JUSTIFY_CENTER);
	 		targetDc.drawText(width / 2 - offcenter, height / 2 -2, fontLabel, labelLeft, Gfx.TEXT_JUSTIFY_CENTER); 
		}       




//Draw Digital Elements ------------------------------------------------------------------ 

	    var fontDigital = 0;
	   

         var digiFont = (App.getApp().getProperty("DigiFont")); 
         //Sys.println("digiFont="+ digiFont);
         //fontDigital = null;
         
    	//font for display
	    if ( digiFont == 1) { //!digital
	    	fontDigital = Ui.loadResource(Rez.Fonts.id_font_digital); 
	    	//fontDigital = Gfx.FONT_SYSTEM_MEDIUM ;
	    	//Sys.println("set digital");    
	    	}
	    if ( digiFont == 2) { //!classik
        	fontDigital = Ui.loadResource(Rez.Fonts.id_font_classicklein); 
        	//fontDigital = Gfx.FONT_SYSTEM_MEDIUM ;
        	//Sys.println("set classic");     
	    	}
	    if ( digiFont == 3) { //!simple
        		fontDigital = Gfx.FONT_SYSTEM_MEDIUM ;         	     	    
	    }
	    	    	   
	    var UpperDispEnable = (App.getApp().getProperty("UpperDispEnable"));
	    var LowerDispEnable = (App.getApp().getProperty("LowerDispEnable"));

	  	
		//Anzeige oberes Display--------------------------  
		if (UpperDispEnable) {
			var displayInfo = (App.getApp().getProperty("UDInfo"));
		//	Sys.println("UDInfo: " + displayInfo);
			setLabel(displayInfo);
			//background for upper display
			targetDc.setColor(App.getApp().getProperty("DigitalBackgroundColor"), Gfx.COLOR_TRANSPARENT);  
	       	targetDc.fillRoundedRectangle(ULBGx, ULBGy , ULBGwidth, 38, 5);
      	      	 
        	targetDc.setColor((App.getApp().getProperty("ForegroundColor")), (App.getApp().getProperty("DigitalBackgroundColor")));
        	targetDc.drawText(ULTEXTx, ULTEXTy, fontDigital, labelText, Gfx.TEXT_JUSTIFY_CENTER);	
        	//targetDc.drawText(ULTEXTx, ULTEXTy, Gfx.FONT_SYSTEM_MEDIUM, "88:88/88:88", Gfx.TEXT_JUSTIFY_CENTER);	
			targetDc.drawText(ULINFOx, ULINFOy, fontLabel, labelInfoText, Gfx.TEXT_JUSTIFY_RIGHT);
			
			if (displayInfo == 4) {
			drawStepGraph(targetDc, ULTEXTx, ULTEXTy, ULINFOx, ULINFOy);
			}	    				
		}	
		
			
	 //Anzeige unteres Display--------------------------  
		if (LowerDispEnable) {
			var displayInfo = (App.getApp().getProperty("LDInfo"));
		//	Sys.println("LDInfo: " + displayInfo);
			setLabel(displayInfo);
			//background for upper display
			targetDc.setColor(App.getApp().getProperty("DigitalBackgroundColor"), Gfx.COLOR_TRANSPARENT);  
	       	targetDc.fillRoundedRectangle(LLBGx, LLBGy , LLBGwidth, 38, 5);
	       	       	      	      	 
        	targetDc.setColor((App.getApp().getProperty("ForegroundColor")), (App.getApp().getProperty("DigitalBackgroundColor")));
        	targetDc.drawText(LLTEXTx, LLTEXTy, fontDigital, labelText, Gfx.TEXT_JUSTIFY_CENTER);
       // 	targetDc.drawText(LLTEXTx-25, LLTEXTy, fontDigital, "88888", Gfx.TEXT_JUSTIFY_CENTER);		
			targetDc.drawText(LLINFOx, LLINFOy, fontLabel, labelInfoText, Gfx.TEXT_JUSTIFY_RIGHT);
			
			if (displayInfo == 4) {
			drawStepGraph(targetDc, LLTEXTx, LLTEXTy, LLINFOx, LLINFOy);
			}	    				
		}

//Fadenkreuz-------------------------------------
	  	targetDc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
//	  	targetDc.setPenWidth(1);  	
//		dc.drawLine(ULBGx, 0, ULBGx , height);
//		dc.drawLine(ULBGx + ULBGwidth, 0, ULBGx + ULBGwidth , height);	
//		dc.drawLine(width/2, 0, width/2 , height);		
//		dc.drawLine(0, height/2, width , height/2);

	
//draw move bar (inactivity alarm)----------------------
// Sys.println("moveBarLevel "+ ActMonitor.getInfo().moveBarLevel);
var showMoveBar = (App.getApp().getProperty("MoveBarEnable"));

var setY = ULBGy + 40 ;
var setX = center_x;

	if (showMoveBar) {
	targetDc.setPenWidth(3);
	
		targetDc.setColor(App.getApp().getProperty("QuarterNumbersColor"), Gfx.COLOR_TRANSPARENT);
		if (ActMonitor.getInfo().moveBarLevel >= 1) {
			targetDc.drawLine(setX - 7 , setY, setX  - 58, setY);		
		//	targetDc.fillRoundedRectangle(ULBGx , setY, ULBGwidth/2 - 2 , 3, 3);
		}
			
		if (ActMonitor.getInfo().moveBarLevel >= 2) {
			targetDc.drawLine(setX , setY, setX + 10, setY);
			setX = setX +  16;
		//	targetDc.fillRoundedRectangle(ULBGx + ULBGwidth/2, setY, ULBGwidth/8 - 2 , 3, 3);
		}
		if (ActMonitor.getInfo().moveBarLevel >= 3) {
			targetDc.drawLine(setX , setY, setX + 10, setY);
			setX = setX +  16;
		//	targetDc.fillRoundedRectangle(ULBGx  + ULBGwidth/2 + ULBGwidth/8, setY, ULBGwidth/8 - 2 , 3, 3);
		}
		if (ActMonitor.getInfo().moveBarLevel >= 4) {
			targetDc.drawLine(setX , setY, setX + 10, setY);
			setX = setX +  16;
		//	targetDc.fillRoundedRectangle(ULBGx  + ULBGwidth/2 + ULBGwidth/8 * 2, setY, ULBGwidth/8 - 2 , 3, 3);
		}
		if (ActMonitor.getInfo().moveBarLevel == 5) {
			targetDc.drawLine(setX , setY, setX + 10, setY);
		//	targetDc.fillRoundedRectangle(ULBGx  + ULBGwidth/2 + ULBGwidth/8 * 3, setY, ULBGwidth/8 + 2 , 3, 3);
		}
	}	  	
	     

  // Draw hands ------------------------------------------------------------------         
    	hands.drawHands(targetDc); 

     	
  // Center Point with Bluetooth connection
  	var CenterDotEnable = (App.getApp().getProperty("CenterDotEnable"));
  	if (CenterDotEnable) {
  	
  		if (Sys.getDeviceSettings().phoneConnected) {
  			targetDc.setColor((App.getApp().getProperty("HandsColor1")), Gfx.COLOR_TRANSPARENT);
	   	} else {
  			targetDc.setColor((App.getApp().getProperty("BackgroundColor")), Gfx.COLOR_TRANSPARENT);
	   	} 
	
	} else {
  			targetDc.setColor((App.getApp().getProperty("HandsColor1")), Gfx.COLOR_TRANSPARENT);
	   	} 
    
	    targetDc.fillCircle(width / 2, height / 2, 5);
	    targetDc.setPenWidth(2);
     	targetDc.setColor((App.getApp().getProperty("HandsColor2")), Gfx.COLOR_TRANSPARENT);
	    targetDc.drawCircle(width / 2, height / 2 , 5);
 	    
 
     // Output the offscreen buffers to the main display if required.
       drawBackground(dc);
       
    // Draw the hash marks (nicht in den Buffer!)---------------------------------------------------------------------------
        drawHashMarks(dc);  
        drawQuarterHashmarks(dc);    
        
   	//some Idicators
   		//!progress battery------------
		var BatProgressEnable = (App.getApp().getProperty("BatProgressEnable"));
       	if (BatProgressEnable) {
			drawBattery(dc);
		}
		//!progress steps--------------
		var StepProgressEnable = (App.getApp().getProperty("StepProgressEnable"));
       	if (StepProgressEnable) {
			drawStepGoal(dc);
		}
		//! Markers for sunrire and sunset
		var SunmarkersEnable = (App.getApp().getProperty("SunMarkersEnable"));		
       	if (SunmarkersEnable) {
       		//Sys.println("sunmarkers "+ SunmarkersEnable);
			marker.drawSunMarkers(dc);
		}         
       
       
       
 
         if (_partialUpdatesAllowed) {
            // If this device supports partial updates and they are currently
            // allowed run the onPartialUpdate method to draw the second hand.
            onPartialUpdate(dc);
            Sys.println("_partialUpdatesAllowed = true");
        } else if (isAwake) {
        	var SecHandEnable = (App.getApp().getProperty("SecHandEnable"));
        	if (SecHandEnable) {
        		hands.drawSecondHands(dc);
        		Sys.println("isAwake = true");
        	}	
        	
            // Otherwise, if we are out of sleep mode, draw the second hand
            // directly in the full update method.
            //targetDc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            //var secondHand = (clockTime.sec / 60.0) * Math.PI * 2;

            //targetDc.fillPolygon(generateHandCoordinates(_screenCenterPoint, secondHand, 60, 20, 2));
        }


      	 
        _fullScreenRefresh = false; 
 
//Ausgabe Speicherstatus auf Konsole
Sys.println("used: " + System.getSystemStats().usedMemory);
Sys.println("free: " + System.getSystemStats().freeMemory);
Sys.println("total: " + System.getSystemStats().totalMemory);
Sys.println("");

}



    //! Handle the partial update event
    //! @param dc Device context
    public function onPartialUpdate(dc as Dc) as Void {
        // If we're not doing a full screen refresh we need to re-draw the background
        // before drawing the updated second hand position. Note this will only re-draw
        // the background in the area specified by the previously computed clipping region.
        if (!_fullScreenRefresh) {
            drawBackground(dc);
        }

        var clockTime = System.getClockTime();
        var secondHand = (clockTime.sec / 60.0) * Math.PI * 2;
        var secondHandPoints = generateHandCoordinates(_screenCenterPoint, secondHand, 60, 20, 2);
        // Update the clipping rectangle to the new location of the second hand.
        var curClip = getBoundingBox(secondHandPoints);
        var bBoxWidth = (curClip[1][0] - curClip[0][0] + 1) * 1.0;
        var bBoxHeight = (curClip[1][1] - curClip[0][1] + 1) * 1.0;
        dc.setClip(curClip[0][0], curClip[0][1], bBoxWidth, bBoxHeight);

        // Draw the second hand to the screen.
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(secondHandPoints);
               
    }

    //! Compute a bounding box from the passed in points
    //! @param points Points to include in bounding box
    //! @return The bounding box points
    private function getBoundingBox(points as Array< Array<Number or Float> >) as Array< Array<Number or Float> > {
        var min = [9999, 9999] as Array<Number>;
        var max = [0,0] as Array<Number>;

        for (var i = 0; i < points.size(); ++i) {
            if (points[i][0] < min[0]) {
                min[0] = points[i][0];
            }

            if (points[i][1] < min[1]) {
                min[1] = points[i][1];
            }

            if (points[i][0] > max[0]) {
                max[0] = points[i][0];
            }

            if (points[i][1] > max[1]) {
                max[1] = points[i][1];
            }
        }

        return [min, max] as Array< Array<Number or Float> >;
    }

    //! Draw the watch face background
    //! onUpdate uses this method to transfer newly rendered Buffered Bitmaps
    //! to the main display.
    //! onPartialUpdate uses this to blank the second hand from the previous
    //! second before outputting the new one.
    //! @param dc Device context
    private function drawBackground(dc as Dc) as Void {

        // If we have an offscreen buffer that has been written to
        // draw it to the screen.
        var offscreenBuffer = _offscreenBuffer;
        if (null != offscreenBuffer) {
            dc.drawBitmap(0, 0, offscreenBuffer);
        }

    }

    //! This method is called when the device re-enters sleep mode.
    //! Set the isAwake flag to let onUpdate know it should stop rendering the second hand.
    public function onEnterSleep() as Void {
        isAwake = false;
        Ui.requestUpdate();
    }

    //! This method is called when the device exits sleep mode.
    //! Set the isAwake flag to let onUpdate know it should render the second hand.
    public function onExitSleep() as Void {
        isAwake = true;
    }

    //! Turn off partial updates
    public function turnPartialUpdatesOff() as Void {
        _partialUpdatesAllowed = false;
    }
}

	//! Receives watch face events
	class AviatorlikeDelegate extends Ui.WatchFaceDelegate {
    private var _view as AviatorlikeView;

    //! Constructor
    //! @param view The analog view
    public function initialize(view as AviatorlikeView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    //! The onPowerBudgetExceeded callback is called by the system if the
    //! onPartialUpdate method exceeds the allowed power budget. If this occurs,
    //! the system will stop invoking onPartialUpdate each second, so we notify the
    //! view here to let the rendering methods know they should not be rendering a
    //! second hand.
    //! @param powerInfo Information about the power budget
    public function onPowerBudgetExceeded(powerInfo as WatchFacePowerInfo) as Void {
        System.println("Average execution time: " + powerInfo.executionTimeAverage);
        System.println("Allowed execution time: " + powerInfo.executionTimeLimit);
        _view.turnPartialUpdatesOff();
    }
}

