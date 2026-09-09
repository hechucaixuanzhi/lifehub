# tflite_flutter 同时兼容可选 GPU delegate；LifeHub 当前自我识别只使用 CPU。
# R8 在 release 构建中仍会检查该可选类型，因此只抑制这一个不存在类的警告。
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
