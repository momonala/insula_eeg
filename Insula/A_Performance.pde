int eighth_note_delay; // updated by the clock function
void play_eighth_note()
{   
    //delay(eighth_note_delay); 
    //beat.pause();
    //beat.play(); 
}


class Performance
{
    int tempo;  
    Boolean playing; 
    
    Performance()
    {
       count = 0; 
       playing = false;
       started = false; 
    }
     
    // used to time instruments to the dyanmic tempo 
    float time_to_trigger; 
    boolean started; 
    public void clock()
    {
      float now = millis();
      if(abs(now-time_to_trigger)<50 || !started)
      {    
          float bpms = (float)tempo/60000; 
          float mspb = 1/bpms; 
          int delay_val = (int)mspb;
          time_to_trigger = millis()+delay_val; 
          started = true; 
          
          //eighth_note_delay = delay_val/2; 
          //thread("play_eighth_note"); 
      }
    }
    
    // updates the tempo to the average bpm set up by the incoming ecg data 
    int count = 0;
    float first = 0; 
    float avg_bpm; 
    public void heart_beat_logged()
    {
        float now = millis();
        if(count == 0)
        {
            first = now; 
            count++; 
        }
        else
        {
            avg_bpm = 60000* count/(now-first); 
            count ++; 
        }
        tempo = (int)avg_bpm; 
    }
}