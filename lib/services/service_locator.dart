
import 'audio_handler.dart';
import 'audio_session.dart';

late VideoPlayerServiceHandler videoPlayerServiceHandler;
late AudioSessionHandler audioSessionHandler;

// 初始化就绪标记，供使用处判断是否可安全调用
bool serviceLocatorReady = false;

Future<void> setupServiceLocator() async {
  if (serviceLocatorReady) return; // 避免重复初始化
  final audio = await initAudioService();
  videoPlayerServiceHandler = audio;
  audioSessionHandler = AudioSessionHandler();
  serviceLocatorReady = true;
}
