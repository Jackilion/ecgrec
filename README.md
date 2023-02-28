# ecgrec

An app meant to be used with the PolaH10 ECG belt.
It saves the ECG and accelerometer data to a SQLite database, that can easily be transferred to a computer for analysis.

## Building

The app relies on my forked version of the flutter polar wrapper package. I needed to add the functionality to set the sensor time, because
the H10 sensor resets itself to 01/01/2019 UTC after it goes to standby. Since the app is only meant to be run on android device, 
I added the functionality for the Android channel only. If I ever add it to the iOS channel as well, I will make a pull request for the package.
