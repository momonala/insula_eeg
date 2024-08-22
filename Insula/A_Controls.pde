int EKG_octave; 
int ALPHA_octave; 
int EMG_octave; 
int IN_octave;
int OUT_octave; 
int delay = 10;

void stop_all_notes()
{
    ekg.pause_all(); 
    alpha.pause_all();
    emg.pause_all(); 
    in.pause_all(); 
    out.pause_all(); 
    
    println("all of the notes should have stopped");
    
}

class Instrument
{
    Knob volume;
    Keys keyboard;
    Slider octave; 
    Slider threshold;
    Slider rhythm; 
    
    MidiBus midi_bus; 
    public boolean isPlaying;
    
    int color_delay = 10; 
    
    Instrument(int y,String bus_iac)  
    {   
        midi_bus = new MidiBus(this, 0, bus_iac);  
        
        String knob_label = bus_iac+" volume"; 
        volume = controlp5.addKnob(knob_label,0,127,100,600,y-35,90);
        volume.setColorForeground(color(220));
        volume.setColorBackground(color(250));
        volume.setColorActive(color(240));
        volume.setColorValueLabel(255) ;
        volume.setColorCaptionLabel(color(0)) ;
        
        
        String octave_label = bus_iac+"_octave";
        octave = controlp5.addSlider(octave_label,0,8,4,700,y-30,150,20);
        octave.setColorForeground(color(220));
        octave.setColorBackground(color(255));
        octave.setColorActive(color(240));
        octave.setColorValueLabel(255) ;
        octave.setColorCaptionLabel(color(0)) ;
        
        String threshold_label = bus_iac+" threshold";
        if(bus_iac == "EMG")
        {
          threshold = controlp5.addSlider(threshold_label,0,1024,500,980,y-30,150,20);
          threshold.setColorForeground(color(220));
          threshold.setColorBackground(color(255));
          threshold.setColorActive(color(240));
          threshold.setColorValueLabel(255) ;
          threshold.setColorCaptionLabel(color(0)) ;
          
          
          rhythm = controlp5.addSlider("emg delay",0,50,10,980,y-30+110,150,20);
          rhythm.setColorForeground(color(220));
          rhythm.setColorBackground(color(255));
          rhythm.setColorActive(color(240));
          rhythm.setColorValueLabel(255) ;
          rhythm.setColorCaptionLabel(color(0)) ;
          
          
        }

        keyboard = new Keys(700,y,40,60);
        
        isPlaying = false; 
    }
    
    void initialize_keys()
    {
        
    }
    
    public void pause_all()
    {
        for(int i = 0 ; i<128; i++)
        {
            midi_bus.sendNoteOff(0, i, 0); 
        }
       
    }
    
    public void play()
    {
        isPlaying = true; 
        //turn off all midi notes 
        for(int i = 0 ; i<128; i++)
        {
         //   midi_bus.sendNoteOff(0, i, 0); 
        }
        
        
        int o = (int) octave.getValue(); 
        for(int i = 0; i < keyboard.midi_notes.size(); i++)
        {
            midi_bus.sendNoteOn(0, keyboard.midi_notes.get(i)+o*12, (int)volume.getValue()); 
        }
        color_delay = 0; 
        //midi_bus.sendControllerChange(0, 7, (int)volume.getValue());
        
    }
    
    public void update_volume(int vol) // passed integer between 0 and 127
    {
        midi_bus.sendControllerChange(0, 7, vol);
    }
    
    public void pause()
    {
        if(!isPlaying) return; 
        isPlaying = false; 
        int o = (int)octave.getValue(); 
        for(int i = 0; i < keyboard.midi_notes.size(); i++)
        {
            midi_bus.sendNoteOff(0, keyboard.midi_notes.get(i)+o*12, (int)volume.getValue()); 
        } 
    } 
    
    void draw()
    {
       volume.setColorBackground(color(250));
       if(color_delay<9)
       {  
         volume.setColorBackground(color(230));
         color_delay++;
       }
        
       keyboard.draw(); 
    }
    
    public void mousePressed() 
    {  
        keyboard.mousePressed(); 
    }
}

boolean overRect(Key k)  {
  if (mouseX >= k.x && mouseX <= k.x+k.w && 
      mouseY >= k.y && mouseY <= k.y+k.h) {
    return true;
  } else {
    return false;
  }
}

class Keys 
{
  int x_pos;
  int y_pos; 
  
  int key_width;
  int key_height;
  
  Key [] white_keys;
  Key [] black_keys;
  
  IntList midi_notes = new IntList();
 
  Keys(int x, int y, int w, int h)
  {  
    x_pos = x; 
    y_pos = y; 
    key_width = w; 
    key_height = h; 
    
    white_keys = new Key[14]; 
    black_keys = new Key[10];
    
    white_keys[0] = new Key(x_pos+key_width*0,y_pos,key_width,key_height,"C",0);
    white_keys[1] = new Key(x_pos+key_width*1,y_pos,key_width,key_height,"D",2);
    white_keys[2] = new Key(x_pos+key_width*2,y_pos,key_width,key_height,"E",4);
    white_keys[3] = new Key(x_pos+key_width*3,y_pos,key_width,key_height,"F",5);
    white_keys[4] = new Key(x_pos+key_width*4,y_pos,key_width,key_height,"G",7);
    white_keys[5] = new Key(x_pos+key_width*5,y_pos,key_width,key_height,"A",9);
    white_keys[6] = new Key(x_pos+key_width*6,y_pos,key_width,key_height,"B",11);
    white_keys[7] = new Key(x_pos+key_width*7,y_pos,key_width,key_height,"C",12);
    white_keys[8] = new Key(x_pos+key_width*8,y_pos,key_width,key_height,"D",14);
    white_keys[9] = new Key(x_pos+key_width*9,y_pos,key_width,key_height,"E",16);
    white_keys[10] = new Key(x_pos+key_width*10,y_pos,key_width,key_height,"F",17);
    white_keys[11] = new Key(x_pos+key_width*11,y_pos,key_width,key_height,"G",19);
    white_keys[12] = new Key(x_pos+key_width*12,y_pos,key_width,key_height,"A",21);
    white_keys[13] = new Key(x_pos+key_width*13,y_pos,key_width,key_height,"B",23);
  
    black_keys[0] = new Key(x_pos+key_width*1-key_width/6,y_pos,key_width/3,key_height/2,"C_SHARP",1);
    black_keys[1] = new Key(x_pos+key_width*2-key_width/6,y_pos,key_width/3,key_height/2,"E_FLAT",3);
    black_keys[2] = new Key(x_pos+key_width*4-key_width/6,y_pos,key_width/3,key_height/2,"F_SHARP",6);
    black_keys[3] = new Key(x_pos+key_width*5-key_width/6,y_pos,key_width/3,key_height/2,"A_FLAT",8);
    black_keys[4] = new Key(x_pos+key_width*6-key_width/6,y_pos,key_width/3,key_height/2,"B_FLat",10);
    black_keys[5] = new Key(x_pos+key_width*8-key_width/6,y_pos,key_width/3,key_height/2,"C_SHARP",13);
    black_keys[6] = new Key(x_pos+key_width*9-key_width/6,y_pos,key_width/3,key_height/2,"E_FLAT",15);
    black_keys[7] = new Key(x_pos+key_width*11-key_width/6,y_pos,key_width/3,key_height/2,"F_SHARP",18);
    black_keys[8] = new Key(x_pos+key_width*12-key_width/6,y_pos,key_width/3,key_height/2,"A_FLAT",20);
    black_keys[9] = new Key(x_pos+key_width*13-key_width/6,y_pos,key_width/3,key_height/2,"B_FLat",22);
    
  }
  
  public void draw()
  {  
      
      for(int i = 0; i < 14; i++)
      {   
          fill(255);
          white_keys[i].draw(); 
      
      }
      
      for(int i = 0; i < 10; i++)
      {
        fill(0); 
        black_keys[i].draw(); 
      
      }
     
  }
   
 public void update_midi_notes()
 {
    midi_notes.clear(); 
    for(int i = 0; i < 14; i++)
    {    
          if(white_keys[i].selected)
            midi_notes.append(white_keys[i].midi_note); 
      
    }
      
    for(int i = 0; i < 10; i++)
    {
          if(black_keys[i].selected)
            midi_notes.append(black_keys[i].midi_note);
      
    }
    
 }
 
   public void mousePressed() 
   {
  
      for(int j=0; j<10; j++) // check black keys first 
      {
         if(overRect(black_keys[j]))
         {
           if(black_keys[j].selected)
              black_keys[j].selected = false; 
           else  
               black_keys[j].selected = true; 
               
           update_midi_notes(); 
           return; 
         }
      }
  
      for(int i=0; i<14; i++)
      {
         if(overRect(white_keys[i]))
         {
             if(white_keys[i].selected)  
               white_keys[i].selected = false; 
             else
               white_keys[i].selected = true;
               
             update_midi_notes(); 
             return; 
         }
      }
   }  
   
 
}

class Key
{
    public int x;
    public int y;
    public int w; 
    public int h;
    
    public String name; 
    
    public int midi_note; 
    public boolean selected; 
   
    
    Key(int _x, int _y, int _w, int _h, String _name, int _midi_note )
    {
      x = _x;
      y = _y; 
      w = _w; 
      h = _h;
      name = _name; 
      midi_note = _midi_note; 
    }
    
    public void draw()
    {  
      stroke(0);
      if(selected)
      {
         fill(150); 
      }
      rect(x,y,w,h);
    }
}