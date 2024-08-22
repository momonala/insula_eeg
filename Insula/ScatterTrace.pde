
//////////////////
//
// The ScatterTrace class is used to draw and manage the traces on each
// X-Y line plot created using gwoptics graphing library
//
// Created: Chip Audette, May 2014
//
// Based on examples in gwoptics graphic library v0.5.0
// http://www.gwoptics.org/processing/gwoptics_p5lib/
//
// Note that this class does NOT store any of the data used for the
// plot.  Instead, you point it to the data that lives in your
// own program.  In Java-speak, I believe that this is called
// "aliasing"...in this class, I have made an "alias" to your data.
// Some people consider this dangerous.  Because Processing is slow,
// this was one technique for making it faster.  By making an alias
// to your data, you don't need to pass me the data for every update
// and I don't need to make a copy of it.  Instead, once you update
// your data array, the alias in this class is already pointing to
// the right place.  Cool, huh?
//
////////////////


int alpha_chan = 1;
int heart_chan = 0;

//import processing.core.PApplet;
import org.gwoptics.graphics.*;
import org.gwoptics.graphics.graph2D.*;
import org.gwoptics.graphics.graph2D.Graph2D;
import org.gwoptics.graphics.graph2D.LabelPos;
import org.gwoptics.graphics.graph2D.traces.Blank2DTrace;
import org.gwoptics.graphics.graph2D.backgrounds.*;
import java.awt.Color;

class ScatterTrace extends Blank2DTrace {
  private float[] dataX;
  private float[][] dataY;
  private float plotYScale = 1f;  //multiplied to data prior to plotting
  private float plotYOffset[];  //added to data prior to plotting, after applying plotYScale
  private int decimate_factor = 1;  // set to 1 to plot all points, 2 to plot every other point, 3 for every third point
  private DataStatus[] is_railed;
  PFont font = createFont("Arial", 16);
  float[] plotXlim;

  public ScatterTrace() {
    //font = createFont("Arial",10);
    plotXlim = new float[] {
      Float.NaN, Float.NaN
    };
  }

  /* set the plot's X and Y data by overwriting the existing data */
  public void setXYData_byRef(float[] x, float[][] y) {
    //dataX = x.clone();  //makes a copy
    dataX = x;  //just copies the reference!
    setYData_byRef(y);
  }   

  public void setYData_byRef(float[][] y) {
    //dataY = y.clone(); //makes a copy
    dataY = y;//just copies the reference!
  }   

  public void setYOffset_byRef(float[] yoff) {
    plotYOffset = yoff;  //just copies the reference!
  }

  public void setYScale_uV(float yscale_uV) {
    setYScaleFac(1.0f/yscale_uV);
  }

  public void setYScaleFac(float yscale) {
    plotYScale = yscale;
  }

  public void set_plotXlim(float val_low, float val_high) {
    if (val_high < val_low) {
      float foo = val_low;
      val_low = val_high;
      val_high = foo;
    }
    plotXlim[0]=val_low;
    plotXlim[1]=val_high;
  }
  public void set_isRailed(DataStatus[] is_rail) {
    is_railed = is_rail;
  }

  //here is the fucntion that gets called with every call to the GUI's own draw() fucntion
  public void TraceDraw(Blank2DTrace.PlotRenderer pr) {
    float x_val;

    if (dataX.length > 0) {       
      pr.canvas.pushStyle();     
      int Ichan= heart_chan;
          pr.canvas.stroke(color(0));  //set the new line's color;
          
        float new_x = pr.valToX(dataX[0]);  //first point, convert from data coordinates to pixel coordinates
        float new_y = pr.valToY(dataY[Ichan][0]*plotYScale+plotYOffset[Ichan]);  //first point, convert from data coordinates to pixel coordinate
        float prev_x, prev_y;
        for (int i=1; i < dataY[Ichan].length; i+= decimate_factor) {
          prev_x = new_x;
          prev_y = new_y;
          x_val = dataX[i];
          if ( (Float.isNaN(plotXlim[0])) || ((x_val >= plotXlim[0]) && (x_val <= plotXlim[1])) ) {
            new_x = pr.valToX(x_val);
            new_y = pr.valToY(dataY[Ichan][i]*plotYScale+plotYOffset[Ichan]);
            pr.canvas.strokeWeight(1);
            pr.canvas.line(prev_x, prev_y, new_x, new_y);
            //if (i==1)  println("ScatterTrace: first point: new_x, new_y = " + new_x + ", " + new_y);
          } else {
            //do nothing
          }
        }


      }
      pr.canvas.popStyle(); //restore whatever was the previous style
  }

  public void setDecimateFactor(int val) {
    decimate_factor = max(1, val);
    //println("ScatterTrace: setDecimateFactor to " + decimate_factor);
  }
}


// /////////////////////////////////////////////////////////////////////////////////////////////
class ScatterTrace_FFT extends Blank2DTrace {
  private FFT[] fftData;
  private float plotYOffset[];
  private float[] plotXlim = new float[] {
    Float.NaN, Float.NaN
  };
  private float[] goodBand_Hz = {
    -1.0f, -1.0f
  };
  private float[] badBand_Hz = {
    -1.0f, -1.0f
  };
  private boolean showFFTFilteringData = false;
  private DetectionData_FreqDomain[] detectionData;
  private Oscil wave;

  public ScatterTrace_FFT() {
  }

  public ScatterTrace_FFT(FFT foo_fft[]) {
    setFFT_byRef(foo_fft);
    //    if (foo_fft.length != plotYOffset.length) {
    //      plotYOffset = new float[foo_fft.length];
    //    }
  }

  public void setFFT_byRef(FFT foo_fft[]) {
    fftData = foo_fft;//just copies the reference!
  }   

  public void setYOffset(float yoff[]) {
    plotYOffset = yoff;
  }
  public void set_plotXlim(float val_low, float val_high) {
    if (val_high < val_low) {
      float foo = val_low;
      val_low = val_high;
      val_high = foo;
    }
    plotXlim[0]=val_low;
    plotXlim[1]=val_high;
  }

  public void setGoodBand(float band_Hz[]) {
    for (int i=0; i<2; i++) { 
      goodBand_Hz[i]=band_Hz[i];
    };
  }
  public void setBadBand(float band_Hz[]) {
    for (int i=0; i<2; i++) { 
      badBand_Hz[i]=band_Hz[i];
    };
  }
  public void showFFTFilteringData(boolean show) {
    showFFTFilteringData = show;
  }
  public void setDetectionData_freqDomain(DetectionData_FreqDomain[] data) {
    detectionData = data.clone();
  }
  public void setAudioOscillator(Oscil wave_given) {
    wave = wave_given;
  }

  public void TraceDraw(Blank2DTrace.PlotRenderer pr) {
    float x_val, spec_value;

    //save whatever was the previous style
    pr.canvas.pushStyle();      

    if (fftData != null) {      

        //draw all the individual segments
      //for (int Ichan=0; Ichan < fftData.length; Ichan++) {
      int Ichan = alpha_chan;
        pr.canvas.stroke(color(0));  //set the new line's color;
            

        float new_x = pr.valToX(fftData[Ichan].indexToFreq(0));  //first point, convert from data coordinates to pixel coordinates
        float new_y = pr.valToY(fftData[Ichan].getBand(0)+plotYOffset[Ichan]);  //first point, convert from data coordinates to pixel coordinate
        float prev_x, prev_y;
        for (int i=1; i < fftData[Ichan].specSize (); i++) {
          prev_x = new_x;
          prev_y = new_y;
          x_val = fftData[Ichan].indexToFreq(i);
          //only plot those points that are within the frequency limits of the plot
          if ( (Float.isNaN(plotXlim[0])) || ((x_val >= plotXlim[0]) && (x_val <= plotXlim[1])) ) {
            new_x = pr.valToX(x_val);
            //spec_value = fftData[Ichan].getBand(i)/fftData[Ichan].specSize();  //uV_per_bin...this normalization is now done elsewhere
            spec_value = fftData[Ichan].getBand(i);
            new_y = pr.valToY(spec_value+plotYOffset[Ichan]);
            pr.canvas.strokeWeight(1);
            pr.canvas.line(prev_x, prev_y, new_x, new_y);
          } else {
            //do nothing
          } // end if Float.isNan
        }   //end of loop over spec size

      } // end loop over channels


      pr.canvas.popStyle(); //restore whatever was the previous style
  }

  float calcDesiredAudioFrequency(float excessSNR) {
    //set some constants
    final float excessSNRRange[] = { 
      1.0f, 3.0f
    };  //not dB, just linear units
    final float freqRange_Hz[] = {
      200.0f, 600.0f
    };

    //compute the desired snr
    float outputFreq_Hz = -1.0f;
    if (excessSNR >= excessSNRRange[0]) {
      excessSNR = constrain(excessSNR, excessSNRRange[0], excessSNRRange[1]);
      outputFreq_Hz = map(excessSNR, excessSNRRange[0], excessSNRRange[1], freqRange_Hz[0], freqRange_Hz[1]);
    }
    return outputFreq_Hz;
  }
};