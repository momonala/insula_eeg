import ddf.minim.analysis.*; 
import ddf.minim.ugens.*;  
import java.lang.Math; 
import processing.core.PApplet;
import java.util.*;
import java.util.Map.Entry;
import processing.serial.*;  
import java.awt.event.*; 

import themidibus.*;

/*
insula variables: 
===============================================================================
*/

boolean hide_gui_elements = true; 
boolean fft_mode = true; 
boolean graph_mode = true; 
boolean reading_arduino = true; 
int background_color = color(255); 
boolean hide_channel_controller = false; 
boolean skip_setup = true; 
String playback_file = "data/file.csv"; 
boolean channels_set = false; 
ControlP5 controlp5;

/*
===============================================================================
*/








boolean isVerbose = false; //set true if you want more verbosity in console.. verbosePrint("print_this_thing") is used to output feedback when isVerbose = true

//used to switch between application states
int systemMode = 0; /* Modes: 0 = system stopped/control panel setings / 10 = gui / 20 =  guide */

//choose where to get the EEG data
final int DATASOURCE_NORMAL = 3;  //looking for signal from OpenBCI board via Serial/COM port, no Aux data
final int DATASOURCE_PLAYBACKFILE = 1;  //playback from a pre-recorded text file
final int DATASOURCE_SYNTHETIC = 2;  //Synthetically generated data
final int DATASOURCE_NORMAL_W_AUX = 0; // new default, data from serial with Accel data CHIP 2014-11-03
public int eegDataSource = -1; //default to none of the options

//Serial communications constants
OpenBCI_ADS1299 openBCI = new OpenBCI_ADS1299(); //dummy creation to get access to constants, create real one later
String openBCI_portName = "N/A";  //starts as N/A but is selected from control panel to match your OpenBCI USB Dongle's serial/COM
int openBCI_baud = 115200; //baud rate from the Arduino

//here are variables that are used if loading input data from a CSV text file...double slash ("\\") is necessary to make a single slash
String playbackData_fname = playback_file; //only used if loading input data from a file

float playback_speed_fac = 1.0f;  //make 1.0 for real-time.  larger for faster playback
int currentTableRowIndex = 0;
Table_CSV playbackData_table;
int nextPlayback_millis = -100; //any negative number

// boolean printingRegisters = false;

// define some timing variables for this program's operation
long timeOfLastFrame = 0;
int newPacketCounter = 0;
long timeOfInit;
long timeSinceStopRunning = 1000;
int prev_time_millis = 0;
final int nPointsPerUpdate = 50; //update the GUI after this many data points have been received 

/////Define variables related to OpenBCI board operations
//define number of channels from openBCI...first EEG channels, then aux channels
int nchan = 8; //Normally, 8 or 16.  Choose a smaller number to show fewer on the GUI
int n_aux_ifEnabled = 3;  // this is the accelerometer data CHIP 2014-11-03

//define variables related to warnings to the user about whether the EEG data is nearly railed (and, therefore, of dubious quality)
DataStatus is_railed[];
final int threshold_railed = int(pow(2, 23)-1000);  //fully railed should be +/- 2^23, so set this threshold close to that value
final int threshold_railed_warn = int(pow(2, 23)*0.75); //set a somewhat smaller value as the warning threshold

//OpenBCI SD Card setting (if eegDataSource == 0)
int sdSetting = 0; //0 = do not write; 1 = 5 min; 2 = 15 min; 3 = 30 min; etc...
String sdSettingString = "Do not write to SD";

//openBCI data packet
final int nDataBackBuff = 3*(int)openBCI.get_fs_Hz();
DataPacket_ADS1299 dataPacketBuff[] = new DataPacket_ADS1299[nDataBackBuff]; //allocate the array, but doesn't call constructor.  Still need to call the constructor!
int curDataPacketInd = -1;
int lastReadDataPacketInd = -1;

//related to sync'ing communiction to OpenBCI hardware?
boolean currentlySyncing = false;
long timeOfLastCommand = 0;

////// End variables related to the OpenBCI boards

//define some data fields for handling data here in processing
float dataBuffX[];  //define the size later
float dataBuffY_uV[][]; //2D array to handle multiple data channels, each row is a new channel so that dataBuffY[3][] is channel 4
float dataBuffY_filtY_uV[][];
float yLittleBuff[] = new float[nPointsPerUpdate];
float yLittleBuff_uV[][] = new float[nchan][nPointsPerUpdate]; //small buffer used to send data to the filters
float data_elec_imp_ohm[];

//variables for writing EEG data out to a file
OutputFile_rawtxt fileoutput;
String output_fname;
String fileName = "N/A";

//create objects that'll do the EEG signal processing
EEG_Processing eegProcessing;
Channels channels;

// Serial output
String serial_output_portName = "/dev/tty.usbmodem1411";  //must edit this based on the name of the serial/COM port
Serial serial_output;
int serial_output_baud = 115200; //baud rate from the Arduino

//fft constants
int Nfft = 256; //set resolution of the FFT.  Use N=256 for normal, N=512 for MU waves
FFT fftBuff[] = new FFT[nchan];   //from the minim library
float[] smoothFac = new float[]{0.75, 0.9, 0.95, 0.98, 0.0, 0.5};
int smoothFac_ind = 0;    //initial index into the smoothFac array

//plotting constants
color bgColor = color(255);
Gui_Manager gui;
float default_vertScale_uV = 200.0f;  //used for vertical scale of time-domain montage plot and frequency-domain FFT plot
float displayTime_sec = 5f;    //define how much time is shown on the time-domain montage plot (and how much is used in the FFT plot?)
float dataBuff_len_sec = displayTime_sec+3f; //needs to be wider than actual display so that filter startup is hidden

//Control Panel for (re)configuring system settings
ControlPanel controlPanel;
Button controlPanelCollapser;
PlotFontInfo fontInfo;
int navBarHeight = 32;

//program constants
boolean isRunning=false;
boolean redrawScreenNow = true;
int openBCI_byteCount = 0;
int inByte = -1;    // Incoming serial data

// Widget initiation

//for screen resizing
boolean screenHasBeenResized = false;
float timeOfLastScreenResize = 0;
float timeOfGUIreinitialize = 0;
int reinitializeGUIdelay = 125;

//set window size
int win_x = 1024;  //window width
int win_y = 768; //window height

PImage logo;

PFont f1;
PFont f2;
PFont f3;

//========================SETUP============================//
//========================SETUP============================//
//========================SETUP============================//

void add_button()
{
    controlp5.addBang("bang")
       .setPosition(1200, 30)
       .setSize(40, 40)
       .setId(0)
       .setColorForeground(160)
       .setCaptionLabel("initialize arduino") 
       ;
}

public void bang() {
  initialize_arduino();
  controlp5.addBang("bang")
       .setPosition(1200, 30)
       .setSize(40, 40)
       .setId(0)
       .setColorForeground(160)
       .setCaptionLabel("initialize arduino") 
       .setVisible(false)
       ;
}


Serial port;
void initialize_arduino()
{
  String [] ports = Serial.list();    // print a list of available serial ports
  for(int i = 0 ; i< ports.length; i++)
  {
      String sub = ports[i].substring(0,20);
      println(sub); 
      if(sub.equals("/dev/cu.wchusbserial")) //20
      {
         port = new Serial(this, ports[i], 115200);
         port.clear();            // flush buffer
         port.bufferUntil('\n'); 
         println("arduino successfully initialized");
         break; 
      }
  }
 // port = new Serial(this, "/dev/cu.wchusbserial1410", 115200); 
  // make sure Arduino is talking serial at this baud rate
  //port.clear();            // flush buffer
  //port.bufferUntil('\n'); 
  //println("arduino successfully initialized");

}

void setup() {
  controlp5  = new ControlP5(this); 
  channels = new Channels();
  add_button();
  
  println("Welcome to the Processing-based OpenBCI GUI!"); //Welcome line.
  println("Last update: 2/16/2016"); //Welcome line.
  println("For more information about how to work with this code base, please visit: http://docs.openbci.com/tutorials/01-GettingStarted");
  println("For specific questions, please post them to the Software section of the OpenBCI Forum: http://openbci.com/index.php/forum/#/categories/software");
  //open window
  size(displayWidth, displayHeight, P2D);
  frameRate(30); //refresh rate ... this will slow automatically, if your processor can't handle the specified rate
  smooth(); //turn this off if it's too slow

  //surface.setResizable(true);  //updated from frame.setResizable in Processing 2

  //V1 FONTS
  f1 = createFont("fonts/Raleway-SemiBold.otf", 16);
  f2 = createFont("fonts/Raleway-Regular.otf", 15);
  f3 = createFont("fonts/Raleway-SemiBold.otf", 15);

  //listen for window resize ... used to adjust elements in application
  frame.addComponentListener(new ComponentAdapter() { 
    public void componentResized(ComponentEvent e) { 
      if (e.getSource()==frame) { 
        println("OpenBCI_GUI: setup: RESIZED");
        screenHasBeenResized = true;
        timeOfLastScreenResize = millis();
        // initializeGUI();
      }
    }
  }
  );

  //set up controlPanelCollapser button
  fontInfo = new PlotFontInfo();

  controlPanelCollapser = new Button(2, 2, 256, 26, "SYSTEM CONTROL PANEL", fontInfo.buttonLabel_size);

  controlPanelCollapser.setIsActive(true);
  controlPanelCollapser.makeDropdownButton(true);

  //from the user's perspective, the program hangs out on the ControlPanel until the user presses "Start System".
  print("Graphics & GUI Library: ");
  controlPanel = new ControlPanel(this);  
  //The effect of "Start System" is that initSystem() gets called, which starts up the conneciton to the OpenBCI
  //hardware (via the "updateSyncState()" process) as well as initializing the rest of the GUI elements.  
  //Once the hardware is synchronized, the main GUI is drawn and the user switches over to the main GUI.

  logo = loadImage("logo2.png");

  //attempt to open a serial port for "output"
  try {
    verbosePrint("OpenBCI_GUI.pde:  attempting to open serial port for data output = " + serial_output_portName);
    serial_output = new Serial(this, serial_output_portName, serial_output_baud); //open the com port
    serial_output.clear(); // clear anything in the com port's buffer
  } 
  catch (RuntimeException e) {
    verbosePrint("OpenBCI_GUI.pde: *** ERROR ***: Could not open " + serial_output_portName);
  }
  
  if(skip_setup)
  {
    initSystem();
    startRunning();
    
  }
  
}
//====================== END--OF ==========================//
//========================SETUP============================//
//========================SETUP============================//

int pointCounter = 0;
int prevBytes = 0; 
int prevMillis=millis();
int byteRate_perSec = 0;
int drawLoop_counter = 0;

//used to init system based on initial settings...Called from the "Start System" button in the GUI's ControlPanel
void initSystem() {
  
  println("ORDERING: init system function called");

  verbosePrint("OpenBCI_GUI: initSystem: -- Init 0 --");
  timeOfInit = millis(); //store this for timeout in case init takes too long

  //prepare data variables
  verbosePrint("OpenBCI_GUI: initSystem: Preparing data variables...");
  dataBuffX = new float[(int)(dataBuff_len_sec * openBCI.get_fs_Hz())];
  dataBuffY_uV = new float[nchan][dataBuffX.length];
  dataBuffY_filtY_uV = new float[nchan][dataBuffX.length];
  data_elec_imp_ohm = new float[nchan];
  is_railed = new DataStatus[nchan];
  for (int i=0; i<nchan; i++) is_railed[i] = new DataStatus(threshold_railed, threshold_railed_warn);
  for (int i=0; i<nDataBackBuff; i++) { 
    dataPacketBuff[i] = new DataPacket_ADS1299(nchan, n_aux_ifEnabled);
  }
  eegProcessing = new EEG_Processing(nchan, openBCI.get_fs_Hz());

  //initialize the data
  prepareData(dataBuffX, dataBuffY_uV, openBCI.get_fs_Hz());

  verbosePrint("OpenBCI_GUI: initSystem: -- Init 1 --");

  //initialize the FFT objects
  for (int Ichan=0; Ichan < nchan; Ichan++) { 
    verbosePrint("a--"+Ichan);
    fftBuff[Ichan] = new FFT(Nfft, openBCI.get_fs_Hz());
  };  //make the FFT objects
  verbosePrint("OpenBCI_GUI: initSystem: b");
  initializeFFTObjects(fftBuff, dataBuffY_uV, Nfft, openBCI.get_fs_Hz());

  verbosePrint("OpenBCI_GUI: initSystem: -- Init 2 --");
  
  if(skip_setup)
  {
     eegDataSource = DATASOURCE_PLAYBACKFILE; 
  }
  //prepare the source of the input data
  switch (eegDataSource) {
  case DATASOURCE_NORMAL: 
  case DATASOURCE_NORMAL_W_AUX:

    int nEEDataValuesPerPacket = nchan;
    boolean useAux = false;
    if (eegDataSource == DATASOURCE_NORMAL_W_AUX) useAux = true;  //switch this back to true CHIP 2014-11-04
    openBCI = new OpenBCI_ADS1299(this, openBCI_portName, openBCI_baud, nEEDataValuesPerPacket, useAux, n_aux_ifEnabled); //this also starts the data transfer after XX seconds
    break;
  case DATASOURCE_SYNTHETIC:
    //do nothing
    break;
  case DATASOURCE_PLAYBACKFILE:
    //open and load the data file
    println("OpenBCI_GUI: initSystem: loading playback data from " + playbackData_fname);
    try {
      playbackData_table = new Table_CSV(playbackData_fname);
    } 
    catch (Exception e) {
      println("OpenBCI_GUI: initSystem: could not open file for playback: " + playbackData_fname);
      println("   : quitting...");
      exit();
    }
    println("OpenBCI_GUI: initSystem: loading complete.  " + playbackData_table.getRowCount() + " rows of data, which is " + round(float(playbackData_table.getRowCount())/openBCI.get_fs_Hz()) + " seconds of EEG data");

    //removing first column of data from data file...the first column is a time index and not eeg data
    playbackData_table.removeColumn(0);
    break;
  default:
  }

  verbosePrint("OpenBCI_GUI: initSystem: -- Init 3 --");

  //initilize the GUI
  initializeGUI();
  verbosePrint("OpenBCI_GUI: initSystem: -- Init 4 --");

  //open data file
  if ((eegDataSource == DATASOURCE_NORMAL) || (eegDataSource == DATASOURCE_NORMAL_W_AUX)) openNewLogFile(fileName);  //open a new log file

  nextPlayback_millis = millis(); //used for synthesizeData and readFromFile.  This restarts the clock that keeps the playback at the right pace.

  if (eegDataSource != DATASOURCE_NORMAL && eegDataSource != DATASOURCE_NORMAL_W_AUX) {
    systemMode = 10; //tell system it's ok to leave control panel and start interfacing GUI
  }
  
  //if(reading_arduino)
  //  initialize_arduino(); 
}

//so data initialization routines
void prepareData(float[] dataBuffX, float[][] dataBuffY_uV, float fs_Hz) {
  //initialize the x and y data
  int xoffset = dataBuffX.length - 1;
  for (int i=0; i < dataBuffX.length; i++) {
    dataBuffX[i] = ((float)(i-xoffset)) / fs_Hz; //x data goes from minus time up to zero
    for (int Ichan = 0; Ichan < nchan; Ichan++) { 
      dataBuffY_uV[Ichan][i] = 0f;  //make the y data all zeros
    }
  }
}

void initializeFFTObjects(FFT[] fftBuff, float[][] dataBuffY_uV, int N, float fs_Hz) {

  float[] fooData;
  for (int Ichan=0; Ichan < nchan; Ichan++) {
    fftBuff[Ichan].window(FFT.HAMMING);
    fooData = dataBuffY_uV[Ichan];
    fooData = Arrays.copyOfRange(fooData, fooData.length-Nfft, fooData.length); 
    fftBuff[Ichan].forward(fooData); //compute FFT on this channel of data
  }
}

//halt the data collection
void haltSystem() {
  println("openBCI_GUI: haltSystem: Halting system for reconfiguration of settings...");
  stopRunning();  //stop data transfer

  //reset variables for data processing
  curDataPacketInd = -1;
  lastReadDataPacketInd = -1;
  pointCounter = 0;
  prevBytes = 0; 
  prevMillis=millis();
  byteRate_perSec = 0;
  drawLoop_counter = 0;
  //set all data source list items inactive
  if ((eegDataSource == DATASOURCE_NORMAL) || (eegDataSource == DATASOURCE_NORMAL_W_AUX)) {
    closeLogFile();  //close log file
    openBCI.closeSDandSerialPort();
  }
  systemMode = 0;
}

void initializeGUI() {

  verbosePrint("OpenBCI_GUI: initializeGUI: 1");
  String filterDescription = eegProcessing.getFilterDescription();
  verbosePrint("OpenBCI_GUI: initializeGUI: 2");
  gui = new Gui_Manager(this, win_x, win_y, nchan, displayTime_sec, default_vertScale_uV, filterDescription, smoothFac[smoothFac_ind]);
  verbosePrint("OpenBCI_GUI: initializeGUI: 3");
  //associate the data to the GUI traces
  gui.initDataTraces(dataBuffX, dataBuffY_filtY_uV, fftBuff, eegProcessing.data_std_uV, is_railed, eegProcessing.polarity);
  verbosePrint("OpenBCI_GUI: initializeGUI: 4");
  //limit how much data is plotted...hopefully to speed things up a little
  gui.setDoNotPlotOutsideXlim(true);
  verbosePrint("OpenBCI_GUI: initializeGUI: 5");
  gui.setDecimateFactor(2);
  verbosePrint("OpenBCI_GUI: initializeGUI: 6");
}

//======================== DRAW LOOP =============================//

void draw() {
  signPost("10");
  drawLoop_counter++;
  signPost("20");
  systemUpdate();
  signPost("30");
  systemDraw();
  signPost("40");
}

void systemUpdate() { // for updating data values and variables

  //update the sync state with the OpenBCI hardware
  openBCI.updateSyncState(sdSetting);

  //prepare for updating the GUI
  win_x = width;
  win_y = height;

  //updates while in intro screen
  if (systemMode == 0) {
  }
  if (systemMode == 10) {
    if (isRunning) {
      //get the data, if it is available
      channels_set = true; 
     
      
      pointCounter = getDataIfAvailable(pointCounter);

      //has enough data arrived to process it and update the GUI?
      if (pointCounter >= nPointsPerUpdate) {
        pointCounter = 0;  //reset for next time

        //process the data
        processNewData();
        if ((millis() - timeOfGUIreinitialize) > reinitializeGUIdelay) { //wait 1 second for GUI to reinitialize
          try {
            gui.update(eegProcessing.data_std_uV, data_elec_imp_ohm);
          } 
          catch (Exception e) {
            println(e.getMessage());
            reinitializeGUIdelay = reinitializeGUIdelay * 2;
            println("OpenBCI_GUI: systemUpdate: New GUI reinitialize delay = " + reinitializeGUIdelay);
          }
        } else {
          println("OpenBCI_GUI: systemUpdate: reinitializing GUI after resize... not updating GUI");
        }

        redrawScreenNow=true;
      } else {
        //not enough data has arrived yet... only update the channel controller
      }
    }

    gui.cc.update(); //update Channel Controller even when not updating certain parts of the GUI... (this is a bit messy...)
    updateButtons(); //make sure all system buttons are up to date

    //re-initialize GUI if screen has been resized and it's been more than 1/2 seccond (to prevent reinitialization of GUI from happening too often)
    if (screenHasBeenResized == true && (millis() - timeOfLastScreenResize) > reinitializeGUIdelay) {
      screenHasBeenResized = false;
      println("systemUpdate: reinitializing GUI");
      timeOfGUIreinitialize = millis();
      initializeGUI();
    }

  }

}

void systemDraw() { //for drawing to the screen
  
  //redraw the screen...not every time, get paced by when data is being plotted    
  background(background_color);  //clear the screen
 
  
  
  if (systemMode == 10) {
    int drawLoopCounter_thresh = 100;
    if ((redrawScreenNow) || (drawLoop_counter >= drawLoopCounter_thresh)) {
      //if (drawLoop_counter >= drawLoopCounter_thresh) println("OpenBCI_GUI: redrawing based on loop counter...");
      drawLoop_counter=0; //reset for next time
      redrawScreenNow = false;  //reset for next time

      //update the title of the figure;
      switch (eegDataSource) {
      case DATASOURCE_NORMAL: 
      case DATASOURCE_NORMAL_W_AUX:
        //surface.setTitle(int(frameRate) + " fps, Byte Count = " + openBCI_byteCount + ", bit rate = " + byteRate_perSec*8 + " bps" + ", " + int(float(fileoutput.getRowsWritten())/openBCI.get_fs_Hz()) + " secs Saved, Writing to " + output_fname);
        break;
      case DATASOURCE_SYNTHETIC:
        //surface.setTitle(int(frameRate) + " fps, Using Synthetic EEG Data");
        break;
      case DATASOURCE_PLAYBACKFILE:
        //surface.setTitle(int(frameRate) + " fps, Playing " + int(float(currentTableRowIndex)/openBCI.get_fs_Hz()) + " of " + int(float(playbackData_table.getRowCount())/openBCI.get_fs_Hz()) + " secs, Reading from: " + playbackData_fname);
        break;
      }
    }

    //wait 1 second for GUI to reinitialize
    if ((millis() - timeOfGUIreinitialize) > reinitializeGUIdelay) { 
      // println("attempting to draw GUI...");
      try {
        // println("GUI DRAW!!! " + millis());
        pushStyle();
        fill(255);
        noStroke();
        rect(0, 0, width, navBarHeight);
        popStyle();
        gui.draw(); //draw the GUI
      } 
      catch (Exception e) {
        println(e.getMessage());
        reinitializeGUIdelay = reinitializeGUIdelay * 2;
        println("OpenBCI_GUI: systemDraw: New GUI reinitialize delay = " + reinitializeGUIdelay);
      }
    } else {
      //reinitializing GUI after resize
      println("OpenBCI_GUI: systemDraw: reinitializing GUI after resize... not drawing GUI");
    }
  } else { //systemMode != 10
    //still print title information about fps
    //surface.setTitle(int(frameRate) + " fps — OpenBCI GUI");
  }

  //control panel
  if (controlPanel.isOpen) {
        channels_set = false; 
      controlPanel.draw();
  }
  //if(!skip_setup)
 // controlPanelCollapser.draw();
  if ((openBCI.get_state() == openBCI.STATE_COMINIT || openBCI.get_state() == openBCI.STATE_SYNCWITHHARDWARE) && systemMode == 0) {
    //make out blink the text "Initalizing GUI..."
    if (millis()%1000 < 500) {
      println("Iniitializing communication w/ your OpenBCI board...");
    } else {
     // println("");
    }

    if (millis() - timeOfInit > 12000) {
      haltSystem();
      initSystemButton.but_txt = "START SYSTEM";
      println("Init timeout. Verify your Serial/COM Port. Power DOWN/UP your OpenBCI & USB Dongle. Then retry Initialization.");
    }
  }
  channels.draw();
}

//called from systemUpdate when mode=10 and isRunning = true
int getDataIfAvailable(int pointCounter) {

  if ( (eegDataSource == DATASOURCE_NORMAL) || (eegDataSource == DATASOURCE_NORMAL_W_AUX) ) {
    //get data from serial port as it streams in
    //next, gather any new data into the "little buffer"
    while ( (curDataPacketInd != lastReadDataPacketInd) && (pointCounter < nPointsPerUpdate)) {
      lastReadDataPacketInd = (lastReadDataPacketInd+1) % dataPacketBuff.length;  //increment to read the next packet
      for (int Ichan=0; Ichan < nchan; Ichan++) {   //loop over each cahnnel
        //scale the data into engineering units ("microvolts") and save to the "little buffer"
        yLittleBuff_uV[Ichan][pointCounter] = dataPacketBuff[lastReadDataPacketInd].values[Ichan] * openBCI.get_scale_fac_uVolts_per_count();
      } 
      pointCounter++; //increment counter for "little buffer"
    }
  } else {
    // make or load data to simulate real time

    //has enough time passed?
    int current_millis = millis();
    if (current_millis >= nextPlayback_millis) {
      //prepare for next time
      int increment_millis = int(round(float(nPointsPerUpdate)*1000.f/openBCI.get_fs_Hz())/playback_speed_fac);
      if (nextPlayback_millis < 0) nextPlayback_millis = current_millis;
      nextPlayback_millis += increment_millis;

      // generate or read the data
      lastReadDataPacketInd = 0;
      for (int i = 0; i < nPointsPerUpdate; i++) {
        // println();
        dataPacketBuff[lastReadDataPacketInd].sampleIndex++;
        switch (eegDataSource) {
        case DATASOURCE_SYNTHETIC: //use synthetic data (for GUI debugging)   
          break;
        case DATASOURCE_PLAYBACKFILE: 
          currentTableRowIndex=getPlaybackDataFromTable(playbackData_table, currentTableRowIndex, openBCI.get_scale_fac_uVolts_per_count(), dataPacketBuff[lastReadDataPacketInd]);
          break;
        default:
          //no action
        }
        //gather the data into the "little buffer"
        for (int Ichan=0; Ichan < nchan; Ichan++) {
          //scale the data into engineering units..."microvolts"
          yLittleBuff_uV[Ichan][pointCounter] = dataPacketBuff[lastReadDataPacketInd].values[Ichan]* openBCI.get_scale_fac_uVolts_per_count();
        }
        pointCounter++;
      } 
    } // close "has enough time passed"
  } 
  return pointCounter;
}




RunningMean avgBitRate = new RunningMean(10);  //10 point running average...at 5 points per second, this should be 2 second running average
void processNewData() {

  //compute instantaneous byte rate
  float inst_byteRate_perSec = (int)(1000.f * ((float)(openBCI_byteCount - prevBytes)) / ((float)(millis() - prevMillis)));

  prevMillis=millis();           //store for next time
  prevBytes = openBCI_byteCount; //store for next time

  //compute smoothed byte rate
  avgBitRate.addValue(inst_byteRate_perSec);
  byteRate_perSec = (int)avgBitRate.calcMean();

  //prepare to update the data buffers
  float foo_val;
  float prevFFTdata[] = new float[fftBuff[0].specSize()];
  double foo;

  //update the data buffers
  for (int Ichan=0; Ichan < nchan; Ichan++) {
    //append the new data to the larger data buffer...because we want the plotting routines
    //to show more than just the most recent chunk of data.  This will be our "raw" data.
    appendAndShift(dataBuffY_uV[Ichan], yLittleBuff_uV[Ichan]);

    //make a copy of the data that we'll apply processing to.  This will be what is displayed on the full montage
    dataBuffY_filtY_uV[Ichan] = dataBuffY_uV[Ichan].clone();
  }

  //update the FFT (frequency spectrum)
  for (int Ichan=0; Ichan < nchan; Ichan++) {  

    //copy the previous FFT data...enables us to apply some smoothing to the FFT data
    for (int I=0; I < fftBuff[Ichan].specSize(); I++) prevFFTdata[I] = fftBuff[Ichan].getBand(I); //copy the old spectrum values

    //prepare the data for the new FFT
    float[] fooData_raw = dataBuffY_uV[Ichan];  //use the raw data for the FFT
    fooData_raw = Arrays.copyOfRange(fooData_raw, fooData_raw.length-Nfft, fooData_raw.length);   //trim to grab just the most recent block of data
    float meanData = mean(fooData_raw);  //compute the mean
    for (int I=0; I < fooData_raw.length; I++) fooData_raw[I] -= meanData; //remove the mean (for a better looking FFT

    //compute the FFT
    fftBuff[Ichan].forward(fooData_raw); //compute FFT on this channel of data

    for (int I=0; I < fftBuff[Ichan].specSize(); I++) {  //loop over each FFT bin
      fftBuff[Ichan].setBand(I, (float)(fftBuff[Ichan].getBand(I) / fftBuff[Ichan].specSize()));
    }     
    
    //average the FFT with previous FFT data so that it makes it smoother in time
    double min_val = 0.01d;
    for (int I=0; I < fftBuff[Ichan].specSize(); I++) {   //loop over each fft bin
      if (prevFFTdata[I] < min_val) prevFFTdata[I] = (float)min_val; //make sure we're not too small for the log calls
      foo = fftBuff[Ichan].getBand(I); 
      if (foo < min_val) foo = min_val; //make sure this value isn't too small

      if (true) {
        //smooth in dB power space
        foo =   (1.0d-smoothFac[smoothFac_ind]) * java.lang.Math.log(java.lang.Math.pow(foo, 2));
        foo += smoothFac[smoothFac_ind] * java.lang.Math.log(java.lang.Math.pow((double)prevFFTdata[I], 2)); 
        foo = java.lang.Math.sqrt(java.lang.Math.exp(foo)); //average in dB space
      } 
      fftBuff[Ichan].setBand(I, (float)foo); //put the smoothed data back into the fftBuff data holder for use by everyone else
    } //end loop over FFT bins
  } //end the loop over channels.

  //apply additional processing for the time-domain montage plot (ie, filtering)
  eegProcessing.process(yLittleBuff_uV, dataBuffY_uV, dataBuffY_filtY_uV, fftBuff);
  channels.process(yLittleBuff_uV, dataBuffY_filtY_uV, fftBuff);

  //look to see if the latest data is railed so that we can notify the user on the GUI
  for (int Ichan=0; Ichan < nchan; Ichan++) is_railed[Ichan].update(dataPacketBuff[lastReadDataPacketInd].values[Ichan]);

  //compute the electrode impedance. Do it in a very simple way [rms to amplitude, then uVolt to Volt, then Volt/Amp to Ohm]
  for (int Ichan=0; Ichan < nchan; Ichan++) data_elec_imp_ohm[Ichan] = (sqrt(2.0)*eegProcessing.data_std_uV[Ichan]*1.0e-6) / openBCI.get_leadOffDrive_amps();
}

//er function in handling the EEG data
void appendAndShift(float[] data, float[] newData) {
  int nshift = newData.length;
  int end = data.length-nshift;
  for (int i=0; i < end; i++) {
    data[i]=data[i+nshift];  //shift data points down by 1
  }
  for (int i=0; i<nshift; i++) {
    data[end+i] = newData[i];  //append new data
  }
}


boolean emg_configured = false; 

//here is the routine that listens to the serial port.
//if any data is waiting, get it, parse it, and stuff it into our vector of 
//pre-allocated dataPacketBuff
void serialEvent(Serial port) {
  //check to see which serial port it is
  if (openBCI.isOpenBCISerial(port)) {
    // println("OpenBCI_GUI: serialEvent: millis = " + millis());

    boolean echoBytes;

    if (openBCI.isStateNormal() != true) {  // || printingRegisters == true){
      echoBytes = true;
    } else {
      echoBytes = false;
    }

    openBCI.read(echoBytes);
    openBCI_byteCount++;
    if (openBCI.get_isNewDataPacketAvailable()) {
      //copy packet into buffer of data packets
      curDataPacketInd = (curDataPacketInd+1) % dataPacketBuff.length; //this is also used to let the rest of the code that it may be time to do something
      openBCI.copyDataPacketTo(dataPacketBuff[curDataPacketInd]);  //resets isNewDataPacketAvailable to false
      newPacketCounter++;

      fileoutput.writeRawData_dataPacket(dataPacketBuff[curDataPacketInd], openBCI.get_scale_fac_uVolts_per_count(), openBCI.get_scale_fac_accel_G_per_count());
    }
  } else {
    
    String inData = port.readStringUntil('\n');
    if (inData == null)            
    return;
    channels.parse_arduino_messages(inData);  
    
  }
}

String getDateString() {
  String fname = year() + "-";
  if (month() < 10) fname=fname+"0";
  fname = fname + month() + "-";
  if (day() < 10) fname = fname + "0";
  fname = fname + day(); 

  fname = fname + "_";
  if (hour() < 10) fname = fname + "0";
  fname = fname + hour() + "-";
  if (minute() < 10) fname = fname + "0";
  fname = fname + minute() + "-";
  if (second() < 10) fname = fname + "0";
  fname = fname + second();
  return fname;
}


void mousePressed() {
  
  ekg.mousePressed(); 
  alpha.mousePressed();
  emg.mousePressed(); 
  in.mousePressed(); 
  out.mousePressed(); 

  verbosePrint("OpenBCI_GUI: mousePressed: mouse pressed");

  //if not in initial setup...
  if (systemMode >= 10) {

    //limit interactivity of main GUI if control panel is open
    if (controlPanel.isOpen == false) {
      //was the stopButton pressed?

      gui.mousePressed(); // trigger mousePressed function in GUI
      //most of the logic below should be migrated into the Gui_manager specific function above

      if (gui.stopButton.isMouseHere()) { 
        gui.stopButton.setIsActive(true);
        stopButtonWasPressed();
        stop_all_notes();
      }
      //check the buttons
      switch (gui.guiPage) {
      case Gui_Manager.GUI_PAGE_CHANNEL_ONOFF:
        break;
      case Gui_Manager.GUI_PAGE_IMPEDANCE_CHECK:
      case Gui_Manager.GUI_PAGE_HEADPLOT_SETUP:
      }

      
    }
  }

  //=============================//
  // CONTROL PANEL INTERACTIVITY //
  //=============================//

  //was control panel button pushed
  if (controlPanelCollapser.isMouseHere()) {
    if (controlPanelCollapser.isActive && systemMode == 10) {
      controlPanelCollapser.setIsActive(false);
      controlPanel.isOpen = false;
    } else {
      controlPanelCollapser.setIsActive(true);
      controlPanel.isOpen = true;
    }
  } else {
    if (controlPanel.isOpen) {
      controlPanel.CPmousePressed();
    }
  }

  //interacting with control panel
  if (controlPanel.isOpen) {
    //close control panel if you click outside...
    if (systemMode == 10) {
      if (mouseX > 0 && mouseX < controlPanel.w && mouseY > 0 && mouseY < controlPanel.initBox.y+controlPanel.initBox.h) {
        println("OpenBCI_GUI: mousePressed: clicked in CP box");
        controlPanel.CPmousePressed();
      }
      //if clicked out of panel
      else {
        println("OpenBCI_GUI: mousePressed: outside of CP clicked");
        controlPanel.isOpen = false;
        controlPanelCollapser.setIsActive(false);
        //println("Press the \"Press to Start\" button to initialize the data stream.");
      }
    }
  }

  redrawScreenNow = true;  //command a redraw of the GUI whenever the mouse is pressed

}

void mouseReleased() {

  //keyboard.mouseReleased(); 
  verbosePrint("OpenBCI_GUI: mouseReleased: mouse released");

  //some buttons light up only when being actively pressed.  Now that we've
  //released the mouse button, turn off those buttons.

  //interacting with control panel
  if (controlPanel.isOpen) {
    //if clicked in panel
    controlPanel.CPmouseReleased();
  }

  if (systemMode >= 10) {

    gui.mouseReleased();
    redrawScreenNow = true;  //command a redraw of the GUI whenever the mouse is released
  }

  if (screenHasBeenResized) {
    println("OpenBCI_GUI: mouseReleased: screen has been resized...");
    screenHasBeenResized = false;
  }


}

void printRegisters() {
  openBCI.printRegisters();
}

void stopRunning() {
  verbosePrint("OpenBCI_GUI: stopRunning: stop running...");
  //println("Data stream stopped.");
  if (openBCI != null) {
    openBCI.stopDataTransfer();
  }
  timeSinceStopRunning = millis(); //used as a timer to prevent misc. bytes from flooding serial...
  isRunning = false;
}

void startRunning() {
  verbosePrint("startRunning...");
  //println("Data stream started.");
  if ((eegDataSource == DATASOURCE_NORMAL) || (eegDataSource == DATASOURCE_NORMAL_W_AUX)) {
    if (openBCI != null) openBCI.startDataTransfer();
  }
  isRunning = true;
}

//execute this function whenver the stop button is pressed
void stopButtonWasPressed() {
  //toggle the data transfer state of the ADS1299...stop it or start it...
  if (isRunning) {
    verbosePrint("openBCI_GUI: stopButton was pressed...stopping data transfer...");
    stopRunning();
  } else { //not running
    verbosePrint("openBCI_GUI: startButton was pressed...starting data transfer...");
    startRunning();
    nextPlayback_millis = millis();  //used for synthesizeData and readFromFile.  This restarts the clock that keeps the playback at the right pace.
  }
}

void updateButtons() {
  //update the stop button with new text based on the current running state
  //gui.stopButton.setActive(isRunning);
  if (isRunning) {
    //println("OpenBCI_GUI: stopButtonWasPressed (a): changing string to " + Gui_Manager.stopButton_pressToStop_txt);
    gui.stopButton.setString(Gui_Manager.stopButton_pressToStop_txt); 
    gui.stopButton.setColorNotPressed(color(200));
  } else {
    //println("OpenBCI_GUI: stopButtonWasPressed (a): changing string to " + Gui_Manager.stopButton_pressToStart_txt);
    gui.stopButton.setString(Gui_Manager.stopButton_pressToStart_txt);
    gui.stopButton.setColorNotPressed(color(100));
  }
}

int getPlaybackDataFromTable(Table datatable, int currentTableRowIndex, float scale_fac_uVolts_per_count, DataPacket_ADS1299 curDataPacket) {
  float val_uV = 0.0f;

  //check to see if we can load a value from the table
  if (currentTableRowIndex >= datatable.getRowCount()) {
    //end of file
    println("OpenBCI_GUI: getPlaybackDataFromTable: hit the end of the playback data file.  starting over...");
    //if (isRunning) stopRunning();
    currentTableRowIndex = 0;
  } else {
    //get the row
    TableRow row = datatable.getRow(currentTableRowIndex);
    currentTableRowIndex++; //increment to the next row

    //get each value
    for (int Ichan=0; Ichan < nchan; Ichan++) {
      if (isChannelActive(Ichan) && (Ichan < datatable.getColumnCount())) {
        val_uV = row.getFloat(Ichan);
      } else {
        //use zeros for the missing channels
        val_uV = 0.0f;
      }

      //put into data structure
      curDataPacket.values[Ichan] = (int) (0.5f+ val_uV / scale_fac_uVolts_per_count); //convert to counts, the 0.5 is to ensure rounding
    }
  }
  return currentTableRowIndex;
}

//Ichan is zero referenced (not one referenced)
boolean isChannelActive(int Ichan) {
  boolean return_val = false;
  if (channelSettingValues[Ichan][0] == '1') {
    return_val = false;
  } else {
    return_val = true;
  }
  return return_val;
}

//activateChannel: Ichan is [0 nchan-1] (aka zero referenced)
void activateChannel(int Ichan) {
  println("OpenBCI_GUI: activating channel " + (Ichan+1));
  if (eegDataSource == DATASOURCE_NORMAL || eegDataSource == DATASOURCE_NORMAL_W_AUX) {
    if (openBCI.isSerialPortOpen()) {
      verbosePrint("**");
      openBCI.changeChannelState(Ichan, true); //activate
    }
  }
  if (Ichan < gui.chanButtons.length) {
    channelSettingValues[Ichan][0] = '0'; 
    gui.cc.update();
  }
}  
void deactivateChannel(int Ichan) {
  println("OpenBCI_GUI: deactivating channel " + (Ichan+1));
  if (eegDataSource == DATASOURCE_NORMAL || eegDataSource == DATASOURCE_NORMAL_W_AUX) {
    if (openBCI.isSerialPortOpen()) {
      verbosePrint("**");
      openBCI.changeChannelState(Ichan, false); //de-activate
    }
  }
  if (Ichan < gui.chanButtons.length) {
    channelSettingValues[Ichan][0] = '1'; 
    gui.cc.update();
  }
}

void openNewLogFile(String _fileName) {
  //close the file if it's open
  if (fileoutput != null) {
    println("OpenBCI_GUI: closing log file");
    closeLogFile();
  }

  //open the new file
  fileoutput = new OutputFile_rawtxt(openBCI.get_fs_Hz(), _fileName);
  output_fname = fileoutput.fname;
  println("openBCI: openNewLogFile: opened output file: " + output_fname);
  println("openBCI: openNewLogFile: opened output file: " + output_fname);
}

void closeLogFile() {
  if (fileoutput != null) fileoutput.closeFile();
}

void incrementFilterConfiguration() {
  eegProcessing.incrementFilterConfiguration();

  //update the button strings
  gui.filtBPButton.but_txt = "BP Filt\n" + eegProcessing.getShortFilterDescription();
  gui.titleMontage.string = "EEG Data (" + eegProcessing.getFilterDescription() + ")";
}

void incrementNotchConfiguration() {
  eegProcessing.incrementNotchConfiguration();

  //update the button strings
  gui.filtNotchButton.but_txt = "Notch\n" + eegProcessing.getShortNotchDescription();
  gui.titleMontage.string = "EEG Data (" + eegProcessing.getFilterDescription() + ")";
}

void incrementSmoothing() {
  smoothFac_ind++;
  if (smoothFac_ind >= smoothFac.length) smoothFac_ind = 0;

  //update the button
  gui.smoothingButton.but_txt = "Smooth\n" + smoothFac[smoothFac_ind];
}

void fileSelected(File selection) {  //called by the Open File dialog box after a file has been selected
  if (selection == null) {
    println("fileSelected: no selection so far...");
  } else {
    //inputFile = selection;
    playbackData_fname = selection.getAbsolutePath();
    if(skip_setup)
    {
      playbackData_fname = playback_file; 
    }
  }
}

void verbosePrint(String _string) {
  if (isVerbose) {
    println(_string);
  }
}

void delay(int delay)
{
  int time = millis();
  while (millis() - time <= delay);
}

boolean printSignPosts = false;

float millisOfLastSignPost = 0.0;
float millisSinceLastSignPost = 0.0;

//method for printing out an ["indentifier"][millisSinceLastSignPost] for debugging purposes... allows us to look at what is taking too long.
void signPost(String identifier) {
  if (printSignPosts) {
    millisSinceLastSignPost = millis() - millisOfLastSignPost;
    println("SIGN POST: [" + identifier + "][" + millisSinceLastSignPost + "]");
    millisOfLastSignPost = millis();
  }
}
