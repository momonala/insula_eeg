Instrument ekg; 
Instrument alpha;
Instrument emg; 
Instrument in; 
Instrument out; 

class Features
{
  //phsyiological parameters (to be mapped to audiovisual parameters) 
  
  int heart_beat_logged;
  int alpha_magnitude; 
  int breath_value; // 0 for breathing in, 1 for breathing out
  //int muscle_intensity; 
  int alpha_waves_detected; 
  int heart_beat_count; 
  //Interface i; 
  
  Performance performance; 
  Features () {
    performance = new Performance(); 
    heart_beat_logged = 0;
    heart_beat_count = 0;
    int y = 40; 
    ekg = new Instrument(y,"EKG"); 
    alpha = new Instrument(y+110,"ALPHA"); 
    emg = new Instrument(y+110*2,"EMG");
    in = new Instrument(y+110*3,"IN");
    out = new Instrument(y+110*4,"OUT");
  } 
  
  public void draw(){
    ekg.draw(); 
    alpha.draw(); 
    emg.draw();
    in.draw(); 
    out.draw(); 
    
    if(heart_beat_count>3)
    {
      performance.clock(); 
    }
    
    if(heart_beat_logged==1)
    {
      performance.heart_beat_logged(); 
      ekg.play();
   
      heart_beat_count++;
    }
    reset_parameters();
  } 
  
  public void reset_parameters()
  {
    if(heart_beat_logged==1)
      heart_beat_logged=0;
  }
  
 
  public void extract_breath_rate(float value)
  {
  }
  
  public void listen_for_contractions(float value)
  { 
     //synth.play(); 
  }
  
  
  void update_brain_state(float freq,float magnitude)
  {
      //println("neural oscillation detected: frequency "+freq+ ", magnitude: " + magnitude);
      if(freq==0 && magnitude==0)
      {
        //brainwave = "no neural oscillations detected"; 
        
        if(alpha.isPlaying)
        {
          alpha.pause(); 
        }
      }
      else if(freq>7 && freq<12) // means we're in the alpha range 
      {
        //brainwave = "neural oscillations detected at "+freq+" with magnitude "+magnitude+" -> classified as alpha activity"; 
        if(!alpha.isPlaying)
        {
           alpha.play(); 
        }
      }
      else
      {
         //brainwave = "neural oscillations detected at "+freq+" with magnitude "+magnitude+" -> classified as theta rhythm"; 
        
         alpha.pause();
      }
  }
  
   /* ekg analysis (written by sam) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */ 

   int count =0 ;
   int position =0; 
   int currentSampleIndex = 0;
   int lastBeatIndex = 0;
   float thresh = 0;
   float ecg_Value_uV = 0;
   float P = 0; // p is the peak of the last heart beat in microvolts 
   float T = 0; // t is the lowest point since the last heart beat (volts) 
   float amp = 0; //distance between p and t 
   int N = 0; // n is the number of data points since the last beat
   int IBI = 90; // interbeat interval - the distance between heart beats in terms of data points 
   boolean pulse = false; 
   int ecgChan = 0; //channel number - 1 b/c index starts at 0
   boolean past_threshold = false; 
  
  public void extract_heart_rate(float value)
  {   
      //println(value);
      float ecg_Value_uV = value;
      currentSampleIndex++;    //set current sample Index
      N = currentSampleIndex - lastBeatIndex;    //get num samples since last beat (temperary IBI)
      //now finding the peack and trough of the pulse
          
      //trough
      if((ecg_Value_uV < thresh) && (N >(3/5)*IBI)){   //if signal < threshold and current time since last beat is > 3/5*IBI
         if(ecg_Value_uV < T){
            T = ecg_Value_uV;    //keeping track of the lowest point (the trough)
            //println("found trough");
         }
      }
          
      //peak
      if((ecg_Value_uV > thresh) && (ecg_Value_uV > P) && (N >(3/5)*IBI) ){
          P = ecg_Value_uV;
          //println("found new peak");
      }
          
      //now time to look for a beat
      if(N > 100){        //first check if N > 90 data points (equates to ~160bpm), gets rid of high freq noise

            if((ecg_Value_uV > thresh) && (pulse == false) && (N > 3*IBI/5))
            {
              pulse = true;      //flag that pulse found
              IBI = currentSampleIndex - lastBeatIndex;    //set IBI
              lastBeatIndex = currentSampleIndex;      //set new beat index to current sample index
              
              heart_beat_logged = 1; 

            }
      }
          
      if((ecg_Value_uV < thresh) && (pulse == true)){      //if wave is falling (ie there was a beat and now its back below threshold
            pulse = false;
            amp = P - T; 
            thresh = amp/1.25 + T;     //thresh = half of amp + DC offset (effectively)
            //println("thresh = " + thresh + " P and T: " + P + " " + T );
            P = thresh;          //resent P and T
            T = thresh;
      }
          
      if (N > 750){    //if no beats for 3 seconds
            //Reset thresh, T and P
            thresh = 0;
            T =0;
            P = 0;
            lastBeatIndex = currentSampleIndex;     //bring time of last beat up to date
      }
  }
  
  
  
}