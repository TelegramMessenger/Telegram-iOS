package com.wels.enc;

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

public class WelsEncTest extends Activity {
  /** Called when the activity is first created. */
  private OnClickListener OnClickEvent;
  private Button mBtnLoad, mBtnStartSW;

  final String   mStreamPath = "/sdcard/welsenc/";
  Vector<String> mCfgFiles = new Vector<String>();

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
          String cfgFile = mStreamPath + "cfgs.txt";
          try {
            BufferedReader bufferedReader = new BufferedReader (new FileReader (cfgFile));
            String text;
            while ((text = bufferedReader.readLine()) != null) {
              mCfgFiles.add (mStreamPath + text);
              Log.i (TAG, mStreamPath + text);
            }
            bufferedReader.close();
          } catch (IOException e) {
            Log.e (TAG, e.getMessage());
          }
        }
        break;
        case R.id.buttonSW: {
          System.out.println ("encode sequence number = " + mCfgFiles.size());
          Log.i (TAG, "after click");
          try {
            for (int k = 0; k < mCfgFiles.size(); k++) {
              String cfgFile =  mCfgFiles.get (k);
              DoEncoderTest (cfgFile);
            }
          } catch (Exception e) {
            Log.e (TAG, e.getMessage());
          }
          mCfgFiles.clear();
          tv.setText ("Encoder is completed!");
        }
        break;
        }
      }
    };

    mBtnLoad.setOnClickListener (OnClickEvent);
    mBtnStartSW.setOnClickListener (OnClickEvent);

    System.out.println ("Done!");
    //run the test automatically,if you not want to autotest, just comment this line
    runAutoEnc();
  }

  public void runAutoEnc() {
    Thread thread = new Thread() {

      public void run() {
        Log.i (TAG, "encoder performance test begin");
        String inYuvfile = null, outBitfile = null, inOrgfile = null, inLayerfile = null;
        File encCase = new File (mStreamPath);
        String[] caseNum = encCase.list();
        if (caseNum == null || caseNum.length == 0) {
          Log.i (TAG, "have not find any encoder resourse");
          finish();
        }

        for (int i = 0; i < caseNum.length; i++) {
          String[] yuvName = null;
          File yuvPath = null;
          File encCaseNo = new File (mStreamPath + caseNum[i]);
          String[] encFile = encCaseNo.list();

          for (int k = 0; k < encFile.length; k++) {
            if (encFile[k].compareToIgnoreCase ("welsenc.cfg") == 0)

              inOrgfile = encCaseNo + File.separator + encFile[k];

            else if (encFile[k].compareToIgnoreCase ("layer2.cfg") == 0)
              inLayerfile = encCaseNo + File.separator + encFile[k];
            else if (encFile[k].compareToIgnoreCase ("yuv") == 0) {
              yuvPath = new File (encCaseNo + File.separator + encFile[k]);
              yuvName = yuvPath.list();
            }
          }
          for (int m = 0; m < yuvName.length; m++) {
            inYuvfile = yuvPath + File.separator + yuvName[m];
            outBitfile = inYuvfile + ".264";
            Log.i (TAG, "enc yuv file:" + yuvName[m]);
            DoEncoderAutoTest (inOrgfile, inLayerfile, inYuvfile, outBitfile);
          }
        }

        Log.i (TAG, "encoder performance test finish");
        finish();
      }

    };
    thread.start();

  }

  @Override
  public void onStart() {
    Log.i (TAG, "welsencdemo onStart");
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

  public native void  DoEncoderTest (String cfgFileName);
  public native void  DoEncoderAutoTest (String cfgFileName, String layerFileName, String yuvFileName,
                                         String outBitsName);
  private static final String TAG = "welsenc";
  static {
    try {
      System.loadLibrary ("openh264");
      System.loadLibrary ("stlport_shared");
      System.loadLibrary ("welsencdemo");
      Log.v (TAG, "Load libwelsencdemo.so successful");
    } catch (Exception e) {
      Log.e (TAG, "Failed to load welsenc" + e.getMessage());
    }
  }

}

