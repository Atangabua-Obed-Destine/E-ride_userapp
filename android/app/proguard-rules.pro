# ML Kit text recognition (ID verification) references the Chinese, Devanagari,
# Japanese and Korean recognisers, which E-Ride does not ship (Latin only).
# Without these lines R8 stops the release build on the missing classes.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
