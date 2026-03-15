# ReefGuard: AI-Powered Illegal Fishing Detection System
*Protecting marine ecosystems 24/7 with acoustic ML + WiFi geofencing*

## What is ReefGuard?

ReefGuard is a **dual-sensor floating buoy** deployed in protected marine habitats that:

1. **Listens** - Detects ship acoustic signatures using ML classification
2. **Locates**  - Calculates distance via WiFi signal strength (RSSI)
3. **Tracks**  - Monitors vessel movement through geofenced zones
4. **Alerts** - Notifies law enforcement in real-time

## Hardware
1. Arduino Uno R3
2. Arduino Tiny Machine Learning Kit
3. Micro Servo 9g
4. GL.iNet Router (OpenWrt) 
5. CAD File https://ncssm.onshape.com/documents/62f700a6995dc5237d6cae4d/w/bc9af101aebb61ccc203b014/e/45f9962600fb57eff495c581?renderMode=0&uiState=69b6d75f1dfd08036e3173f4
## Distance Sensing using Wi-Fi router and phone
We used a linear interpolation algorithm to estimate values between two known points. The formula for linear interpolation is:

$$
L(x) = y_0 + \frac{y_1 - y_0}{x_1 - x_0}(x - x_0)
$$

**where:**

- $L(x)$ — interpolated value at $x$
- $x_0, y_0$ — coordinates of the first known point
- $x_1, y_1$ — coordinates of the second known point

To find the values, we first calibrated 5 defined values using calibrate.sh and used them for the algorithm.

## Neural Network Training Process
The actual model was created and trained using Edge Impulse, which was then exported to Arduino. Sound is taken in through a microphone on the Arduino Nano 33 BLE, and the sound data is then used to produce a prediction of whether or not a ship is there. The data folders and Arduino code are listed on the GitHub repository. The original model had much higher training data, but TinyML didn't have sufficient memory, so only one model and limited memory was allowed. 

Data was derived from https://github.com/irfankamboh/DeepShip and https://github.com/ZhuPengsen/Method-for-Splitting-the-DeepShip-Dataset
