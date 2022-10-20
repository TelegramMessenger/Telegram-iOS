package com.wels.dec;

import android.app.Activity;
import android.os.Bundle;
import android.os.Environment;
import android.os.Process;
import android.util.Log;

import android.view.KeyEvent;
import android.view.View;
import android.view.View.OnClickListener;

import android.widget.Button;
import android.widget.TextView;
import java.io.*;
import java.util.Vector;

public class WelsDecTest extends Activity {
  /** Called when the activity is first created. */
  private OnClickListener OnClickEvent;
  private Button mBtnLoad, mBtnStartSW;

  final String   mStreamPath = "/sdcard/welsdec/";
  Vector<String> mStreamFiles = new Vector<String>();

  @Override
  public void onCreate (Bundle savedInstanceState) {
    super.onCreate (savedInstanceState);
    final TextView  tv = new TextView (this);
    System.out.println ("Here we go ...");
    Log.i (TAG, "sdcard path:" + Environment.getExternalStorageDirectory().getAbsolutePath());
    setContentView (R.layout.main);

    mBtnLoad = (Button)findViewById (R.id.cfg);
    mBtnStartSW = (Button)findViewById (R.id.buttonSW);

    OnClickEvent = new OnClickListener() {
      public void onClick (View v) {
        switch (v.getId()) {
        case R.id.cfg: {
          String cfgFile = mStreamPath + "BitStreams.txt";
          try {
            BufferedReader bufferedReader = new BufferedReader (new FileReader (cfgFile));
            String text;
            while ((text = bufferedReader.readLine()) != null) {
              mStreamFiles.add (mStreamPath + text);
              Log.i (TAG, mStreamPath + text);
            }
            bufferedReader.close();
          } catch (IOException e) {
            Log.e ("WELS_DEC", e.getMessage());
          }
        }
        break;
        case R.id.buttonSW: {
          System.out.println ("decode sequence number = " + mStreamFiles.size());
          Log.i ("WSE_DEC", "after click");
          try {
            for (int k = 0; k < mStreamFiles.size(); k++) {
              String inFile =  mStreamFiles.get (k);
              String outFile =  mStreamFiles.get (k) + ".yuv";
              Log.i (TAG, "input file:" + inFile + "    output file:" + outFile);
              DoDecoderTest (inFile, outFile);
            }
          } catch (Exception e) {
            Log.e (TAG, e.getMessage());
          }
          mStreamFiles.clear();
          tv.setText ("Decoder is completed!");
        }
        break;
        }
      }
    };

    mBtnLoad.setOnClickListener (OnClickEvent);
    mBtnStartSW.setOnClickListener (OnClickEvent);

    System.out.println ("Done!");
    //if you want to run the demo manually, just comment following 2 lines
    runAutoDec();
  }
  public void runAutoDec() {
    Thread thread = new Thread() {

      public void run() {
        Log.i (TAG, "decoder performance test begin");

        File bitstreams = new File (mStreamPath);
        String[] list = bitstreams.list();
        if (list == null || list.length == 0) {
          Log.i (TAG, "have not find any coder resourse");
          finish();
        }
        for (int i = 0; i < list.length; i++) {

          String inFile = list[i];
          inFile = mStreamPath + inFile;
          String outFile = inFile + ".yuv";
          DoDecoderTest (inFile, outFile);


        }
        Log.i (TAG, "decoder performance test finish");
        finish();
      }

    };
    thread.start();

  }

  @Override
  public void onStart() {
    Log.i ("WSE_DEC", "welsdecdemo onStart");
    super.onStart();
  }
  @Override
  public void onDestroy() {
    super.onDestroy();

    Log.i (TAG, "OnDestroy");

    Process.killProcess (Process.myPid());

  }

  @Override
  public boolean onKeyDown (int keyCode, KeyEvent event) {
    switch (keyCode) {
    case KeyEvent.KEYCODE_BACK:
      return true;
    default:
      return super.onKeyDown (keyCode, event);
    }
  }

  public native void  DoDecoderTest (String infilename, String outfilename);
  private static final String TAG = "welsdec";
  static {
    try {
      System.loadLibrary ("openh264");
      System.loadLibrary ("stlport_shared");
      System.loadLibrary ("welsdecdemo");
      Log.v (TAG, "Load libwelsdec successful");
    } catch (Exception e) {
      Log.e (TAG, "Failed to load welsdec" + e.getMessage());
    }
  }
}

