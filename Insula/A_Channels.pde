/*
this tab is responsible for accessing the raw data for each channel and preparing to send to the Features class for feature extraction 
convention: 
1. ekg (chest)
2. eeg (frontal lobe)
3. eeg (right occipital)
4. eeg (left occipital)
5. emg (left forearm) 
6. em (left bicep)
7. breath
*/

class Channels {
  
  /* specify channels */
  int heart_rate_channel = 0; 
  int alpha_channel = 1;
  
  //private int nchan;  
  float acceptableLimitUV = 255;  //uV values above this limit are excluded, as a result of them almost certainly being noise...
  Features features; 
  
  Channels() 
  {
    features = new Features();
    detectedPeak = new DetectedPeak(); 
    alpha_channel = 1;
    heart_rate_channel = 0; 
    if(skip_setup)
    {
      heart_rate_channel = 3;
      heart_chan = 3;
    }
  }
  
  int delay_count = 0;
  int prev; 
  int current=0;
  //from arduino
  public void parse_arduino_messages(String message) 
  {
    //println("parsing arduino message"); 
    float value;
    int val; 
    //println("arduino: "+ message); 
    if (message.charAt(0) == 'B' && message.charAt(1)=='B')  // b for breath
    {         
        message = message.substring(2);        
        value = float(message);    
        val = (int)value; 
        //println("breath value: "+val); 
        if(val!=current)
        {  
          current = val;
          if(val==0)
          {  
             in.play(); 
             out.pause(); 
          }
          else
          {
            out.play(); 
            in.pause(); 
          }
        }
        
    }
    if (message.charAt(0) == 'M')  // m for emg
    {         
        message = message.substring(1);        
        value = float(message); 
        val = (int)value;
        
        if(val>=emg.threshold.getValue())
        {
            if(delay_count>emg.rhythm.getValue())
           {
             emg.pause();
            emg.play(); 
             delay_count = 0; 
          }
        }
        //println("muscle value: "+value);
        delay_count++; 
         
       
    }
    if (message.charAt(0) == 'P')  // 
    {         
        message = message.substring(1);      
        //output(message);
        
        
    }
    
  }
  
  public void process(float[][] data_newest_uV, float[][] data_forDisplay_uV, ddf.minim.analysis.FFT[] fftData) 
  {         
    find_brain_state(fftData);
    // time-domain processing~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    float value; 
   
    //heart rate~~~~~~~~~~~~~~~~~~~~~~~
    int indexOfNewData = data_forDisplay_uV[heart_rate_channel].length - data_newest_uV[heart_rate_channel].length;
    for (int Isamp=indexOfNewData; Isamp < data_forDisplay_uV[heart_rate_channel].length; Isamp++) 
    {
        value = data_forDisplay_uV[heart_rate_channel][Isamp]; 
        features.extract_heart_rate(value); /* send values to sam's algorithm for finding the heart rate */ 
    }    
  }
  
  final float detection_thresh_dB = 8.0f; //how much bigger must the peak be relative to the background
  final float min_allowed_peak_freq_Hz = 4.5f; //was 4.0f, input, for peak frequency detection
  final float max_allowed_peak_freq_Hz = 15.0f; //was 15.0f, input, for peak frequency detection
  final float[] processing_band_low_Hz = {
    4.0, 6.5, 9, 13.5
  }; //lower bound for each frequency band of interest (2D classifier only)
  final float[] processing_band_high_Hz = {
    6.5, 9, 12, 16.5
  };  //upper bound for each frequency band of interest
  DetectedPeak detectedPeak;  //output per channel, from peak frequency detection
  
  public void find_brain_state( 
  ddf.minim.analysis.FFT[] fftData) {              

    findPeakFrequency(fftData, alpha_channel); //find the frequency for each channel with the peak amplitude
    if (detectedPeak.SNR_dB >= detection_thresh_dB/2) {
      features.update_brain_state(detectedPeak.freq_Hz,detectedPeak.SNR_dB);
      if (detectedPeak.freq_Hz < processing_band_high_Hz[2-1]) {
      } else if (detectedPeak.freq_Hz < processing_band_high_Hz[3-1]) {
        
      } else if (detectedPeak.freq_Hz < processing_band_high_Hz[4-1]) {
        
      }
    }
    else
    {
      features.update_brain_state(0,0);
    }
  }


  //add some functions here...if you'd like
  void findPeakFrequency(ddf.minim.analysis.FFT[] fftData, int Ichan) {

    //loop over each EEG channel and find the frequency with the peak amplitude
    float FFT_freq_Hz, FFT_value_uV;
    //for (int Ichan=0;Ichan < nchan; Ichan++) {

    //clear the data structure that will hold the peak for this channel
    detectedPeak.clear();

    //loop over each frequency bin to find the one with the strongest peak
    int nBins =  fftData[Ichan].specSize();
    for (int Ibin=0; Ibin < nBins; Ibin++) {
      FFT_freq_Hz = fftData[Ichan].indexToFreq(Ibin); //here is the frequency of htis bin

        //is this bin within the frequency band of interest?
      if ((FFT_freq_Hz >= min_allowed_peak_freq_Hz) && (FFT_freq_Hz <= max_allowed_peak_freq_Hz)) {
        //we are within the frequency band of interest

        //get the RMS voltage (per bin)
        FFT_value_uV = fftData[Ichan].getBand(Ibin) / ((float)nBins); 

        //decide if this is the maximum, compared to previous bins for this channel
        if (FFT_value_uV > detectedPeak.rms_uV_perBin) {
          //this is bigger, so hold onto this value as the new "maximum"
          detectedPeak.bin  = Ibin;
          detectedPeak.freq_Hz = FFT_freq_Hz;
          detectedPeak.rms_uV_perBin = FFT_value_uV;
        }
      } //close if within frequency band
    } //close loop over bins

    //loop over the bins again (within the sense band) to get the average background power, excluding the bins on either side of the peak
    float sum_pow=0.0;
    int count=0;
    for (int Ibin=0; Ibin < nBins; Ibin++) {
      FFT_freq_Hz = fftData[Ichan].indexToFreq(Ibin);
      if ((FFT_freq_Hz >= min_allowed_peak_freq_Hz) && (FFT_freq_Hz <= max_allowed_peak_freq_Hz)) {
        if ((Ibin < detectedPeak.bin - 1) || (Ibin > detectedPeak.bin + 1)) {
          FFT_value_uV = fftData[Ichan].getBand(Ibin) / ((float)nBins);  //get the RMS per bin
          sum_pow+=pow(FFT_value_uV, 2.0f);
          count++;
        }
      }
    }
    //compute mean
    detectedPeak.background_rms_uV_perBin = sqrt(sum_pow / count);

    //decide if peak is big enough to be detected
    detectedPeak.SNR_dB = 20.0f*(float)java.lang.Math.log10(detectedPeak.rms_uV_perBin / detectedPeak.background_rms_uV_perBin);

  } //end method findPeakFrequency

  public void draw(){
    features.draw();
    
    
  }

}


class DetectedPeak { 
  int bin;
  float freq_Hz;
  float rms_uV_perBin;
  float background_rms_uV_perBin;
  float SNR_dB;
  boolean isDetected;
  float threshold_dB;

  DetectedPeak() {
    clear();
  }

  void clear() {
    bin=0;
    freq_Hz = 0.0f;
    rms_uV_perBin = 0.0f;
    background_rms_uV_perBin = 0.0f;
    SNR_dB = -100.0f;
    isDetected = false;
    threshold_dB = 0.0f;
  }

  void copyTo(DetectedPeak target) {
    target.bin = bin;
    target.freq_Hz = freq_Hz;
    target.rms_uV_perBin = rms_uV_perBin;
    target.background_rms_uV_perBin = background_rms_uV_perBin;
    target.SNR_dB = SNR_dB;
    target.isDetected = isDetected;
    target.threshold_dB = threshold_dB;
  }
}